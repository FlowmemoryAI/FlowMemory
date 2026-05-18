#!/usr/bin/env node
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

import {
  addEncryptedTestVaultAccount,
  buildBridgeWithdrawalIntentDocument,
  buildFinalityActionDocument,
  buildProductAddLiquidityDocument,
  buildProductPoolCreateDocument,
  buildProductRemoveLiquidityDocument,
  buildProductSwapDocument,
  buildProductTokenLaunchDocument,
  buildProductTransferDocument,
  createEncryptedTestVault,
  exportLocalWalletPublicMetadata,
  exportVaultPublicMetadata,
  listVaultPublicAccounts,
  LOCAL_TEST_UNIT_ASSET_ID,
  rotateEncryptedTestVaultAccount,
  signWalletDocumentWithVault,
  unlockEncryptedTestVault,
  validateLocalTransactionEnvelope,
  flowchainPublicAccountMetadata,
  validateLocalWalletPublicMetadata,
  verifyFlowchainEnvelope,
  verifyWalletSignedEnvelope
} from "./index.js";

const { command, args } = parseCommand(process.argv.slice(2));

try {
  if (command === "create") {
    const vault = createEncryptedTestVault({
      password: password(),
      label: args.label ?? "local-operator",
      signerRole: args.role ?? "operator",
      chainId: args["chain-id"] ?? "31337",
      createdAtUnixMs: args["created-at-unix-ms"]
    });
    writeJson(requiredOrDefault("vault", "devnet/local/wallet/operator-vault.local.json"), vault);
    maybeWriteMetadata(vault);
    printAccountSummary("flowchain.wallet.account_created.v0", vault.publicAccounts[0], { includePublicKey: true });
  } else if (command === "import") {
    const vaultPath = requiredOrDefault("vault", "devnet/local/wallet/imported-vault.local.json");
    const privateKey = importedPrivateKey();
    const vault = existsSync(vaultPath)
      ? addEncryptedTestVaultAccount({
        vault: readJson(vaultPath),
        password: password(),
        label: args.label ?? "imported-account",
        signerRole: args.role ?? "agent",
        privateKey,
        chainId: args["chain-id"] ?? "31337",
        createdAtUnixMs: args["created-at-unix-ms"]
      })
      : createEncryptedTestVault({
        password: password(),
        label: args.label ?? "imported-account",
        signerRole: args.role ?? "agent",
        privateKey,
        chainId: args["chain-id"] ?? "31337",
        createdAtUnixMs: args["created-at-unix-ms"]
    });
    writeJson(vaultPath, vault);
    maybeWriteMetadata(vault);
    printAccountSummary("flowchain.wallet.account_imported.v0", vault.publicAccounts.at(-1), { includePublicKey: false });
  } else if (command === "unlock" || command === "check") {
    const vault = readJson(required("vault"));
    const session = unlockVaultSafely(vault);
    const markerPath = sessionPath();
    writeJson(markerPath, {
      schema: "flowchain.wallet.unlock_marker.v0",
      vaultId: session.vaultId,
      unlockedAtUnixMs: Date.now().toString(),
      accountCount: session.accounts.length,
      containsSecrets: false
    });
    console.log(JSON.stringify({
      schema: "flowchain.wallet.unlock_result.v0",
      vaultId: session.vaultId,
      unlocked: true,
      accountCount: session.accounts.length,
      sessionPath: markerPath,
      containsSecrets: false
    }, null, 2));
  } else if (command === "lock") {
    const markerPath = sessionPath();
    if (existsSync(markerPath)) {
      rmSync(markerPath, { force: true });
    }
    console.log(JSON.stringify({
      schema: "flowchain.wallet.lock_result.v0",
      locked: true,
      sessionPath: markerPath
    }, null, 2));
  } else if (command === "list" || command === "list-accounts") {
    const vault = readJson(required("vault"));
    if (!args.public) {
      unlockVaultSafely(vault);
    }
    console.log(JSON.stringify({
      schema: "flowchain.wallet.account_list.v0",
      vaultId: vault.vaultId,
      locked: !existsSync(sessionPath()),
      chainIds: [...new Set((vault.publicAccounts ?? []).map((account) => String(account.chainId ?? "31337")))],
      accounts: listVaultPublicAccounts(vault)
    }, null, 2));
  } else if (command === "metadata") {
    const vault = readJson(required("vault"));
    console.log(JSON.stringify(exportVaultPublicMetadata(vault), null, 2));
  } else if (command === "export-metadata") {
    const vault = readJson(required("vault"));
    const metadata = exportLocalWalletPublicMetadata(vault, { updatedAtUnixMs: args["updated-at-unix-ms"] });
    writeOutput(args.out, metadata);
    console.log(JSON.stringify(metadata, null, 2));
  } else if (command === "verify-metadata") {
    const metadata = readJson(required("metadata"));
    const result = validateLocalWalletPublicMetadata(metadata, { expectedChainId: args["chain-id"] });
    console.log(JSON.stringify(result, null, 2));
    process.exitCode = result.valid ? 0 : 1;
  } else if (command === "add-account" || command === "rotate-account") {
    const vaultPath = required("vault");
    const vault = readJson(vaultPath);
    const updatedVault = addEncryptedTestVaultAccount({
      vault,
      password: password(),
      label: args.label ?? "local-account",
      signerRole: args.role ?? "agent",
      chainId: args["chain-id"] ?? vault.publicAccounts?.[0]?.chainId ?? "31337",
      createdAtUnixMs: args["created-at-unix-ms"]
    });
    writeJson(vaultPath, updatedVault);
    maybeWriteMetadata(updatedVault);
    printAccountSummary("flowchain.wallet.account_added.v0", updatedVault.publicAccounts.at(-1), { includePublicKey: true });
  } else if (command === "rotate") {
    const vaultPath = required("vault");
    const vault = readJson(vaultPath);
    const updatedVault = rotateEncryptedTestVaultAccount({
      vault,
      password: password(),
      signerKeyId: required("signer-key-id"),
      label: args.label,
      chainId: args["chain-id"],
      createdAtUnixMs: args["created-at-unix-ms"]
    });
    writeJson(vaultPath, updatedVault);
    maybeWriteMetadata(updatedVault);
    printAccountSummary("flowchain.wallet.account_rotated.v0", updatedVault.publicAccounts.at(-1), { includePublicKey: true });
  } else if (command === "sign") {
    const document = readJson(required("document"));
    await signAndPrint(document);
  } else if (command === "sign-transfer") {
    await signAndPrint(buildProductTransferDocument({
      fromAccountId: required("from"),
      toAccountId: required("to"),
      assetId: args["asset-id"] ?? LOCAL_TEST_UNIT_ASSET_ID,
      amount: required("amount"),
      accountNonce: args["account-nonce"] ?? required("nonce"),
      deadlineBlock: args["deadline-block"] ?? "0",
      memo: args.memo,
      memoHash: args["memo-hash"]
    }));
  } else if (command === "sign-token-launch") {
    await signAndPrint(buildProductTokenLaunchDocument({
      issuerAccountId: required("owner"),
      ownerAccountId: required("owner"),
      symbol: required("symbol"),
      name: required("name"),
      supply: required("supply"),
      decimals: args.decimals ?? 18,
      accountNonce: args["account-nonce"] ?? required("nonce"),
      tokenId: args["token-id"],
      metadataHash: args["metadata-hash"],
      launchPolicyHash: args["launch-policy-hash"]
    }));
  } else if (command === "sign-token-transfer") {
    await signAndPrint(buildProductTransferDocument({
      fromAccountId: required("from"),
      toAccountId: required("to"),
      assetId: required("token-id"),
      amount: required("amount"),
      accountNonce: args["account-nonce"] ?? required("nonce"),
      deadlineBlock: args["deadline-block"] ?? "0",
      memo: args.memo,
      memoHash: args["memo-hash"]
    }));
  } else if (command === "sign-pool-create") {
    await signAndPrint(buildProductPoolCreateDocument({
      creatorAccountId: required("owner"),
      baseAssetId: required("base-asset-id"),
      quoteAssetId: required("quote-asset-id"),
      baseReserve: required("base-reserve"),
      quoteReserve: required("quote-reserve"),
      feeBps: args["fee-bps"] ?? 30,
      tickSpacing: args["tick-spacing"] ?? 1,
      poolId: args["pool-id"],
      metadataHash: args["metadata-hash"],
      accountNonce: args["account-nonce"] ?? required("nonce")
    }));
  } else if (command === "sign-add-liquidity") {
    await signAndPrint(buildProductAddLiquidityDocument({
      providerAccountId: required("owner"),
      poolId: required("pool-id"),
      baseAmount: required("base-amount"),
      quoteAmount: required("quote-amount"),
      minLiquidityTokens: required("min-liquidity-tokens"),
      deadlineBlock: required("deadline-block"),
      accountNonce: args["account-nonce"] ?? required("nonce")
    }));
  } else if (command === "sign-remove-liquidity") {
    await signAndPrint(buildProductRemoveLiquidityDocument({
      providerAccountId: required("owner"),
      poolId: required("pool-id"),
      liquidityTokens: required("liquidity-tokens"),
      minBaseAmount: required("min-base-amount"),
      minQuoteAmount: required("min-quote-amount"),
      deadlineBlock: required("deadline-block"),
      accountNonce: args["account-nonce"] ?? required("nonce")
    }));
  } else if (command === "sign-swap") {
    await signAndPrint(buildProductSwapDocument({
      traderAccountId: required("owner"),
      poolId: required("pool-id"),
      assetInId: required("input-token-id"),
      assetOutId: required("output-token-id"),
      amountIn: required("input-amount"),
      minAmountOut: required("minimum-output"),
      deadlineBlock: required("deadline-block"),
      accountNonce: args["account-nonce"] ?? required("nonce")
    }));
  } else if (command === "sign-withdrawal-intent") {
    await signAndPrint(buildBridgeWithdrawalIntentDocument({
      creditId: required("credit-id"),
      depositId: required("deposit-id"),
      sourceChainId: args["source-chain-id"] ?? required("chain-id"),
      destinationChainId: args["destination-chain-id"] ?? 8453,
      token: required("bridge-asset"),
      amount: required("amount"),
      flowchainAccount: required("account"),
      baseRecipient: required("base-address"),
      requestedAt: args["requested-at"]
    }));
  } else if (command === "sign-finality") {
    await signAndPrint(buildFinalityActionDocument({
      receiptId: required("receipt-id"),
      reportId: required("report-id"),
      challengeRoot: args["challenge-root"],
      finalityState: args["finality-state-code"] ?? 6,
      finalizedAtUnixMs: required("finalized-at-unix-ms"),
      finalizedBlockNumber: required("finalized-block-number"),
      finalizedBlockHash: required("finalized-block-hash"),
      policyHash: required("policy-hash")
    }));
  } else if (command === "verify") {
    if (!args.envelope && !args.document) {
      runVerificationSmoke();
    } else {
      const envelope = readJson(required("envelope"));
      const document = args.document ? readJson(args.document) : undefined;
      const context = verificationContext(document);
      const result = args.runtime || args["require-canonical"]
        ? verifyFlowchainEnvelope({
          document,
          envelope,
          context: {
            ...context,
            networkProfile: args["network-profile"],
            nowUnixMs: args["now-unix-ms"],
            requireCanonical: Boolean(args["require-canonical"])
          }
        })
        : envelope.schema === "flowchain.wallet_signed_envelope.v0"
          ? verifyWalletSignedEnvelope({ envelope, context })
          : validateLocalTransactionEnvelope({ document, envelope, context });
      console.log(JSON.stringify(result, null, 2));
      process.exitCode = (result.valid ?? result.ok) ? 0 : 1;
    }
  } else if (command === "submit") {
    const envelope = readJson(required("envelope"));
    const response = await submitEnvelope(envelope);
    console.log(JSON.stringify(response, null, 2));
    process.exitCode = response.error ? 1 : 0;
  } else if (command === "query") {
    const response = await queryControlPlane(required("method"), args.params ? parseJsonValue(args.params) : {});
    console.log(JSON.stringify(response, null, 2));
    process.exitCode = response.error ? 1 : 0;
  } else if (command === "derive-metadata") {
    const metadata = flowchainPublicAccountMetadata({
      publicKey: required("public-key"),
      role: args.role ?? "user",
      label: args.label,
      createdAtUnixMs: args["created-at-unix-ms"]
    });
    console.log(JSON.stringify(metadata, null, 2));
  } else {
    usage();
    process.exitCode = 1;
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}

function parseCommand(argv) {
  const rawCommand = argv[0];
  if (rawCommand === "list" && argv[1] === "accounts") {
    return { command: "list", args: parseArgs(argv.slice(2)) };
  }
  return { command: rawCommand, args: parseArgs(argv.slice(1)) };
}

function parseArgs(argv) {
  const parsed = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith("--")) {
      continue;
    }
    const key = arg.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith("--")) {
      parsed[key] = true;
    } else {
      parsed[key] = next;
      i += 1;
    }
  }
  return parsed;
}

