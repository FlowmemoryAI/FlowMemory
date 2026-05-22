#!/usr/bin/env node
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { keccak256Utf8 } from "../../services/shared/src/index.ts";
import {
  blockArgumentToDecimalString,
  blockArgumentToRpcQuantity,
  normalizeEvmAddress,
  normalizeRpcUrl,
  readArgValue,
} from "../../services/indexer/src/reader-utils.ts";

const BASE_SEPOLIA_CHAIN_ID = "84532";
const DEFAULT_MAX_BLOCK_SPAN = 10_000n;
const DEFAULT_OUT = "fixtures/deployments/public-agent-network-base-sepolia-readback.latest.json";

export const PUBLIC_AGENT_EVENT_CATALOG = [
  { group: "runtime", name: "AgentRegistered", signature: "AgentRegistered(bytes32,bytes32,address,bytes32,bytes32,bytes32,bytes32,string)" },
  { group: "registry", name: "AgentClassRegistered", signature: "AgentClassRegistered(bytes32,uint64,bytes32,bytes32,bytes32,bytes32)" },
  { group: "registry", name: "ToolRegistered", signature: "ToolRegistered(bytes32,uint64,uint8,bool,bytes32)" },
  { group: "registry", name: "ToolSetRegistered", signature: "ToolSetRegistered(bytes32,uint64,uint8,bytes32)" },
  { group: "registry", name: "ToolSetMemberSet", signature: "ToolSetMemberSet(bytes32,bytes32,bool)" },
  { group: "registry", name: "ToolSetAllowedForClass", signature: "ToolSetAllowedForClass(bytes32,bytes32)" },
  { group: "registry", name: "AuthorizedRegistrarSet", signature: "AuthorizedRegistrarSet(address,bool)" },
  { group: "profile", name: "AgentProfileSet", signature: "AgentProfileSet(bytes32,address,bytes32,bytes32,bytes32,bytes32,bool)" },
  { group: "receipt", name: "AuthorizedAttestorSet", signature: "AuthorizedAttestorSet(address,bool)" },
  { group: "receipt", name: "AgentReceiptAnchored", signature: "AgentReceiptAnchored(bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64)" },
  { group: "launch", name: "LaunchGuardianSet", signature: "LaunchGuardianSet(address,address)" },
  { group: "launch", name: "LaunchIntentConsumed", signature: "LaunchIntentConsumed(bytes32,address,bytes32,uint64)" },
  { group: "launch", name: "AgentLaunched", signature: "AgentLaunched(bytes32,bytes32,bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,uint8,uint8)" },
  { group: "launch", name: "AgentLaunchLinkedToLineage", signature: "AgentLaunchLinkedToLineage(bytes32,bytes32,bytes32)" },
  { group: "bond", name: "ApprovedBondTokenSet", signature: "ApprovedBondTokenSet(address,bool)" },
  { group: "bond", name: "AuthorizedLockerSet", signature: "AuthorizedLockerSet(address,bool)" },
  { group: "bond", name: "BondPolicyUpdated", signature: "BondPolicyUpdated(bytes32,address,uint256,uint256,uint64,uint64,uint16,bool)" },
  { group: "bond", name: "LaunchBondLocked", signature: "LaunchBondLocked(bytes32,address,address,address,uint256,bytes32,uint64)" },
  { group: "fuel", name: "ApprovedFuelTokenSet", signature: "ApprovedFuelTokenSet(address,bool)" },
  { group: "fuel", name: "AuthorizedMeterSet", signature: "AuthorizedMeterSet(address,bool)" },
  { group: "fuel", name: "FuelPolicyUpdated", signature: "FuelPolicyUpdated(bytes32,address,uint256,uint256,uint256,bool,bool)" },
  { group: "fuel", name: "FuelAccountRegistered", signature: "FuelAccountRegistered(bytes32,address,bytes32,address)" },
  { group: "fuel", name: "MemoryFuelDeposited", signature: "MemoryFuelDeposited(bytes32,address,address,uint256)" },
  { group: "swarm", name: "SwarmPolicyRegistered", signature: "SwarmPolicyRegistered(bytes32,bytes32,bytes32,bytes32,bytes32)" },
  { group: "swarm", name: "SwarmClassApproved", signature: "SwarmClassApproved(bytes32,bool)" },
  { group: "swarm", name: "SwarmCreated", signature: "SwarmCreated(bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32)" },
  { group: "swarm", name: "SwarmMemberJoined", signature: "SwarmMemberJoined(bytes32,bytes32,uint8,bytes32,bytes32)" },
  { group: "swarm", name: "SwarmIntentConsumed", signature: "SwarmIntentConsumed(bytes32,address,bytes32)" },
  { group: "swarm", name: "SwarmLaunched", signature: "SwarmLaunched(bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32)" },
  { group: "swarm", name: "AuthorizedOperatorSet", signature: "AuthorizedOperatorSet(address,bool)" },
  { group: "swarm", name: "SwarmBudgetDeposited", signature: "SwarmBudgetDeposited(bytes32,address,address,uint256)" },
  { group: "swarm", name: "SwarmBudgetLineCreated", signature: "SwarmBudgetLineCreated(bytes32,bytes32,address,uint256,bytes32,bytes32)" },
  { group: "swarm", name: "SwarmBudgetReserved", signature: "SwarmBudgetReserved(bytes32,bytes32,bytes32,uint256,bytes32)" },
  { group: "swarm", name: "SwarmBudgetReleased", signature: "SwarmBudgetReleased(bytes32,bytes32,bytes32,uint256)" },
  { group: "swarm", name: "SwarmBudgetSpent", signature: "SwarmBudgetSpent(bytes32,bytes32,bytes32,address,address,uint256,bytes32)" },
  { group: "shell", name: "AuthorizedLauncherSet", signature: "AuthorizedLauncherSet(address,bool)" },
  { group: "deployment", name: "PublicAgentNetworkBaseSepoliaDeployed", signature: "PublicAgentNetworkBaseSepoliaDeployed(address,address,address,address,address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)" },
].map((event) => ({ ...event, topic0: keccak256Utf8(event.signature) }));

