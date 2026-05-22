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
  if (value === undefined || value.startsWith("--")) throw new Error(`${name} requires a value`);
  return value;
}

function normalizeOptionalAddress(value, label) {
  if (value === undefined || value === null || value.trim() === "") return null;
  const trimmed = value.trim();
  if (!/^0x[0-9a-fA-F]{40}$/.test(trimmed)) throw new Error(`${label} must be a 20-byte EVM address`);
  return trimmed;
}

function requireAddress(value, label) {
  const normalized = normalizeOptionalAddress(value, label);
  if (normalized === null) throw new Error(`${label} is required`);
  return normalized;
}

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

const planOut = resolve(readArgValue(
  "--plan-out",
  process.env.PUBLIC_AGENT_NETWORK_BASE_SEPOLIA_PLAN_OUT ?? "fixtures/deployments/public-agent-network-base-sepolia-plan.json",
));
const artifactOut = resolve(readArgValue(
  "--artifact-out",
  process.env.PUBLIC_AGENT_NETWORK_BASE_SEPOLIA_ARTIFACT_OUT ?? "fixtures/deployments/public-agent-network-base-sepolia.latest.json",
));
const generatedAt = readArgValue(
  "--generated-at",
  process.env.PUBLIC_AGENT_NETWORK_BASE_SEPOLIA_GENERATED_AT ?? new Date().toISOString(),
);
const deployerAddress = normalizeOptionalAddress(
  readArgValue("--deployer-address", process.env.BASE_SEPOLIA_PUBLIC_AGENT_DEPLOYER_ADDRESS ?? null),
  "--deployer-address / BASE_SEPOLIA_PUBLIC_AGENT_DEPLOYER_ADDRESS",
);

const rpcUrl = process.env.BASE_SEPOLIA_RPC_URL;
const deployerKey = process.env.BASE_SEPOLIA_DEPLOYER_KEY_HEX;
const basescanApiKey = process.env.BASE_SEPOLIA_BASESCAN_API_KEY ?? process.env.BASESCAN_API_KEY;

const deployScript = "script/DeployPublicAgentNetworkBaseSepolia.s.sol:DeployPublicAgentNetworkBaseSepolia";
const expectedFoundryBroadcastDir = "broadcast/DeployPublicAgentNetworkBaseSepolia.s.sol/84532";
const expectedFoundryBroadcastPath = `${expectedFoundryBroadcastDir}/run-latest.json`;

function validateEnvForForgeRun() {
  if (!rpcUrl) throw new Error("BASE_SEPOLIA_RPC_URL is required for public-agent Base Sepolia deployment runs");
  if (!deployerKey) throw new Error("BASE_SEPOLIA_DEPLOYER_KEY_HEX is required for public-agent Base Sepolia deployment runs");
  if (!/^0x[0-9a-fA-F]{64}$/.test(deployerKey)) {
    throw new Error("BASE_SEPOLIA_DEPLOYER_KEY_HEX must be a 32-byte hex private key with 0x prefix");
  }
  requireAddress(deployerAddress, "--deployer-address / BASE_SEPOLIA_PUBLIC_AGENT_DEPLOYER_ADDRESS");
}

function redactedEnv() {
  return {
    BASE_SEPOLIA_RPC_URL: rpcUrl ? "<set>" : "<missing>",
    BASE_SEPOLIA_DEPLOYER_KEY_HEX: deployerKey ? "<set:redacted>" : "<missing>",
    BASE_SEPOLIA_PUBLIC_AGENT_DEPLOYER_ADDRESS: deployerAddress ?? "<missing>",
    BASE_SEPOLIA_BASESCAN_API_KEY: process.env.BASE_SEPOLIA_BASESCAN_API_KEY ? "<set:redacted>" : "<missing>",
    BASESCAN_API_KEY: process.env.BASESCAN_API_KEY ? "<set:redacted>" : "<missing>",
    PUBLIC_AGENT_NETWORK_BASE_SEPOLIA_PLAN_OUT: process.env.PUBLIC_AGENT_NETWORK_BASE_SEPOLIA_PLAN_OUT ? "<set>" : "<default>",
    PUBLIC_AGENT_NETWORK_BASE_SEPOLIA_ARTIFACT_OUT: process.env.PUBLIC_AGENT_NETWORK_BASE_SEPOLIA_ARTIFACT_OUT ? "<set>" : "<default>",
  };
}