async function signAndPrint(document) {
  const vault = readJson(required("vault"));
  const signerKeyId = args["signer-key-id"] ?? selectSignerKeyId(vault, args.from ?? args.owner ?? args.account);
  const envelope = await signWalletDocumentWithVault({
    vault,
    password: password(),
    signerKeyId,
    document,
    chainId: required("chain-id"),
    nonce: required("nonce"),
    issuedAtUnixMs: args["issued-at-unix-ms"],
    expiresAtUnixMs: args["expires-at-unix-ms"] ?? null
  });
  const outPath = args.out ?? defaultEnvelopePath(envelope.txId);
  writeJson(outPath, envelope);
  console.log(JSON.stringify({
    schema: "flowchain.wallet.sign_result.v0",
    txId: envelope.txId,
    chainId: envelope.chainId,
    payloadType: envelope.payloadType,
    signerAddress: envelope.signerAddress,
    nonce: envelope.nonce,
    envelopePath: outPath,
    verification: envelope.verification
  }, null, 2));
}

function selectSignerKeyId(vault, preferredAddress) {
  const accounts = vault.publicAccounts ?? [];
  if (preferredAddress) {
    const account = accounts.find((candidate) =>
      candidate.signerId === preferredAddress ||
      candidate.accountId === preferredAddress ||
      candidate.address === preferredAddress
    );
    if (!account) {
      throw new Error("vault does not contain an active signer for the requested account");
    }
    return account.signerKeyId;
  }
  const account = accounts.find((candidate) => candidate.active !== false) ?? accounts[0];
  if (!account) {
    throw new Error("vault does not contain any signer accounts");
  }
  return account.signerKeyId;
}

