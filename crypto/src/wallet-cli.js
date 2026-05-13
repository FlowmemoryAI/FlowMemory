#!/usr/bin/env node
import { readFileSync, writeFileSync } from "node:fs";
import {
  createEncryptedTestVault,
  exportVaultPublicMetadata,
  signLocalTransactionWithVault,
  validateLocalTransactionEnvelope
} from "./index.js";

const command = process.argv[2];
const args = parseArgs(process.argv.slice(3));

try {
  if (command === "create") {
    const vault = createEncryptedTestVault({
      password: password(),
      label: args.label ?? "local-operator",
      signerRole: args.role ?? "operator"
    });
    writeOutput(args.vault, vault);
    console.log(JSON.stringify(exportVaultPublicMetadata(vault), null, 2));
  } else if (command === "sign") {
    const vault = readJson(required("vault"));
    const document = readJson(required("document"));
    const signerKeyId = args["signer-key-id"] ?? vault.publicAccounts[0]?.signerKeyId;
    const envelope = await signLocalTransactionWithVault({
      vault,
      password: password(),
      signerKeyId,
      document,
      chainId: required("chain-id"),
      nonce: required("nonce")
    });
    writeOutput(args.out, envelope);
    console.log(JSON.stringify(envelope, null, 2));
  } else if (command === "verify") {
    const document = readJson(required("document"));
    const envelope = readJson(required("envelope"));
    const result = validateLocalTransactionEnvelope({
      document,
      envelope,
      context: args["chain-id"] ? { chainId: args["chain-id"] } : {}
    });
    console.log(JSON.stringify(result, null, 2));
    process.exitCode = result.valid ? 0 : 1;
  } else {
    usage();
    process.exitCode = 1;
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
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
    throw new Error("set --password or FLOWMEMORY_TEST_WALLET_PASSWORD for the local test vault");
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
  node src/wallet-cli.js create --vault <path> [--password <local-test-password>] [--label <label>] [--role operator]
  node src/wallet-cli.js sign --vault <path> --document <path> --chain-id <id> --nonce <n> [--signer-key-id <id>] [--out <path>]
  node src/wallet-cli.js verify --document <path> --envelope <path> [--chain-id <id>]`);
}