function extractFoundryBroadcastSummary(path) {
  if (!existsSync(path)) return null;
  const broadcastJson = readJson(path);
  const transactions = Array.isArray(broadcastJson.transactions) ? broadcastJson.transactions : [];
  const contracts = {};
  const deploymentTransactions = [];
  const callTransactions = [];
  for (const tx of transactions) {
    if (tx === null || typeof tx !== "object") continue;
    const contractName = typeof tx.contractName === "string" ? tx.contractName : null;
    const contractAddress = typeof tx.contractAddress === "string" ? tx.contractAddress : null;
    const hash = typeof tx.hash === "string" ? tx.hash : null;
    const txType = typeof tx.transactionType === "string" ? tx.transactionType : null;
    const fn = typeof tx.function === "string" ? tx.function : null;
    const from = tx.transaction && typeof tx.transaction === "object" && typeof tx.transaction.from === "string"
      ? tx.transaction.from
      : null;
    const to = tx.transaction && typeof tx.transaction === "object" && typeof tx.transaction.to === "string"
      ? tx.transaction.to
      : null;
    const nonce = tx.transaction && typeof tx.transaction === "object" && typeof tx.transaction.nonce === "string"
      ? tx.transaction.nonce
      : null;

    const row = { hash, contractName, contractAddress, transactionType: txType, function: fn, from, to, nonce };
    if (txType === "CREATE" && contractName && contractAddress) {
      contracts[contractName] = contractAddress;
      deploymentTransactions.push(row);
    } else if (txType === "CALL") {
      callTransactions.push(row);
    }
  }

  return {
    source: path,
    transactionCount: transactions.length,
    deploymentTransactionCount: deploymentTransactions.length,
    callTransactionCount: callTransactions.length,
    contracts,
    deploymentTransactions,
    callTransactions,
  };
}

const forgeArgsRedacted = [
  "script",
  deployScript,
  "--threads",
  "1",
  "--rpc-url",
  "$BASE_SEPOLIA_RPC_URL",
  "--chain-id",
  "84532",
];
if (broadcast) forgeArgsRedacted.push("--broadcast", "--slow");

const deployedContracts = [
  "BaseOnchainAgentMemory",
  "AgentClassRegistry",
  "ToolRegistry",
  "AgentProfileRegistry",
  "AgentLaunchBondEscrow",
  "AgentMemoryFuelVault",
  "AgentLineageRegistry",
  "AgentReceiptAnchor",
  "AgentShellFactory",
  "AgentFactory",
  "SwarmPolicyRegistry",
  "SwarmRegistry",
  "SwarmBudgetVault",
  "SwarmFactory",
  "PublicNetworkBaseSepoliaToken",
];

