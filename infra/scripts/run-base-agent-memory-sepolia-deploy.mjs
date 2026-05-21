#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
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
  if (value === undefined || value.startsWith("--")) throw new Error(`${name} requires a value`);
  return value;
}

const planOut = resolve(readArgValue("--plan-out", process.env.BASE_AGENT_MEMORY_BASE_SEPOLIA_PLAN_OUT ?? "fixtures/deployments/base-agent-memory-base-sepolia-plan.json"));
const artifactOut = resolve(readArgValue("--artifact-out", process.env.BASE_AGENT_MEMORY_BASE_SEPOLIA_ARTIFACT_OUT ?? "fixtures/deployments/base-agent-memory-base-sepolia.latest.json"));
const generatedAt = readArgValue("--generated-at", process.env.BASE_AGENT_MEMORY_BASE_SEPOLIA_GENERATED_AT ?? new Date().toISOString());

const rpcUrl = process.env.BASE_SEPOLIA_RPC_URL;
const deployerKey = process.env.BASE_SEPOLIA_DEPLOYER_KEY_HEX;
const basescanApiKey = process.env.BASE_SEPOLIA_BASESCAN_API_KEY ?? process.env.BASESCAN_API_KEY;

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function validateEnv() {
  if (!rpcUrl) throw new Error("BASE_SEPOLIA_RPC_URL is required for Base agent memory Base Sepolia runs");
  if (!deployerKey) throw new Error("BASE_SEPOLIA_DEPLOYER_KEY_HEX is required for Base agent memory Base Sepolia runs");
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
  };
}

const forgeArgsRedacted = [
  "script",
  "script/DeployBaseAgentMemoryScout.s.sol:DeployBaseAgentMemoryScout",
  "--rpc-url",
  "$BASE_SEPOLIA_RPC_URL",
  "--private-key",
  "$BASE_SEPOLIA_DEPLOYER_KEY_HEX",
  "--chain-id",
  "84532",
];
if (broadcast) forgeArgsRedacted.push("--broadcast", "--slow");

const plan = {
  schema: "flowmemory.base_agent_memory.base_sepolia_plan.v1",
  generatedAt,
  mode: planOnly ? "plan-only" : broadcast ? "broadcast" : "dry-run",
  productionReady: false,
  network: {
    name: "Base Sepolia",
    chainId: "84532",
    explorer: "https://sepolia.basescan.org",
  },
  environment: redactedEnv(),
  requiredEnv: ["BASE_SEPOLIA_RPC_URL", "BASE_SEPOLIA_DEPLOYER_KEY_HEX"],
  optionalEnv: ["BASE_SEPOLIA_BASESCAN_API_KEY", "BASESCAN_API_KEY"],
  deploys: ["BaseOnchainAgentMemory"],
  forgeCommand: {
    program: "forge",
    args: forgeArgsRedacted,
    broadcast,
    note: "Dry run is default. Broadcast only after funded testnet operator approval.",
  },
  writeRehearsal: {
    registerAgent: [
      "cast send <BaseOnchainAgentMemory> \"registerAgent(address,bytes32,bytes32,bytes32,bytes32,bytes32,uint64,bytes32,bytes32,string)\" <owner> <rootfieldId> <policyRoot> <toolAllowlistRoot> <initialMemoryRoot> <activeGoal> <autonomyLevel> <kernelClass> <salt> <uri> --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $BASE_SEPOLIA_DEPLOYER_KEY_HEX",
      "cast send <BaseOnchainAgentMemory> \"setToolPolicy(bytes32,bytes32,(address,bytes4,uint256,uint256,uint256,bool),string)\" <agentId> <toolId> \"(<target>,<selector>,<perActionCap>,<epochCap>,<maxTaskReward>,true)\" <uri> --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $BASE_SEPOLIA_DEPLOYER_KEY_HEX",
    ],
  },
  readRehearsal: {
    agentSmoke: "cast call <BaseOnchainAgentMemory> \"getAgent(bytes32)\" <agentId> --rpc-url $BASE_SEPOLIA_RPC_URL",
    hotMemorySmoke: "cast call <BaseOnchainAgentMemory> \"getHotMemory(bytes32)\" <agentId> --rpc-url $BASE_SEPOLIA_RPC_URL",
  },
  verification: {
    apiKeyEnv: basescanApiKey ? "<set:redacted>" : "BASE_SEPOLIA_BASESCAN_API_KEY or BASESCAN_API_KEY",
    command: "forge verify-contract --chain-id 84532 <address> BaseOnchainAgentMemory --etherscan-api-key $BASE_SEPOLIA_BASESCAN_API_KEY",
  },
  boundaries: [
    "Base Sepolia rehearsal only; not production mainnet readiness.",
    "This deploys a bounded task-scout contract only.",
    "No private keys, RPC URLs, or explorer API keys are written to artifacts.",
    "Receipt metadata remains indexer-derived after execution.",
  ],
};

writeJson(planOut, plan);
if (planOnly) {
  if (json) console.log(JSON.stringify({ ok: true, planOut, plan }, null, 2));
  else console.log(`Base agent memory Base Sepolia plan written: ${planOut}`);
  process.exit(0);
}

validateEnv();
const forgeArgs = [
  "script",
  "script/DeployBaseAgentMemoryScout.s.sol:DeployBaseAgentMemoryScout",
  "--rpc-url",
  rpcUrl,
  "--private-key",
  deployerKey,
  "--chain-id",
  "84532",
];
if (broadcast) forgeArgs.push("--broadcast", "--slow");

const result = spawnSync("forge", forgeArgs, {
  cwd: process.cwd(),
  stdio: "inherit",
  shell: process.platform === "win32",
});
if (result.status !== 0) {
  throw new Error(`Base agent memory Base Sepolia deploy ${broadcast ? "broadcast" : "dry run"} failed with exit code ${result.status ?? "unknown"}`);
}

const artifact = {
  schema: "flowmemory.base_agent_memory.base_sepolia_artifact.v1",
  generatedAt,
  mode: broadcast ? "broadcast" : "dry-run",
  productionReady: false,
  network: plan.network,
  planPath: planOut,
  expectedFoundryBroadcastDir: "broadcast/DeployBaseAgentMemoryScout.s.sol/84532",
  environment: redactedEnv(),
  forge: {
    status: result.status,
    command: plan.forgeCommand,
  },
  nextSteps: {
    readback: plan.readRehearsal,
    writeSmoke: plan.writeRehearsal,
    sourceVerification: plan.verification,
  },
  boundaries: plan.boundaries,
};

writeJson(artifactOut, artifact);
if (json) console.log(JSON.stringify({ ok: true, artifactOut, artifact }, null, 2));
else console.log(`Base agent memory Base Sepolia artifact written: ${artifactOut}`);
