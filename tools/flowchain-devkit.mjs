#!/usr/bin/env node
import {
  DEFAULT_FLOWCHAIN_RPC_URL,
  FlowChainSdkError,
  assertNoFlowChainSecrets,
  createFlowChainClient,
  createLocalSignedEnvelope,
  redactFlowChainSecrets,
} from "../packages/flowchain-sdk/src/index.ts";

const PUBLIC_RPC_ENV = [
  "FLOWCHAIN_RPC_PUBLIC_URL",
  "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
  "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
  "FLOWCHAIN_RPC_TLS_TERMINATED",
  "FLOWCHAIN_RPC_STATE_BACKUP_PATH",
];

const BASE8453_ENV = [
  "FLOWCHAIN_PILOT_OPERATOR_ACK",
  "FLOWCHAIN_BASE8453_RPC_URL",
  "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
  "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
  "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
  "FLOWCHAIN_BASE8453_FROM_BLOCK",
  "FLOWCHAIN_BASE8453_TO_BLOCK",
  "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
  "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
  "FLOWCHAIN_PILOT_CONFIRMATIONS",
];

function parseArgs(argv) {
  const args = [...argv];
  const command = args.shift();
  const options = {
    json: false,
    rpcUrl: DEFAULT_FLOWCHAIN_RPC_URL,
    allowNonLocal: false,
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--json") {
      options.json = true;
      continue;
    }
    if (arg === "--allow-non-local") {
      options.allowNonLocal = true;
      continue;
    }
    if (arg.startsWith("--")) {
      const key = arg.slice(2).replace(/-([a-z])/g, (_, letter) => letter.toUpperCase());
      const next = args[index + 1];
      if (next === undefined || next.startsWith("--")) {
        options[key] = true;
      } else {
        options[key] = next;
        index += 1;
      }
      continue;
    }
    if (!options._) {
      options._ = [];
    }
    options._.push(arg);
  }

  return { command, options };
}

function isLoopbackRpc(url) {
  try {
    const parsed = new URL(url);
    return ["127.0.0.1", "localhost", "::1"].includes(parsed.hostname);
  } catch {
    return false;
  }
}

function requireLoopbackForWrite(options) {
  if (!options.allowNonLocal && !isLoopbackRpc(options.rpcUrl)) {
    throw new Error("write commands require loopback RPC unless --allow-non-local is explicit");
  }
}

function missingEnv(names) {
  return names.filter((name) => typeof process.env[name] !== "string" || process.env[name].trim().length === 0);
}

function requireEnv(names, label) {
  const missing = missingEnv(names);
  if (missing.length > 0) {
    return {
      schema: "flowchain.devkit.fail_closed.v0",
      status: "blocked",
      label,
      missingEnvNames: missing,
      envValuesPrinted: false,
    };
  }
  return null;
}

function output(payload, options) {
  const safe = redactFlowChainSecrets(payload);
  assertNoFlowChainSecrets(safe);
  if (options.json) {
    console.log(JSON.stringify(safe, null, 2));
    return;
  }
  if (typeof safe === "object" && safe !== null && !Array.isArray(safe)) {
    const label = safe.status ?? safe.schema ?? "ok";
    console.log(String(label));
    console.log(JSON.stringify(safe, null, 2));
    return;
  }
  console.log(String(safe));
}

function localAccountMetadata(accountId, label) {
  return {
    schema: "flowchain.devkit.local_account_metadata.v0",
    accountId,
    label,
    addressShape: "FlowChain local account id; bytes32 account ids are used for Base 8453 bridge recipients.",
    signingBoundary: "Local examples use signed envelopes. The devkit does not output custody material.",
    secretMaterialReturned: false,
    localOnly: true,
  };
}

