#!/usr/bin/env node
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { stdin as input, stdout as output } from "node:process";
import { createInterface } from "node:readline/promises";

import {
  DEFAULT_WALLET_PATH,
  createWalletVault,
  exportWalletPublicMetadata,
  importWalletPublicMetadata,
  listWalletPublicAccounts,
  rotateWalletAccount,
  signWalletTransaction,
  unlockWalletVault,
  verifyWalletTransaction
} from "./wallet.js";
import { keccakUtf8 } from "./hashes.js";

const DEFAULT_ENVELOPE_PATH = resolve(DEFAULT_WALLET_PATH, "..", "last-signed-envelope.local.json");
const DEFAULT_PUBLIC_METADATA_PATH = resolve(DEFAULT_WALLET_PATH, "..", "public-metadata.local.json");

const command = process.argv[2] ?? "help";
const args = process.argv.slice(3);

try {
  if (command === "create") {
    const password = await passwordFromEnvOrPrompt();
    print(
      createWalletVault({
        password,
        vaultPath: option("--vault", DEFAULT_WALLET_PATH),
        label: option("--label", "flowchain-local-operator"),
        signerRole: option("--role", "operator"),
        force: hasFlag("--force")
      })
    );
  } else if (command === "unlock") {
    const password = await passwordFromEnvOrPrompt();
    const result = unlockWalletVault({
      password,
      vaultPath: option("--vault", DEFAULT_WALLET_PATH)
    });
    print({
      schema: "flowchain.local_wallet_unlock_result.v0",
      unlocked: true,
      public: result.publicMetadata
    });
  } else if (command === "list") {
    print(listWalletPublicAccounts({ vaultPath: option("--vault", DEFAULT_WALLET_PATH) }));
  } else if (command === "rotate") {
    const password = await passwordFromEnvOrPrompt();
    print(
      rotateWalletAccount({
        password,
        vaultPath: option("--vault", DEFAULT_WALLET_PATH),
        label: option("--label", "flowchain-local-account"),
        signerRole: option("--role", "operator")
      })
    );
  } else if (command === "sign") {
    const password = await passwordFromEnvOrPrompt();
    const outPath = option("--out", DEFAULT_ENVELOPE_PATH);
    const envelope = await signWalletTransaction({
      password,
      vaultPath: option("--vault", DEFAULT_WALLET_PATH),
      accountId: option("--account", undefined),
      chainId: option("--chain-id", "31337"),
      nonce: option("--nonce", undefined),
      payload: readPayload(option("--payload", undefined))
    });
    writeJson(outPath, envelope);
    print({
      schema: "flowchain.local_wallet_sign_result.v0",
      envelopePath: outPath,
      envelope
    });
  } else if (command === "verify") {
    const envelope = readJson(option("--envelope", DEFAULT_ENVELOPE_PATH));
    print({
      schema: "flowchain.local_wallet_verify_result.v0",
      ...verifyWalletTransaction({
        envelope,
        expectedChainId: option("--chain-id", undefined),
        expectedSignerId: option("--signer", undefined)
      })
    });
  } else if (command === "export-public") {
    print(
      exportWalletPublicMetadata({
        vaultPath: option("--vault", DEFAULT_WALLET_PATH),
        outPath: option("--out", DEFAULT_PUBLIC_METADATA_PATH)
      })
    );
  } else if (command === "import-public") {
    print(
      importWalletPublicMetadata({
        vaultPath: option("--vault", DEFAULT_WALLET_PATH),
        inPath: option("--in", DEFAULT_PUBLIC_METADATA_PATH)
      })
    );
  } else {
    printHelp();
    process.exit(command === "help" || command === "--help" || command === "-h" ? 0 : 1);
  }
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

function option(name, fallback) {
  const index = args.indexOf(name);
  if (index === -1) {
    return fallback;
  }
  const value = args[index + 1];
  if (!value || value.startsWith("--")) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

function hasFlag(name) {
  return args.includes(name);
}

async function passwordFromEnvOrPrompt() {
  if (process.env.FLOWCHAIN_WALLET_PASSWORD) {
    return process.env.FLOWCHAIN_WALLET_PASSWORD;
  }
  if (!process.stdin.isTTY) {
    throw new Error("set FLOWCHAIN_WALLET_PASSWORD or run interactively to unlock the local wallet");
  }
  const rl = createInterface({ input, output });
  try {
    return await rl.question("FlowChain local wallet password: ");
  } finally {
    rl.close();
  }
}

function readPayload(path) {
  if (path) {
    return readJson(path);
  }
  return {
    schema: "flowmemory.local_devnet.tx_payload.v0",
    objectType: "agent_account",
    tx: {
      type: "RegisterAgent",
      agentId: keccakUtf8("wallet-cli-demo-agent"),
      controller: "operator:wallet-cli-demo",
      modelPassportId: null,
      metadataHash: keccakUtf8("wallet-cli-demo-agent.metadata")
    }
  };
}

function readJson(path) {
  return JSON.parse(readFileSync(resolve(path), "utf8"));
}

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
}

function print(value) {
  console.log(JSON.stringify(value, null, 2));
}

function printHelp() {
  console.log(`FlowChain local wallet CLI

Commands:
  create [--vault <path>] [--label <label>] [--role operator|agent|verifier|hardware] [--force]
  unlock [--vault <path>]
  list [--vault <path>]
  rotate [--vault <path>] [--label <label>] [--role operator|agent|verifier|hardware]
  sign [--vault <path>] [--payload <json>] [--out <json>] [--account <id>] [--chain-id <id>] [--nonce <n>]
  verify [--envelope <json>] [--chain-id <id>] [--signer <id>]
  export-public [--vault <path>] [--out <json>]
  import-public [--vault <path>] [--in <json>]

Set FLOWCHAIN_WALLET_PASSWORD for non-interactive create, unlock, rotate, and sign.
Default local files are under crypto/.wallet/ and are ignored by git.`);
}
