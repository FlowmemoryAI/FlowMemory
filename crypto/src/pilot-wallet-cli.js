#!/usr/bin/env node
import { readFileSync, writeFileSync } from "node:fs";

import {
  createPilotOperatorConfigFromEnv,
  exportPilotPublicMetadata
} from "./pilot-operator.js";
import {
  exportVaultPublicMetadata,
  signLocalTransactionWithVault
} from "./wallet.js";
import { validatePilotOperatorEnvelope } from "./pilot-envelope-validation.js";

const command = process.argv[2];
const args = parseArgs(process.argv.slice(3));

try {
  if (command === "config-from-env") {
    const config = createPilotOperatorConfigFromEnv({
      createdAtUnixMs: args["created-at-unix-ms"]
    });
    writeOutput(args.out, config);
    console.log(JSON.stringify(config, null, 2));
  } else if (command === "metadata") {
    const config = readJson(required("config"));
    const vault = readJson(required("vault"));
    const metadata = exportPilotPublicMetadata({
      config,
      walletMetadata: exportVaultPublicMetadata(vault)
    });
    writeOutput(args.out, metadata);
    console.log(JSON.stringify(metadata, null, 2));
  } else if (command === "sign") {
    const config = readJson(required("config"));
    const vault = readJson(required("vault"));
    const document = readJson(required("document"));
    const signerKeyId = args["signer-key-id"] ?? selectOperatorSignerKeyId({ vault, config });
    const envelope = await signLocalTransactionWithVault({
      vault,
      password: password(),
      signerKeyId,
      document,
      chainId: args["chain-id"] ?? config.chainId,
      nonce: required("nonce"),
      issuedAtUnixMs: args["issued-at-unix-ms"]
    });
    writeOutput(args.out, envelope);
    console.log(JSON.stringify(envelope, null, 2));
  } else if (command === "verify") {
    const config = readJson(required("config"));
    const document = readJson(required("document"));
    const envelope = readJson(required("envelope"));
    const result = validatePilotOperatorEnvelope({
      document,
      envelope,
      context: {
        expectedChainId: args["chain-id"] ?? config.chainId,
        expectedContractAddress: args["contract-address"] ?? config.contractAddress,
        expectedOperatorId: args["operator-id"] ?? config.operatorId,
        expectedNonce: args["expected-nonce"],
        nowUnixMs: args["now-unix-ms"]
      }
    });
    console.log(JSON.stringify(result, null, 2));
    process.exitCode = result.valid ? 0 : 1;
  } else if (command === "next-commands") {
    const config = readJson(required("config"));
    for (const nextCommand of config.nextCommands) {
      console.log(nextCommand);
    }
  } else {
    usage();
    process.exitCode = 1;
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}

function selectOperatorSignerKeyId({ vault, config }) {
  const account = (vault.publicAccounts ?? []).find(
    (candidate) =>
      candidate.signerId === config.operatorId &&
      candidate.signerRole === "operator" &&
      candidate.active !== false
  );
  if (!account) {
    throw new Error("vault does not contain an active operator signer for the pilot config");
  }
  return account.signerKeyId;
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

function password() {
  const value = args.password ?? process.env.FLOWMEMORY_TEST_WALLET_PASSWORD;
  if (!value) {
    throw new Error("set --password or FLOWMEMORY_TEST_WALLET_PASSWORD for the local pilot vault");
  }
  return value;
}

function required(name) {
  if (!args[name]) {
    throw new Error(`missing --${name}`);
  }
  return args[name];
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function writeOutput(path, value) {
  if (path) {
    writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
  }
}

function usage() {
  console.error(`Usage:
  node src/pilot-wallet-cli.js config-from-env [--created-at-unix-ms <ms>] [--out <path>]
  node src/pilot-wallet-cli.js metadata --config <path> --vault <path> [--out <path>]
  node src/pilot-wallet-cli.js sign --config <path> --vault <path> --document <path> --nonce <n> [--chain-id <id>] [--signer-key-id <id>] [--issued-at-unix-ms <ms>] [--out <path>]
  node src/pilot-wallet-cli.js verify --config <path> --document <path> --envelope <path> [--chain-id <id>] [--contract-address <address>] [--operator-id <id>] [--expected-nonce <n>] [--now-unix-ms <ms>]
  node src/pilot-wallet-cli.js next-commands --config <path>`);
}
