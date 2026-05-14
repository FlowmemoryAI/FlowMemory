#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

const rawArgs = process.argv.slice(2);
const args = new Set(rawArgs);
const broadcast = args.has("--broadcast");
const planOnly = args.has("--plan-only");
const json = args.has("--json");

function readArgValue(name, fallback) {
  const index = rawArgs.indexOf(name);
  if (index === -1) return fallback;
  const value = rawArgs[index + 1];
  if (value === undefined || value.startsWith("--")) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

const planOut = resolve(
  readArgValue(
    "--plan-out",
    process.env.BASE_SEPOLIA_REHEARSAL_PLAN_OUT ?? "fixtures/deployments/base-sepolia-rehearsal-plan.json",
  ),
);
const artifactOut = resolve(
  readArgValue(
    "--artifact-out",
    process.env.BASE_SEPOLIA_REHEARSAL_ARTIFACT_OUT ?? "fixtures/deployments/base-sepolia-rehearsal.latest.json",
  ),
);

const rpcUrl = process.env.BASE_SEPOLIA_RPC_URL;
const deployerKey = process.env.BASE_SEPOLIA_DEPLOYER_KEY_HEX;
const basescanApiKey = process.env.BASE_SEPOLIA_BASESCAN_API_KEY ?? process.env.BASESCAN_API_KEY;
const explicitGeneratedAt = readArgValue(
  "--generated-at",
  process.env.BASE_SEPOLIA_REHEARSAL_GENERATED_AT ?? null,
);

function readExistingGeneratedAt(path) {
  if (!existsSync(path)) return null;
  try {
    const parsed = JSON.parse(readFileSync(path, "utf8"));
    return typeof parsed.generatedAt === "string" ? parsed.generatedAt : null;
  } catch {
    return null;
  }
}

const generatedAt = explicitGeneratedAt ?? (planOnly ? readExistingGeneratedAt(planOut) : null) ?? new Date().toISOString();

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function validateEnvForForgeRun() {
  if (!rpcUrl) {
    throw new Error("BASE_SEPOLIA_RPC_URL is required for Base Sepolia deployment runs");
  }
  if (!deployerKey) {
    throw new Error("BASE_SEPOLIA_DEPLOYER_KEY_HEX is required for Base Sepolia deployment runs");
  }
  if (!/^0x[0-9a-fA-F]{64}$/.test(deployerKey)) {
    throw new Error("BASE_SEPOLIA_DEPLOYER_KEY_HEX must be a 32-byte hex private key with 0x prefix");
  }
}

function redactedEnv() {
  return {
    BASE_SEPOLIA_RPC_URL: rpcUrl ? "<set>" : "<missing>",
    BASE_SEPOLIA_DEPLOYER_KEY_HEX: deployerKey ? "<set:redacted>" : "<missing>",
    BASE_SEPOLIA_BASESCAN_API_KEY: process.env.BASE_SEPOLIA_BASESCAN_API_KEY ? "<set:redacted>" : "<missing>",
    BASESCAN_API_KEY: process.env.BASESCAN_API_KEY ? "<set:redacted>" : "<missing>",
    BASE_SEPOLIA_FLOWPULSE_ADDRESSES: process.env.BASE_SEPOLIA_FLOWPULSE_ADDRESSES ? "<set>" : "<missing>",
    BASE_SEPOLIA_FROM_BLOCK: process.env.BASE_SEPOLIA_FROM_BLOCK ? "<set>" : "<missing>",
    BASE_SEPOLIA_TO_BLOCK: process.env.BASE_SEPOLIA_TO_BLOCK ? "<set>" : "<missing>",
    BASE_SEPOLIA_FINALIZED_BLOCK: process.env.BASE_SEPOLIA_FINALIZED_BLOCK ? "<set>" : "<missing>",
    BASE_SEPOLIA_REHEARSAL_PLAN_OUT: process.env.BASE_SEPOLIA_REHEARSAL_PLAN_OUT ? "<set>" : "<default>",
    BASE_SEPOLIA_REHEARSAL_ARTIFACT_OUT: process.env.BASE_SEPOLIA_REHEARSAL_ARTIFACT_OUT
      ? "<set>"
      : "<default>",
  };
}

function deploymentPlan() {
  const forgeArgsRedacted = [
    "script",
    "script/DeployLaunchCandidate.s.sol:DeployLaunchCandidate",
    "--rpc-url",
    "$BASE_SEPOLIA_RPC_URL",
    "--private-key",
    "$BASE_SEPOLIA_DEPLOYER_KEY_HEX",
    "--chain-id",
    "84532",
  ];
  if (broadcast) {
    forgeArgsRedacted.push("--broadcast", "--slow");
  }

  return {
    schema: "flowmemory.base_sepolia.deployment_rehearsal_plan.v0",
    generatedAt,
    mode: planOnly ? "plan-only" : broadcast ? "broadcast" : "dry-run",
    productionReady: false,
    network: {
      name: "Base Sepolia",
      chainId: "84532",
      explorer: "https://sepolia.basescan.org",
    },
    environment: redactedEnv(),
    requiredEnv: [
      "BASE_SEPOLIA_RPC_URL",
      "BASE_SEPOLIA_DEPLOYER_KEY_HEX",
    ],
    optionalEnv: [
      "BASE_SEPOLIA_BASESCAN_API_KEY",
      "BASESCAN_API_KEY",
      "BASE_SEPOLIA_FLOWPULSE_ADDRESSES",
      "BASE_SEPOLIA_FROM_BLOCK",
      "BASE_SEPOLIA_TO_BLOCK",
      "BASE_SEPOLIA_FINALIZED_BLOCK",
      "BASE_SEPOLIA_REHEARSAL_PLAN_OUT",
      "BASE_SEPOLIA_REHEARSAL_ARTIFACT_OUT",
      "BASE_SEPOLIA_REHEARSAL_GENERATED_AT",
    ],
    deploys: [
      "RootfieldRegistry",
      "FlowMemoryHookAdapter",
      "ArtifactRegistry",
      "CursorRegistry",
      "ReceiptVerifier",
      "WorkerRegistry",
      "VerifierRegistry",
      "WorkReceiptRegistry",
      "VerifierReportRegistry",
      "WorkDebtScheduler",
    ],
    forgeCommand: {
      program: "forge",
      args: forgeArgsRedacted,
      broadcast,
      note: "Dry run is default. Add --broadcast only when the operator has funded the deployer and accepts testnet gas spend.",
    },
    writeRehearsal: {
      rootfieldRegistration: [
        "cast send <RootfieldRegistry> \"registerRootfield(bytes32,bytes32,bytes32,string)\" <rootfieldId> <schemaHash> <metadataHash> <metadataURI> --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $BASE_SEPOLIA_DEPLOYER_KEY_HEX",
        "cast send <RootfieldRegistry> \"submitRoot(bytes32,bytes32,bytes32,bytes32,string)\" <rootfieldId> <root> <artifactCommitment> <parentPulseId> <evidenceURI> --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $BASE_SEPOLIA_DEPLOYER_KEY_HEX",
      ],
      swapMemorySignalAdapter: [
        "cast send <FlowMemoryHookAdapter> \"afterSwap(address,bytes32,bytes32,bytes32,bytes)\" <sender> <poolId> <rootfieldId> <commitment> <hookData> --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $BASE_SEPOLIA_DEPLOYER_KEY_HEX",
      ],
    },
    readRehearsal: {
      rootfieldReadback:
        "cast call <RootfieldRegistry> \"getRootfield(bytes32)\" <rootfieldId> --rpc-url $BASE_SEPOLIA_RPC_URL",
      flowPulseReader:
        "npm run index:base-sepolia -- --rpc-url $BASE_SEPOLIA_RPC_URL --address <RootfieldRegistry> --address <FlowMemoryHookAdapter> --from-block <deployBlock> --to-block <latestBlock> --finalized-block <safeFinalizedBlock>",
      resumeReader:
        "npm run index:base-sepolia -- --rpc-url $BASE_SEPOLIA_RPC_URL --address <RootfieldRegistry> --address <FlowMemoryHookAdapter> --resume-from-checkpoint --to-block <latestBlock>",
    },
    verification: {
      apiKeyEnv: basescanApiKey ? "<set:redacted>" : "BASE_SEPOLIA_BASESCAN_API_KEY or BASESCAN_API_KEY",
      command:
        "forge verify-contract --chain-id 84532 <address> <ContractName> --etherscan-api-key $BASE_SEPOLIA_BASESCAN_API_KEY",
    },
    rollback: [
      "Do not reuse a partially failed deployment artifact as canonical.",
      "If a contract deployment fails before broadcast completion, discard the artifact and rerun dry-run before broadcast.",
      "If smoke writes fail after contracts deploy, record the failed transaction hash, pause claims, and redeploy only if contract ownership or constructor inputs are wrong.",
      "No upgrade or proxy rollback exists in V0; rollback means stop using the address set and mark it superseded in docs/DEPLOYMENTS.",
    ],
    boundaries: [
      "Base Sepolia is a public testnet rehearsal, not production mainnet readiness.",
      "The V0 hook adapter is not a production Uniswap v4 PoolManager hook.",
      "txHash, transactionIndex, and logIndex are derived by the reader after receipts exist, never inside the hook.",
      "No private keys, RPC credentials, or explorer API keys are written to artifacts.",
    ],
  };
}

const plan = deploymentPlan();
writeJson(planOut, plan);

if (planOnly) {
  if (json) {
    console.log(JSON.stringify({ ok: true, planOut, plan }, null, 2));
  } else {
    console.log(`Base Sepolia deployment rehearsal plan written: ${planOut}`);
  }
  process.exit(0);
}

validateEnvForForgeRun();

const forgeArgs = [
  "script",
  "script/DeployLaunchCandidate.s.sol:DeployLaunchCandidate",
  "--rpc-url",
  rpcUrl,
  "--private-key",
  deployerKey,
  "--chain-id",
  "84532",
];

if (broadcast) {
  forgeArgs.push("--broadcast", "--slow");
}

const result = spawnSync("forge", forgeArgs, {
  cwd: process.cwd(),
  stdio: "inherit",
  shell: process.platform === "win32",
});

if (result.status !== 0) {
  throw new Error(`Base Sepolia deploy ${broadcast ? "broadcast" : "dry run"} failed with exit code ${result.status ?? "unknown"}`);
}

const artifact = {
  schema: "flowmemory.base_sepolia.deployment_rehearsal_artifact.v0",
  generatedAt,
  mode: broadcast ? "broadcast" : "dry-run",
  productionReady: false,
  network: plan.network,
  planPath: planOut,
  expectedFoundryBroadcastDir: "broadcast/DeployLaunchCandidate.s.sol/84532",
  environment: redactedEnv(),
  forge: {
    status: result.status,
    command: plan.forgeCommand,
  },
  nextSteps: {
    readback: plan.readRehearsal,
    writeSmoke: plan.writeRehearsal,
    sourceVerification: plan.verification,
    rollback: plan.rollback,
  },
  boundaries: plan.boundaries,
};

writeJson(artifactOut, artifact);

if (json) {
  console.log(JSON.stringify({ ok: true, artifactOut, artifact }, null, 2));
} else {
  console.log(`Base Sepolia ${broadcast ? "broadcast" : "dry run"} artifact written: ${artifactOut}`);
}