function maybeWriteMetadata(vault) {
  if (args["metadata-out"]) {
    writeJson(args["metadata-out"], exportLocalWalletPublicMetadata(vault, { updatedAtUnixMs: args["updated-at-unix-ms"] }));
  }
}

function printAccountSummary(schema, account, { includePublicKey }) {
  const output = {
    schema,
    address: account.address ?? account.signerId
  };
  if (includePublicKey) {
    output.publicKey = account.publicKey;
  }
  console.log(JSON.stringify(output, null, 2));
}

function password() {
  const value = args.password ?? process.env.FLOWMEMORY_TEST_WALLET_PASSWORD;
  if (!value) {
    throw new Error("set --password or FLOWMEMORY_TEST_WALLET_PASSWORD for the local wallet vault");
  }
  return value;
}

function importedPrivateKey() {
  if (args["private-key-env"]) {
    const value = process.env[args["private-key-env"]];
    if (!value) {
      throw new Error(`environment variable ${args["private-key-env"]} is empty`);
    }
    return normalizePrivateKey(value);
  }
  if (args["private-key-file"]) {
    return normalizePrivateKey(readFileSync(args["private-key-file"], "utf8"));
  }
  if (args["private-key-stdin"]) {
    return normalizePrivateKey(readFileSync(0, "utf8"));
  }
  throw new Error("import requires --private-key-env, --private-key-file, or --private-key-stdin");
}