const REQUIRED_GROUPS = ["registry", "launch", "fuel", "bond", "swarm"];

function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function writeText(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, value, "utf8");
}

function writeJson(path, value) {
  writeText(path, `${JSON.stringify(value, null, 2)}\n`);
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function quantityToDecimalString(value) {
  if (typeof value !== "string" || !/^0x[0-9a-fA-F]+$/.test(value)) {
    throw new Error(`invalid JSON-RPC quantity: ${String(value)}`);
  }
  return BigInt(value).toString();
}

function normalizeAddressMap(entries) {
  const normalized = {};
  for (const [label, address] of Object.entries(entries)) {
    if (typeof address !== "string") continue;
    normalized[label] = normalizeEvmAddress(address);
  }
  return normalized;
}

function parseAddressArg(value, index) {
  const separator = value.indexOf("=");
  if (separator === -1) {
    return [`address${index + 1}`, normalizeEvmAddress(value)];
  }
  const label = value.slice(0, separator).trim();
  const address = value.slice(separator + 1).trim();
  if (label === "") throw new Error("--address labels must not be empty");
  if (!/^[A-Za-z][A-Za-z0-9_:-]*$/.test(label)) throw new Error(`invalid --address label: ${label}`);
  return [label, normalizeEvmAddress(address)];
}

function extractContractsFromFoundryBroadcast(path) {
  const parsed = readJson(path);
  const transactions = Array.isArray(parsed.transactions) ? parsed.transactions : [];
  const contracts = {};
  for (const tx of transactions) {
    if (!isRecord(tx)) continue;
    if (tx.transactionType !== "CREATE") continue;
    if (typeof tx.contractName !== "string" || typeof tx.contractAddress !== "string") continue;
    contracts[tx.contractName] = tx.contractAddress;
  }
  return normalizeAddressMap(contracts);
}

function extractContractsFromDeploymentArtifact(path) {
  const parsed = readJson(path);
  const contracts = parsed?.foundryBroadcast?.contracts ?? parsed?.contracts ?? null;
  return isRecord(contracts) ? normalizeAddressMap(contracts) : {};
}

function eventLookupByTopic() {
  const lookup = new Map();
  for (const event of PUBLIC_AGENT_EVENT_CATALOG) {
    const key = event.topic0.toLowerCase();
    const existing = lookup.get(key);
    if (existing === undefined) lookup.set(key, [event]);
    else existing.push(event);
  }
  return lookup;
}

function sortLogs(left, right) {
  const blockDelta = BigInt(left.blockNumber) - BigInt(right.blockNumber);
  if (blockDelta !== 0n) return blockDelta < 0n ? -1 : 1;
  const txDelta = BigInt(left.transactionIndex) - BigInt(right.transactionIndex);
  if (txDelta !== 0n) return txDelta < 0n ? -1 : 1;
  const logDelta = BigInt(left.logIndex) - BigInt(right.logIndex);
  if (logDelta !== 0n) return logDelta < 0n ? -1 : 1;
  return left.transactionHash.localeCompare(right.transactionHash);
}

export function summarizePublicAgentLogs(input) {
  const topicLookup = eventLookupByTopic();
  const addressToLabel = new Map(Object.entries(input.contracts).map(([label, address]) => [address.toLowerCase(), label]));
  const groupCounts = {};
  const eventCounts = {};
  const unknownTopicCounts = {};
  const observations = [];
  const txStatuses = input.txStatuses ?? {};

  for (const rawLog of input.logs) {
    if (!isRecord(rawLog)) continue;
    const topics = Array.isArray(rawLog.topics) ? rawLog.topics.filter((topic) => typeof topic === "string") : [];
    const topic0 = topics[0]?.toLowerCase();
    if (!topic0) continue;
    const matches = topicLookup.get(topic0);
    if (matches === undefined) {
      unknownTopicCounts[topic0] = (unknownTopicCounts[topic0] ?? 0) + 1;
      continue;
    }
    const event = matches[0];
    const address = typeof rawLog.address === "string" ? normalizeEvmAddress(rawLog.address) : "unknown";
    const blockNumber = quantityToDecimalString(rawLog.blockNumber);
    const transactionIndex = quantityToDecimalString(rawLog.transactionIndex);
    const logIndex = quantityToDecimalString(rawLog.logIndex);
    const transactionHash = typeof rawLog.transactionHash === "string" ? rawLog.transactionHash : "unknown";

    groupCounts[event.group] = (groupCounts[event.group] ?? 0) + 1;
    eventCounts[event.name] = (eventCounts[event.name] ?? 0) + 1;
    observations.push({
      group: event.group,
      event: event.name,
      signature: event.signature,
      topic0: event.topic0,
      address,
      contract: addressToLabel.get(address.toLowerCase()) ?? "unknown",
      blockNumber,
      transactionHash,
      transactionIndex,
      logIndex,
      receiptStatus: txStatuses[transactionHash] ?? "unknown",
      topics,
      dataLength: typeof rawLog.data === "string" ? rawLog.data.length : 0,
      removed: rawLog.removed === true,
    });
  }

  observations.sort(sortLogs);
  const requiredGroups = input.requiredGroups ?? REQUIRED_GROUPS;
  const missingRequiredGroups = requiredGroups.filter((group) => (groupCounts[group] ?? 0) === 0);

  return {
    groupCounts,
    eventCounts,
    unknownTopicCounts,
    observations,
    missingRequiredGroups,
    ok: missingRequiredGroups.length === 0,
  };
}

async function rpc(fetchImpl, rpcUrl, method, params) {
  const response = await fetchImpl(rpcUrl, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  if (!response.ok) throw new Error(`JSON-RPC HTTP error ${response.status}`);
  const payload = await response.json();
  if (!isRecord(payload) || payload.jsonrpc !== "2.0") throw new Error(`JSON-RPC ${method} returned a malformed envelope`);
  if (payload.error !== undefined) {
    const error = payload.error;
    if (!isRecord(error) || typeof error.code !== "number" || typeof error.message !== "string") {
      throw new Error(`JSON-RPC ${method} returned a malformed error`);
    }
    throw new Error(`JSON-RPC error ${error.code}: ${error.message}`);
  }
  if (payload.result === undefined) throw new Error(`JSON-RPC ${method} returned no result`);
  return payload.result;
}

async function readReceipts(fetchImpl, rpcUrl, logs) {
  const statuses = {};
  const hashes = [...new Set(logs.map((log) => isRecord(log) && typeof log.transactionHash === "string" ? log.transactionHash : null).filter(Boolean))];
  for (const txHash of hashes) {
    const receipt = await rpc(fetchImpl, rpcUrl, "eth_getTransactionReceipt", [txHash]);
    statuses[txHash] = isRecord(receipt) && receipt.status === "0x1" ? "success" : receipt?.status === "0x0" ? "reverted" : "unknown";
  }
  return statuses;
}

export async function readPublicAgentBaseSepoliaLogs(options) {
  const rpcUrl = normalizeRpcUrl(options.rpcUrl);
  const fromBlock = blockArgumentToDecimalString(options.fromBlock);
  const toBlock = blockArgumentToDecimalString(options.toBlock);
  const maxBlockSpan = options.maxBlockSpan === undefined ? DEFAULT_MAX_BLOCK_SPAN : BigInt(blockArgumentToDecimalString(String(options.maxBlockSpan)));
  if (BigInt(toBlock) < BigInt(fromBlock)) throw new Error("--to-block must be greater than or equal to --from-block");
  const span = BigInt(toBlock) - BigInt(fromBlock);
  if (span > maxBlockSpan) throw new Error(`Base Sepolia public-agent readback refuses broad scans; block span ${span.toString()} exceeds ${maxBlockSpan.toString()}`);

  const fetchImpl = options.fetchImpl ?? fetch;
  const chainIdQuantity = await rpc(fetchImpl, rpcUrl, "eth_chainId", []);
  const chainId = quantityToDecimalString(chainIdQuantity);
  if (chainId !== BASE_SEPOLIA_CHAIN_ID) throw new Error(`expected Base Sepolia chainId ${BASE_SEPOLIA_CHAIN_ID}, received ${chainId}`);

  const addresses = [...new Set(Object.values(options.contracts).map((address) => normalizeEvmAddress(address)))]
    .sort((left, right) => left.localeCompare(right));
  if (addresses.length === 0) throw new Error("at least one public-agent contract address is required");

  const topic0s = [...new Set(PUBLIC_AGENT_EVENT_CATALOG.map((event) => event.topic0))].sort();
  const logs = await rpc(fetchImpl, rpcUrl, "eth_getLogs", [{
    address: addresses,
    fromBlock: blockArgumentToRpcQuantity(fromBlock),
    toBlock: blockArgumentToRpcQuantity(toBlock),
    topics: [topic0s],
  }]);
  if (!Array.isArray(logs)) throw new Error("JSON-RPC eth_getLogs result must be an array");
  const txStatuses = await readReceipts(fetchImpl, rpcUrl, logs);
  return { chainId, addresses, fromBlock, toBlock, logs, txStatuses };
}

export function buildReadbackReport(input) {
  const summary = summarizePublicAgentLogs({
    contracts: input.contracts,
    logs: input.logs,
    txStatuses: input.txStatuses,
    requiredGroups: input.requiredGroups,
  });
  const txHashes = [...new Set(summary.observations.map((observation) => observation.transactionHash))].sort();
  return {
    schema: "flowmemory.public_agent_network.base_sepolia_readback.v1",
    generatedAt: input.generatedAt,
    productionReady: false,
    network: {
      name: "Base Sepolia",
      chainId: BASE_SEPOLIA_CHAIN_ID,
      explorer: "https://sepolia.basescan.org",
    },
    deployer: input.deployerAddress === null ? null : {
      address: input.deployerAddress,
      explorer: `https://sepolia.basescan.org/address/${input.deployerAddress}`,
    },
    boundedRange: {
      fromBlock: input.fromBlock,
      toBlock: input.toBlock,
      maxBlockSpan: String(input.maxBlockSpan ?? DEFAULT_MAX_BLOCK_SPAN),
    },
    contracts: input.contracts,
    requiredGroups: input.requiredGroups ?? REQUIRED_GROUPS,
    missingRequiredGroups: summary.missingRequiredGroups,
    ok: summary.ok,
    counts: {
      contractCount: Object.keys(input.contracts).length,
      rawLogCount: input.logs.length,
      observationCount: summary.observations.length,
      transactionCount: txHashes.length,
      byGroup: summary.groupCounts,
      byEvent: summary.eventCounts,
      unknownTopics: summary.unknownTopicCounts,
    },
    transactions: txHashes,
    observations: summary.observations,
    boundaries: [
      "Base Sepolia readback only; not production or mainnet readiness.",
      "The report stores public addresses, transaction hashes, logs, and bounded block ranges only.",
      "RPC URLs, private keys, and explorer API keys are never written.",
    ],
  };
}

export function formatReadbackMarkdown(report) {
  const lines = [
    "# Public Agent Network Base Sepolia Readback",
    "",
    `Generated: ${report.generatedAt}`,
    "",
    `Network: ${report.network.name} (${report.network.chainId})`,
    `Status: ${report.ok ? "PASS" : "INCOMPLETE"}`,
    `Range: ${report.boundedRange.fromBlock} → ${report.boundedRange.toBlock}`,
    `Contracts: ${report.counts.contractCount}`,
    `Observed logs: ${report.counts.observationCount}`,
    `Transactions: ${report.counts.transactionCount}`,
    "",
  ];
  if (report.deployer) {
    lines.push(`Deployer: ${report.deployer.address}`, "");
  }
  if (report.missingRequiredGroups.length > 0) {
    lines.push("## Missing Required Event Groups", "");
    for (const group of report.missingRequiredGroups) lines.push(`- ${group}`);
    lines.push("");
  }
  lines.push("## Event Groups", "");
  for (const group of report.requiredGroups) {
    lines.push(`- ${group}: ${report.counts.byGroup[group] ?? 0}`);
  }
  lines.push("");
  lines.push("## Contracts", "");
  for (const [label, address] of Object.entries(report.contracts).sort(([left], [right]) => left.localeCompare(right))) {
    lines.push(`- ${label}: ${address}`);
  }
  lines.push("");
  lines.push("## Observations", "");
  if (report.observations.length === 0) {
    lines.push("No public-agent-network events were observed in the bounded range.");
  } else {
    lines.push("| Block | Contract | Event | Tx | Status |", "| --- | --- | --- | --- | --- |");
    for (const observation of report.observations) {
      lines.push(`| ${observation.blockNumber} | ${observation.contract} | ${observation.event} | ${observation.transactionHash} | ${observation.receiptStatus} |`);
    }
  }
  lines.push("", "## Boundaries", "");
  for (const boundary of report.boundaries) lines.push(`- ${boundary}`);
  lines.push("");
  return `${lines.join("\n")}\n`;
}

function parseCliArgs(argv) {
  const addressEntries = {};
  let addressIndex = 0;
  let rpcUrl = process.env.BASE_SEPOLIA_RPC_URL ?? "";
  let fromBlock = process.env.PUBLIC_AGENT_NETWORK_BASE_SEPOLIA_FROM_BLOCK ?? "";
  let toBlock = process.env.PUBLIC_AGENT_NETWORK_BASE_SEPOLIA_TO_BLOCK ?? "";
  let maxBlockSpan = process.env.PUBLIC_AGENT_NETWORK_BASE_SEPOLIA_MAX_BLOCK_SPAN ?? DEFAULT_MAX_BLOCK_SPAN.toString();
  let out = process.env.PUBLIC_AGENT_NETWORK_BASE_SEPOLIA_READBACK_OUT ?? DEFAULT_OUT;
  let markdownOut = process.env.PUBLIC_AGENT_NETWORK_BASE_SEPOLIA_READBACK_MARKDOWN_OUT ?? "";
  let deployerAddress = process.env.BASE_SEPOLIA_PUBLIC_AGENT_DEPLOYER_ADDRESS ?? null;
  let generatedAt = process.env.PUBLIC_AGENT_NETWORK_BASE_SEPOLIA_GENERATED_AT ?? new Date().toISOString();
  let allowMissing = false;

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--rpc-url") {
      rpcUrl = readArgValue(argv, index, arg);
      index += 1;
    } else if (arg === "--from-block") {
      fromBlock = readArgValue(argv, index, arg);
      index += 1;
    } else if (arg === "--to-block") {
      toBlock = readArgValue(argv, index, arg);
      index += 1;
    } else if (arg === "--max-block-span") {
      maxBlockSpan = readArgValue(argv, index, arg);
      index += 1;
    } else if (arg === "--address" || arg === "--addresses") {
      const [label, address] = parseAddressArg(readArgValue(argv, index, arg), addressIndex);
      addressEntries[label] = address;
      addressIndex += 1;
      index += 1;
    } else if (arg === "--deployment-artifact") {
      Object.assign(addressEntries, extractContractsFromDeploymentArtifact(resolve(readArgValue(argv, index, arg))));
      index += 1;
    } else if (arg === "--foundry-broadcast") {
      Object.assign(addressEntries, extractContractsFromFoundryBroadcast(resolve(readArgValue(argv, index, arg))));
      index += 1;
    } else if (arg === "--deployer-address") {
      deployerAddress = readArgValue(argv, index, arg);
      index += 1;
    } else if (arg === "--generated-at") {
      generatedAt = readArgValue(argv, index, arg);
      index += 1;
    } else if (arg === "--out") {
      out = readArgValue(argv, index, arg);
      index += 1;
    } else if (arg === "--markdown-out") {
      markdownOut = readArgValue(argv, index, arg);
      index += 1;
    } else if (arg === "--allow-missing") {
      allowMissing = true;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

  if (fromBlock.trim() === "") throw new Error("--from-block is required");
  if (toBlock.trim() === "") throw new Error("--to-block is required");
  const normalizedDeployer = deployerAddress === null || deployerAddress.trim() === "" ? null : normalizeEvmAddress(deployerAddress);
  const contracts = normalizeAddressMap(addressEntries);
  if (Object.keys(contracts).length === 0) {
    throw new Error("provide --deployment-artifact, --foundry-broadcast, or at least one --address Name=0x...");
  }

  return {
    rpcUrl,
    fromBlock,
    toBlock,
    maxBlockSpan,
    out,
    markdownOut: markdownOut === "" ? out.replace(/\.json$/u, ".md") : markdownOut,
    deployerAddress: normalizedDeployer,
    generatedAt,
    contracts,
    allowMissing,
  };
}

function usage() {
  return [
    "Usage:",
    "  npm run public-agent-network:base-sepolia:readback -- --rpc-url <url> --deployment-artifact <artifact.json> --from-block <n> --to-block <n>",
    "  npm run public-agent-network:base-sepolia:readback -- --rpc-url <url> --address AgentFactory=0x... --address SwarmFactory=0x... --from-block <n> --to-block <n>",
    "",
    "Boundary:",
    "  Reads Base Sepolia only, requires bounded explicit block ranges, and writes no RPC URLs or secrets.",
  ].join("\n");
}

async function main() {
  const options = parseCliArgs(process.argv.slice(2));
  const readResult = await readPublicAgentBaseSepoliaLogs(options);
  const report = buildReadbackReport({
    generatedAt: options.generatedAt,
    deployerAddress: options.deployerAddress,
    contracts: options.contracts,
    fromBlock: readResult.fromBlock,
    toBlock: readResult.toBlock,
    maxBlockSpan: options.maxBlockSpan,
    logs: readResult.logs,
    txStatuses: readResult.txStatuses,
  });
  writeJson(resolve(options.out), report);
  writeText(resolve(options.markdownOut), formatReadbackMarkdown(report));
  console.log(JSON.stringify({
    schema: "flowmemory.public_agent_network.base_sepolia_readback_summary.v1",
    ok: report.ok,
    out: resolve(options.out),
    markdownOut: resolve(options.markdownOut),
    observationCount: report.counts.observationCount,
    transactionCount: report.counts.transactionCount,
    missingRequiredGroups: report.missingRequiredGroups,
  }, null, 2));
  if (!report.ok && !options.allowMissing) process.exitCode = 1;
}

const invokedPath = process.argv[1] ? resolve(process.argv[1]) : "";
const modulePath = resolve(fileURLToPath(import.meta.url));
if (invokedPath === modulePath) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    console.error(usage());
    process.exitCode = 1;
  });
}