const plan = {
  schema: "flowmemory.public_agent_network.base_sepolia_plan.v1",
  generatedAt,
  mode: planOnly ? "plan-only" : broadcast ? "broadcast" : "dry-run",
  productionReady: false,
  network: {
    name: "Base Sepolia",
    chainId: "84532",
    explorer: "https://sepolia.basescan.org",
  },
  deployer: {
    address: deployerAddress ?? "<missing>",
    explorer: deployerAddress ? `https://sepolia.basescan.org/address/${deployerAddress}` : "<missing>",
    note: "Public testnet deployer address only. The private key must stay in local env and is never written.",
  },
  environment: redactedEnv(),
  requiredEnv: ["BASE_SEPOLIA_RPC_URL", "BASE_SEPOLIA_DEPLOYER_KEY_HEX", "BASE_SEPOLIA_PUBLIC_AGENT_DEPLOYER_ADDRESS"],
  optionalEnv: ["BASE_SEPOLIA_BASESCAN_API_KEY", "BASESCAN_API_KEY"],
  deploys: deployedContracts,
  forgeCommand: {
    program: "forge",
    args: forgeArgsRedacted,
    broadcast,
    note: "Dry run is default. Broadcast only after the testnet deployer is funded and operator approval is explicit.",
  },
  publicSmoke: {
    actions: [
      "register public agent class and tool set",
      "configure launch bond and memory fuel policies",
      "launch one deployer-owned task-scout agent with a deployer EIP-712 signature",
      "anchor one local/test receipt root",
      "register one research swarm with wallet + agent members",
      "exercise swarm budget deposit, line, reserve, release, and spend events",
    ],
    valueAtRisk: "testnet token deployed by this script only",
  },
  expectedFoundryBroadcastDir,
  readback: {
    command: "npm run public-agent-network:base-sepolia:readback -- --rpc-url $BASE_SEPOLIA_RPC_URL --deployment-artifact fixtures/deployments/public-agent-network-base-sepolia.latest.json --from-block <deployBlock> --to-block <latestBlock>",
    requiredEventGroups: ["registry", "launch", "fuel", "bond", "swarm"],
    defaultOut: "fixtures/deployments/public-agent-network-base-sepolia-readback.latest.json",
  },
  verification: {
    apiKeyEnv: basescanApiKey ? "<set:redacted>" : "BASE_SEPOLIA_BASESCAN_API_KEY or BASESCAN_API_KEY",
    note: "Use Foundry broadcast metadata for constructor args. Record submitted, verified, or pending per contract in the deployment evidence.",
    command: "forge verify-contract --watch --chain-id 84532 <address> <fully-qualified-contract> --etherscan-api-key $BASE_SEPOLIA_BASESCAN_API_KEY",
  },
  boundaries: [
    "Base Sepolia rehearsal only; not production or mainnet readiness.",
    "No private keys, RPC URLs, or explorer API keys are written to artifacts.",
    "The smoke agent, token, bond, fuel, receipt, and swarm records are local/test protocol evidence only.",
    "Reader evidence must use bounded block ranges and explicit addresses.",
  ],
};

writeJson(planOut, plan);
if (planOnly) {
  if (json) console.log(JSON.stringify({ ok: true, planOut, plan }, null, 2));
  else console.log(`Public-agent Base Sepolia plan written: ${planOut}`);
  process.exit(0);
}

validateEnvForForgeRun();

const forgeArgs = [
  "script",
  deployScript,
  "--threads",
  "1",
  "--rpc-url",
  rpcUrl,
  "--chain-id",
  "84532",
];
if (broadcast) forgeArgs.push("--broadcast", "--slow");

const result = spawnSync("forge", forgeArgs, {
  cwd: process.cwd(),
  stdio: "inherit",
  shell: process.platform === "win32",
  env: {
    ...process.env,
    BASE_SEPOLIA_PUBLIC_AGENT_DEPLOYER_ADDRESS: deployerAddress,
  },
});
if (result.status !== 0) {
  throw new Error(`public-agent Base Sepolia deploy ${broadcast ? "broadcast" : "dry run"} failed with exit code ${result.status ?? "unknown"}`);
}

const broadcastSummary = broadcast ? extractFoundryBroadcastSummary(resolve(expectedFoundryBroadcastPath)) : null;
const artifact = {
  schema: "flowmemory.public_agent_network.base_sepolia_artifact.v1",
  generatedAt,
  mode: broadcast ? "broadcast" : "dry-run",
  productionReady: false,
  network: plan.network,
  deployer: plan.deployer,
  planPath: planOut,
  expectedFoundryBroadcastDir,
  foundryBroadcast: broadcastSummary,
  environment: redactedEnv(),
  forge: {
    status: result.status,
    command: plan.forgeCommand,
  },
  nextSteps: {
    readback: plan.readback,
    sourceVerification: plan.verification,
  },
  boundaries: plan.boundaries,
};

writeJson(artifactOut, artifact);
if (json) console.log(JSON.stringify({ ok: true, artifactOut, artifact }, null, 2));
else console.log(`Public-agent Base Sepolia ${broadcast ? "broadcast" : "dry run"} artifact written: ${artifactOut}`);