function normalizePrivateKey(value) {
  const trimmed = String(value).trim();
  if (!/^0x[0-9a-fA-F]{64}$/.test(trimmed)) {
    throw new Error("imported private key must be a 32-byte hex value");
  }
  return trimmed;
}

function unlockVaultSafely(vault) {
  try {
    return unlockEncryptedTestVault({ vault, password: password() });
  } catch {
    throw new Error("vault unlock failed");
  }
}

function sessionPath() {
  return args["session-path"] ?? `${requiredOrDefault("vault", "devnet/local/wallet/operator-vault.local.json")}.session.local.json`;
}

function verificationContext(document) {
  const context = {};
  if (document) {
    context.document = document;
  }
  if (args["chain-id"]) {
    context.chainId = args["chain-id"];
  }
  if (args["expected-nonce"]) {
    context.expectedNonce = args["expected-nonce"];
  }
  if (args["expected-signer-id"]) {
    context.expectedSignerId = args["expected-signer-id"];
  }
  if (args["expected-signer-address"]) {
    context.expectedSignerAddress = args["expected-signer-address"];
  }
  return context;
}

function runVerificationSmoke() {
  const fixture = readJson(resolve(import.meta.dirname, "..", "fixtures", "product-testnet-transactions.json"));
  const vector = fixture.transactions.positive[0];
  const document = fixture.documents.positive.find((entry) => entry.name === vector.objectName).document;
  const result = validateLocalTransactionEnvelope({
    document,
    envelope: vector.envelope,
    context: { chainId: fixture.chainId, expectedNonce: vector.envelope.nonce }
  });
  console.log(JSON.stringify({
    schema: "flowchain.wallet.verify_smoke.v0",
    vector: vector.name,
    txId: vector.envelope.envelopeId,
    result
  }, null, 2));
  process.exitCode = result.valid ? 0 : 1;
}

