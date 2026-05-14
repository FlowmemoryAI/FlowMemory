#!/usr/bin/env node
import { readFileSync, writeFileSync } from "node:fs";
import {
  addEncryptedTestVaultAccount,
  createEncryptedTestVault,
  exportVaultPublicMetadata,
  listVaultPublicAccounts,
  rotateEncryptedTestVaultAccount,
  signLocalTransactionWithVault,
  unlockEncryptedTestVault,
  validateLocalTransactionEnvelope,
  verifyFlowchainEnvelope,
  flowchainPublicAccountMetadata
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
  } else if (command === "check") {
    const vault = readJson(required("vault"));
    const session = unlockEncryptedTestVault({ vault, password: password() });
    console.log(JSON.stringify({
      schema: "flowmemory.crypto.local-test-vault-check.v0",
      vaultId: session.vaultId,
      accountCount: session.accounts.length,
      publicAccountCount: session.publicAccounts.length,
      unlocked: true
    }, null, 2));
  } else if (command === "list") {
    const vault = readJson(required("vault"));
    unlockEncryptedTestVault({ vault, password: password() });
    console.log(JSON.stringify(listVaultPublicAccounts(vault), null, 2));
  } else if (command === "metadata") {
    const vault = readJson(required("vault"));
    console.log(JSON.stringify(exportVaultPublicMetadata(vault), null, 2));
  } else if (command === "add-account") {
    const vaultPath = required("vault");
    const vault = readJson(vaultPath);
    const updatedVault = addEncryptedTestVaultAccount({
      vault,
      password: password(),
      label: args.label ?? "local-account",
      signerRole: args.role ?? "agent"
    });
    writeOutput(vaultPath, updatedVault);
    console.log(JSON.stringify(exportVaultPublicMetadata(updatedVault), null, 2));
  } else if (command === "rotate") {
    const vaultPath = required("vault");
    const vault = readJson(vaultPath);
    const updatedVault = rotateEncryptedTestVaultAccount({
      vault,
      password: password(),
      signerKeyId: required("signer-key-id"),
      label: args.label
    });
    writeOutput(vaultPath, updatedVault);
    console.log(JSON.stringify(exportVaultPublicMetadata(updatedVault), null, 2));
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
      nonce: required("nonce"),
      issuedAtUnixMs: args["issued-at-unix-ms"],
      expiresAtUnixMs: args["expires-at-unix-ms"],
      networkProfile: args["network-profile"] ?? "local-chain",
      payloadType: args["payload-type"]
    });
    writeOutput(args.out, envelope);
    console.log(JSON.stringify(envelope, null, 2));
  } else if (command === "verify") {
    const document = readJson(required("document"));
    const envelope = readJson(required("envelope"));
    const context = {};
    if (args["chain-id"]) {
      context.chainId = args["chain-id"];
    }
    if (args["expected-nonce"]) {
      context.expectedNonce = args["expected-nonce"];
    }
    if (args["expected-signer-id"]) {
      context.expectedSignerId = args["expected-signer-id"];
    }
    if (args["network-profile"]) {
      context.networkProfile = args["network-profile"];
    }
    if (args["now-unix-ms"]) {
      context.nowUnixMs = args["now-unix-ms"];
    }
    const result = args["runtime"] || args["require-canonical"]
      ? verifyFlowchainEnvelope({ document, envelope, context: { ...context, requireCanonical: true } })
      : validateLocalTransactionEnvelope({ document, envelope, context });
    console.log(JSON.stringify(result, null, 2));
    process.exitCode = (result.valid ?? result.ok) ? 0 : 1;
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
  node src/wallet-cli.js check --vault <path> [--password <local-test-password>]
  node src/wallet-cli.js list --vault <path> [--password <local-test-password>]
  node src/wallet-cli.js metadata --vault <path>
  node src/wallet-cli.js add-account --vault <path> [--password <local-test-password>] [--label <label>] [--role agent]
  node src/wallet-cli.js rotate --vault <path> --signer-key-id <id> [--password <local-test-password>] [--label <label>]
  node src/wallet-cli.js sign --vault <path> --document <path> --chain-id <id> --nonce <n> [--network-profile local-chain] [--payload-type <type>] [--signer-key-id <id>] [--issued-at-unix-ms <ms>] [--expires-at-unix-ms <ms>] [--out <path>]
  node src/wallet-cli.js verify --document <path> --envelope <path> [--chain-id <id>] [--network-profile <profile>] [--expected-nonce <n>] [--expected-signer-id <id>] [--require-canonical] [--runtime]
  node src/wallet-cli.js derive-metadata --public-key <compressed-or-uncompressed-public-key> [--role user] [--label <label>]`);
}