async function waitForInclusion(client, txId, timeoutMs, intervalMs) {
  const started = Date.now();
  let lastStatus = "not_found";
  while (Date.now() - started <= timeoutMs) {
    try {
      const detail = await client.transactionGet({ txId });
      const tx = detail.transaction ?? {};
      lastStatus = String(tx.status ?? detail.status ?? "unknown");
      if (["applied", "finalized", "local-finalized", "accepted_local"].includes(lastStatus)) {
        return {
          schema: "flowchain.devkit.wait_inclusion.v0",
          status: "included",
          txId,
          transactionStatus: lastStatus,
          elapsedMs: Date.now() - started,
          localOnly: true,
        };
      }
    } catch (error) {
      lastStatus = error instanceof FlowChainSdkError ? error.tag : "not_found";
    }
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
  return {
    schema: "flowchain.devkit.wait_inclusion.v0",
    status: "timeout",
    txId,
    lastStatus,
    elapsedMs: Date.now() - started,
    localOnly: true,
  };
}

async function main() {
  const { command, options } = parseArgs(process.argv.slice(2));
  const client = createFlowChainClient({ rpcUrl: options.rpcUrl });

  switch (command) {
    case "discover": {
      output(await client.discover(), options);
      return;
    }
    case "readiness": {
      const failClosed = options.requirePublic ? requireEnv(PUBLIC_RPC_ENV, "public RPC") : null;
      output(failClosed ?? await client.readiness(), options);
      if (failClosed) {
        process.exitCode = 1;
      }
      return;
    }
    case "chain-status": {
      output(await client.chainStatus(), options);
      return;
    }
    case "account": {
      const subcommand = options._?.[0] ?? "create-local";
      if (subcommand !== "create-local") {
        throw new Error(`unknown account subcommand: ${subcommand}`);
      }
      const accountId = options.accountId ?? `local-account:${options.label ?? "sdk-dev"}`;
      const metadata = localAccountMetadata(accountId, options.label ?? "sdk-dev");
      if (options.submit) {
        requireLoopbackForWrite(options);
        const receipt = await client.submitSignedTransaction(createLocalSignedEnvelope({
          type: "CreateLocalTestUnitBalance",
          accountId,
          owner: options.owner ?? "operator:flowchain-devkit",
        }, options.owner ?? "operator:flowchain-devkit"), {
          runtimeSubmit: true,
          submittedBy: options.owner ?? "operator:flowchain-devkit",
        });
        output({ ...metadata, submitted: true, receipt }, options);
      } else {
        output(metadata, options);
      }
      return;
    }
    case "submit-transfer": {
      requireLoopbackForWrite(options);
      const fromAccountId = options.from ?? options.fromAccountId;
      const toAccountId = options.to ?? options.toAccountId;
      const amountUnits = Number(options.amount ?? options.amountUnits);
      if (!fromAccountId || !toAccountId || !Number.isInteger(amountUnits) || amountUnits <= 0) {
        throw new Error("submit-transfer requires --from, --to, and positive integer --amount");
      }
      const transferId = options.transferId ?? `transfer:devkit:${Date.now()}`;
      const envelope = createLocalSignedEnvelope({
        type: "TransferLocalTestUnits",
        transferId,
        fromAccountId,
        toAccountId,
        amountUnits,
        memo: options.memo ?? "flowchain-devkit-transfer",
      }, options.submittedBy ?? "operator:flowchain-devkit");
      output(await client.submitSignedTransaction(envelope, {
        runtimeSubmit: true,
        submittedBy: options.submittedBy ?? "operator:flowchain-devkit",
      }), options);
      return;
    }
    case "wait-inclusion": {
      if (!options.txId) {
        throw new Error("wait-inclusion requires --tx-id");
      }
      output(await waitForInclusion(
        client,
        options.txId,
        Number(options.timeoutMs ?? 30000),
        Number(options.intervalMs ?? 500),
      ), options);
      return;
    }
    case "balance": {
      if (!options.accountId) {
        throw new Error("balance requires --account-id");
      }
      output(await client.balanceGet(options.accountId), options);
      return;
    }
    case "bridge-readiness": {
      const failClosed = options.requireLive ? requireEnv(BASE8453_ENV, "Base 8453 live bridge") : null;
      output(failClosed ?? await client.bridgeReadiness(), options);
      if (failClosed) {
        process.exitCode = 1;
      }
      return;
    }
    case "bridge-lifecycle": {
      output(await client.pilotLifecycle({
        txHash: options.txHash,
        creditId: options.creditId,
        walletAddress: options.walletAddress,
        status: options.status,
        limit: options.limit === undefined ? 50 : Number(options.limit),
      }), options);
      return;
    }
    case "finality": {
      if (!options.objectId && !options.receiptId && !options.rootfieldId) {
        throw new Error("finality requires --object-id, --receipt-id, or --rootfield-id");
      }
      output(await client.finalityGet({
        objectId: options.objectId,
        receiptId: options.receiptId,
        rootfieldId: options.rootfieldId,
      }), options);
      return;
    }
    default:
      output({
        schema: "flowchain.devkit.help.v0",
        commands: [
          "discover",
          "readiness",
          "chain-status",
          "account create-local",
          "submit-transfer",
          "wait-inclusion",
          "balance",
          "bridge-readiness",
          "bridge-lifecycle",
          "finality",
        ],
        defaultRpcUrl: DEFAULT_FLOWCHAIN_RPC_URL,
        localOnlyByDefault: true,
      }, { ...options, json: true });
  }
}

main().catch((error) => {
  const payload = {
    schema: "flowchain.devkit.error.v0",
    status: "failed",
    error: error instanceof FlowChainSdkError
      ? error.toJSON()
      : {
          name: error instanceof Error ? error.name : "Error",
          message: error instanceof Error ? error.message : String(error),
        },
  };
  try {
    output(payload, { json: true });
  } catch {
    console.log(JSON.stringify({
      schema: "flowchain.devkit.error.v0",
      status: "failed",
      error: { message: "redacted failure" },
    }, null, 2));
  }
  process.exitCode = 1;
});