async function submitEnvelope(envelope) {
  const { dispatchJsonRpc, loadControlPlaneState } = await import("../../services/control-plane/src/index.ts");
  const state = loadControlPlaneState({
    txIntakePath: args["intake-path"] ?? "devnet/local/intake/transactions.ndjson"
  });
  return dispatchJsonRpc({
    jsonrpc: "2.0",
    id: 1,
    method: "transaction_submit",
    params: {
      signedEnvelope: envelope,
      submittedBy: args["submitted-by"] ?? "flowchain-wallet-cli"
    }
  }, { state });
}

async function queryControlPlane(method, params) {
  const { dispatchJsonRpc, loadControlPlaneState } = await import("../../services/control-plane/src/index.ts");
  const state = loadControlPlaneState({
    txIntakePath: args["intake-path"] ?? "devnet/local/intake/transactions.ndjson"
  });
  return dispatchJsonRpc({
    jsonrpc: "2.0",
    id: 1,
    method,
    params
  }, { state });
}

function parseJsonValue(value) {
  if (existsSync(value)) {
    return readJson(value);
  }
  return JSON.parse(value);
}

function required(name) {
  if (!args[name]) {
    throw new Error(`missing --${name}`);
  }
  return args[name];
}

function requiredOrDefault(name, defaultValue) {
  return args[name] ?? defaultValue;
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function writeOutput(path, value) {
  if (path) {
    writeJson(path, value);
  }
}

function writeJson(path, value) {
  const fullPath = resolve(path);
  mkdirSync(dirname(fullPath), { recursive: true });
  writeFileSync(fullPath, `${JSON.stringify(value, null, 2)}\n`);
  return fullPath;
}

function defaultEnvelopePath(txId) {
  return `devnet/local/wallet/envelopes/${txId}.json`;
}

function usage() {
  console.error(`Usage:
  node src/wallet-cli.js create --vault <ignored-vault> --chain-id <id> [--metadata-out <public-json>]
  node src/wallet-cli.js import --vault <ignored-vault> --private-key-env <env-name> --chain-id <id>
  node src/wallet-cli.js unlock --vault <ignored-vault>
  node src/wallet-cli.js lock --vault <ignored-vault>
  node src/wallet-cli.js list accounts --vault <ignored-vault> [--public]
  node src/wallet-cli.js metadata --vault <ignored-vault>
  node src/wallet-cli.js export-metadata --vault <ignored-vault> --out <public-json>
  node src/wallet-cli.js verify-metadata --metadata <public-json> [--chain-id <id>]
  node src/wallet-cli.js add-account --vault <ignored-vault> --chain-id <id> [--role agent]
  node src/wallet-cli.js rotate --vault <ignored-vault> --signer-key-id <id>
  node src/wallet-cli.js sign --vault <ignored-vault> --document <path> --chain-id <id> --nonce <n> [--signer-key-id <id>] [--out <path>]
  node src/wallet-cli.js sign-transfer --vault <ignored-vault> --from <account> --to <account> --amount <n> --nonce <n> --chain-id <id>
  node src/wallet-cli.js sign-token-launch --vault <ignored-vault> --owner <account> --symbol <SYM> --name <name> --supply <n> --nonce <n> --chain-id <id>
  node src/wallet-cli.js sign-token-transfer --vault <ignored-vault> --from <account> --to <account> --token-id <id> --amount <n> --nonce <n> --chain-id <id>
  node src/wallet-cli.js sign-pool-create --vault <ignored-vault> --owner <account> --base-asset-id <id> --quote-asset-id <id> --base-reserve <n> --quote-reserve <n> --nonce <n> --chain-id <id>
  node src/wallet-cli.js sign-add-liquidity --vault <ignored-vault> --owner <account> --pool-id <id> --base-amount <n> --quote-amount <n> --min-liquidity-tokens <n> --deadline-block <n> --nonce <n> --chain-id <id>
  node src/wallet-cli.js sign-remove-liquidity --vault <ignored-vault> --owner <account> --pool-id <id> --liquidity-tokens <n> --min-base-amount <n> --min-quote-amount <n> --deadline-block <n> --nonce <n> --chain-id <id>
  node src/wallet-cli.js sign-swap --vault <ignored-vault> --owner <account> --pool-id <id> --input-token-id <id> --output-token-id <id> --input-amount <n> --minimum-output <n> --deadline-block <n> --nonce <n> --chain-id <id>
  node src/wallet-cli.js sign-withdrawal-intent --vault <ignored-vault> --account <account> --base-address <0x...> --amount <n> --bridge-asset <0x...> --credit-id <id> --deposit-id <id> --nonce <n> --chain-id <id>
  node src/wallet-cli.js verify --envelope <wallet-envelope> [--document <path>] [--chain-id <id>] [--expected-nonce <n>] [--network-profile <profile>] [--require-canonical] [--runtime]
  node src/wallet-cli.js submit --envelope <wallet-envelope> [--intake-path <ignored-ndjson>]
  node src/wallet-cli.js query --method <control-plane-method> [--params <json-or-file>]
  node src/wallet-cli.js derive-metadata --public-key <compressed-or-uncompressed-public-key> [--role user] [--label <label>]`);
}
