import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import {
  encodeAddress,
  encodeBytes32,
  encodeStringTail,
  encodeUint256,
  keccak256Hex,
  keccak256Utf8,
  parseFlowPulseLogFixture,
  type FlowPulseReceiptFixture,
} from "../../shared/src/index.ts";
import { indexFlowPulseReceipts, writeIndexerState } from "../../indexer/src/index.ts";
import { verifyObservations, writeVerifierReports, type ArtifactResolverFixture } from "../../verifier/src/index.ts";

function concatBytes(parts: Uint8Array[]): Uint8Array {
  const output = new Uint8Array(parts.reduce((sum, part) => sum + part.length, 0));
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
}

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const OUT_DIR = resolve(REPO_ROOT, "local-runtime/local/base-agent-memory-e2e");
const BROADCAST_PATH = resolve(REPO_ROOT, "broadcast/RunBaseAgentMemoryLocalE2E.s.sol/31337/run-latest.json");
const FLOWPULSE_TOPIC0 = keccak256Utf8("FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)");
const AGENT_MEMORY_SCHEMA_ID = keccak256Utf8("flowmemory.base_onchain_agent_memory.v1");
const DEFAULT_RPC_HOST = "127.0.0.1";
const DEFAULT_CHAIN_ID = 31337;

interface BroadcastTransaction {
  hash: string;
  transactionType: string;
  contractName: string | null;
  contractAddress: string | null;
  function: string | null;
  arguments?: string[] | null;
}

interface BroadcastArtifact {
  transactions: BroadcastTransaction[];
}

interface JsonRpcReceiptLog {
  address: string;
  topics: string[];
  data: string;
  logIndex: string;
  removed?: boolean;
}

interface JsonRpcReceipt {
  blockHash: string;
  blockNumber: string;
  transactionHash: string;
  transactionIndex: string;
  status: string;
  logs: JsonRpcReceiptLog[];
}

interface AgentMemoryLocalE2EReport {
  schema: "flowmemory.base_agent_memory.local_e2e.v1";
  rpcUrl: string;
  chainId: string;
  deployed: {
    baseOnchainAgentMemory: string;
    taskTarget: string;
  };
  transactions: {
    registerAgent: string | null;
    setToolPolicy: string | null;
    step: string;
    pause: string | null;
    correctMemory: string | null;
  };
  indexer: {
    observations: number;
    cursors: number;
    rejectedLogs: number;
    duplicates: number;
  };
  verifier: {
    reports: number;
    statusCounts: Record<string, number>;
  };
  outputs: {
    receiptsPath: string;
    indexerPath: string;
    verifierPath: string;
    reportPath: string;
  };
  localOnly: true;
}

function writeJson(path: string, value: unknown): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function runCommand(command: string, args: string[], options: { cwd?: string } = {}): string {
  const result = spawnSync(command, args, {
    cwd: options.cwd ?? REPO_ROOT,
    encoding: "utf8",
    shell: process.platform === "win32",
  });
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed: ${result.stderr || result.stdout}`);
  }
  return result.stdout.trim();
}

function hexToDecimalString(value: string): string {
  return BigInt(value).toString();
}

async function waitForRpc(rpcUrl: string): Promise<void> {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(rpcUrl, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_chainId", params: [] }),
      });
      if (response.ok) {
        const payload = await response.json() as { result?: string };
        if (payload.result !== undefined) return;
      }
    } catch {}
    await new Promise((resolvePromise) => setTimeout(resolvePromise, 500));
  }
  throw new Error(`Timed out waiting for RPC ${rpcUrl}`);
}

function readBroadcastArtifact(): BroadcastArtifact {
  return JSON.parse(readFileSync(BROADCAST_PATH, "utf8")) as BroadcastArtifact;
}

function receiptFor(rpcUrl: string, txHash: string): JsonRpcReceipt {
  return JSON.parse(runCommand("cast", ["receipt", txHash, "--json", "--rpc-url", rpcUrl])) as JsonRpcReceipt;
}

function splitTupleValues(value: string): string[] {
  return value
    .trim()
    .replace(/^\(/, "")
    .replace(/\)$/, "")
    .split(/,\s*/)
    .map((entry) => entry.trim());
}

function abiEncodeWithString(domain: string, head: Uint8Array[]): Uint8Array {
  const headLength = BigInt((head.length + 1) * 32);
  return concatBytes([
    ...head.slice(0, 1),
    encodeUint256(headLength),
    ...head.slice(1),
    encodeStringTail(domain),
  ]);
}

function deriveActionReceiptId(fields: {
  contractAddress: string;
  agentId: string;
  sequence: string;
  previewHash: string;
  action: string;
  actionSucceeded: boolean;
}): string {
  return keccak256Hex(abiEncodeWithString("action_receipt", [
    encodeBytes32(AGENT_MEMORY_SCHEMA_ID),
    encodeUint256(DEFAULT_CHAIN_ID),
    encodeAddress(fields.contractAddress),
    encodeBytes32(fields.agentId),
    encodeUint256(fields.sequence),
    encodeBytes32(fields.previewHash),
    encodeUint256(fields.action),
    encodeUint256(fields.actionSucceeded ? 1 : 0),
  ]));
}

function deriveNewMemoryRoot(fields: {
  contractAddress: string;
  agentId: string;
  parentRoot: string;
  deltaRoot: string;
  actionReceiptId: string;
  actionSucceeded: boolean;
  sequence: string;
}): string {
  return keccak256Hex(abiEncodeWithString("memory_root", [
    encodeBytes32(AGENT_MEMORY_SCHEMA_ID),
    encodeUint256(DEFAULT_CHAIN_ID),
    encodeAddress(fields.contractAddress),
    encodeBytes32(fields.agentId),
    encodeBytes32(fields.parentRoot),
    encodeBytes32(fields.deltaRoot),
    encodeBytes32(fields.actionReceiptId),
    encodeUint256(fields.actionSucceeded ? 1 : 0),
    encodeUint256(fields.sequence),
  ]));
}

function deriveStepStateFromBroadcast(
  stepTx: BroadcastTransaction,
  contractAddress: string,
  initialMemoryRoot: string,
): {
  actionReceiptId: string;
  newMemoryRoot: string;
  parentRoot: string;
  deltaRoot: string;
  actionSucceeded: boolean;
  stepUri: string;
  memoryUri: string;
} {
  const args = stepTx.arguments ?? [];
  const agentId = args[0];
  const previewTuple = args[2];
  const stepUri = args[3];
  if (agentId === undefined || previewTuple === undefined || stepUri === undefined) {
    throw new Error("step transaction is missing expected broadcast arguments");
  }
  const previewValues = splitTupleValues(previewTuple);
  const action = previewValues[0];
  const deltaRoot = previewValues[6];
  const previewHash = previewValues[7];
  if (action === undefined || deltaRoot === undefined || previewHash === undefined) {
    throw new Error("preview tuple is missing action, deltaRoot, or previewHash");
  }
  const actionReceiptId = deriveActionReceiptId({
    contractAddress,
    agentId,
    sequence: "1",
    previewHash,
    action,
    actionSucceeded: true,
  });
  const newMemoryRoot = deriveNewMemoryRoot({
    contractAddress,
    agentId,
    parentRoot: initialMemoryRoot,
    deltaRoot,
    actionReceiptId,
    actionSucceeded: true,
    sequence: "1",
  });
  return {
    actionReceiptId,
    newMemoryRoot,
    parentRoot: initialMemoryRoot,
    deltaRoot,
    actionSucceeded: true,
    stepUri,
    memoryUri: `${stepUri}#memory`,
  };
}

function flowPulseReceiptFixture(receipt: JsonRpcReceipt): FlowPulseReceiptFixture {
  return {
    chainId: hexToDecimalString(`0x${DEFAULT_CHAIN_ID.toString(16)}`),
    blockNumber: hexToDecimalString(receipt.blockNumber),
    blockHash: receipt.blockHash,
    transactionHash: receipt.transactionHash,
    transactionIndex: hexToDecimalString(receipt.transactionIndex),
    status: receipt.status === "0x1" ? "success" : "reverted",
    logs: receipt.logs
      .filter((log) => log.topics[0]?.toLowerCase() === FLOWPULSE_TOPIC0.toLowerCase())
      .map((log) => ({
        address: log.address,
        topics: log.topics,
        data: log.data,
        logIndex: hexToDecimalString(log.logIndex),
        removed: log.removed,
      })),
  };
}

function parseFlowPulseObservationFromFixture(
  receipt: FlowPulseReceiptFixture,
  log: FlowPulseReceiptFixture["logs"][number],
) {
  return parseFlowPulseLogFixture({
    chainId: receipt.chainId,
    address: log.address,
    topics: log.topics,
    data: log.data,
    blockNumber: receipt.blockNumber,
    blockHash: receipt.blockHash,
    transactionHash: receipt.transactionHash,
    transactionIndex: receipt.transactionIndex,
    logIndex: log.logIndex,
    receiptStatus: receipt.status,
    removed: log.removed,
  });
}

function isStepReceipt(receipt: FlowPulseReceiptFixture): boolean {
  return receipt.logs.some((log) => {
    const observation = parseFlowPulseObservationFromFixture(receipt, log);
    return observation.pulseType === "16" || observation.pulseType === "18";
  });
}

export async function runAgentMemoryLocalE2E(): Promise<AgentMemoryLocalE2EReport> {
  process.chdir(REPO_ROOT);
  mkdirSync(OUT_DIR, { recursive: true });
  const port = 8547;
  const rpcUrl = `http://${DEFAULT_RPC_HOST}:${port}`;
  const anvil = spawn(process.platform === "win32" ? "anvil.exe" : "anvil", [
    "--host",
    DEFAULT_RPC_HOST,
    "--port",
    String(port),
    "--chain-id",
    String(DEFAULT_CHAIN_ID),
    "--timestamp",
    "1700000000",
    "--silent",
  ], {
    cwd: REPO_ROOT,
    stdio: "ignore",
    shell: false,
  });

  try {
    await waitForRpc(rpcUrl);
    const accounts = JSON.parse(runCommand("cast", ["rpc", "eth_accounts", "--rpc-url", rpcUrl])) as string[];
    const sender = accounts[0];
    if (typeof sender !== "string") {
      throw new Error("local anvil did not return an unlocked sender account");
    }

    runCommand("forge", [
      "script",
      "script/RunBaseAgentMemoryLocalE2E.s.sol:RunBaseAgentMemoryLocalE2E",
      "--rpc-url",
      rpcUrl,
      "--broadcast",
      "--unlocked",
      "--sender",
      sender,
      "--non-interactive",
      "--chain",
      String(DEFAULT_CHAIN_ID),
    ]);

    const artifact = readBroadcastArtifact();
    const deployedBaseOnchainAgentMemory = artifact.transactions.find((tx) => tx.transactionType === "CREATE" && tx.contractName === "BaseOnchainAgentMemory")?.contractAddress;
    const deployedTaskTarget = artifact.transactions.find((tx) => tx.transactionType === "CREATE" && tx.contractName === "BaseAgentMemoryTaskTargetMock")?.contractAddress;
    const stepTx = artifact.transactions.find((tx) => tx.contractName === "BaseOnchainAgentMemory" && tx.function?.startsWith("step("));
    const registerTx = artifact.transactions.find((tx) => tx.contractName === "BaseOnchainAgentMemory" && tx.function?.startsWith("registerAgent(")) ?? null;
    const registerTxHash = registerTx?.hash ?? null;
    const policyTxHash = artifact.transactions.find((tx) => tx.contractName === "BaseOnchainAgentMemory" && tx.function?.startsWith("setToolPolicy("))?.hash ?? null;
    const pauseTxHash = artifact.transactions.find((tx) => tx.contractName === "BaseOnchainAgentMemory" && tx.function?.startsWith("setAgentPaused("))?.hash ?? null;
    const correctionTxHash = artifact.transactions.find((tx) => tx.contractName === "BaseOnchainAgentMemory" && tx.function?.startsWith("correctMemory("))?.hash ?? null;
    if (!deployedBaseOnchainAgentMemory || !deployedTaskTarget || stepTx === undefined || registerTx === null) {
      throw new Error("broadcast artifact missing deployed BaseOnchainAgentMemory, BaseAgentMemoryTaskTargetMock, step transaction, or registerAgent transaction");
    }
    const registerArgs = registerTx.arguments ?? [];
    const initialMemoryRoot = registerArgs[4];
    if (initialMemoryRoot === undefined) {
      throw new Error("registerAgent transaction is missing initialMemoryRoot argument");
    }

    const candidateReceipts = artifact.transactions
      .filter((tx) => tx.contractName === "BaseOnchainAgentMemory" && tx.transactionType === "CALL")
      .map((tx) => receiptFor(rpcUrl, tx.hash))
      .map((receipt) => flowPulseReceiptFixture(receipt))
      .filter((receipt) => receipt.logs.length > 0);
    const stepFixture = candidateReceipts.find((receipt) => isStepReceipt(receipt));
    if (stepFixture === undefined) {
      throw new Error("could not find actual deployed-log step receipt with AGENT_STEP_COMMITTED / AGENT_MEMORY_COMMITTED pulses");
    }
    const parsedStep = deriveStepStateFromBroadcast(stepTx, deployedBaseOnchainAgentMemory, initialMemoryRoot);

    const receiptsPath = resolve(OUT_DIR, "flowpulse-receipts.json");
    writeJson(receiptsPath, {
      schema: "flowmemory.indexer.receiptFixtures.v0",
      description: "Actual deployed-log Base agent memory e2e receipts.",
      receipts: [stepFixture],
    });

    const indexerState = indexFlowPulseReceipts([stepFixture], {
      finalizedBlockNumber: stepFixture.blockNumber,
    });
    const resolver: ArtifactResolverFixture = {
      resolverPolicyId: "flowmemory.base_agent_memory.local_e2e",
      artifactsByUri: {
        [parsedStep.stepUri]: {
          kind: "agent-step-commitment",
          actionReceiptId: parsedStep.actionReceiptId,
        },
        [parsedStep.memoryUri]: {
          kind: "agent-memory-commitment",
          parentRoot: parsedStep.parentRoot,
          deltaRoot: parsedStep.deltaRoot,
          newRoot: parsedStep.newMemoryRoot,
          actionReceiptId: parsedStep.actionReceiptId,
          actionSucceeded: parsedStep.actionSucceeded,
        },
      },
    };
    const verifierReports = verifyObservations(indexerState.observations, resolver);

    const indexerPath = resolve(OUT_DIR, "indexer-state.json");
    const verifierPath = resolve(OUT_DIR, "verifier-reports.json");
    writeIndexerState(indexerPath, indexerState);
    writeVerifierReports(verifierPath, verifierReports);

    const statusCounts = verifierReports.reduce<Record<string, number>>((counts, report) => {
      counts[report.reportCore.status] = (counts[report.reportCore.status] ?? 0) + 1;
      return counts;
    }, {});
    const report: AgentMemoryLocalE2EReport = {
      schema: "flowmemory.base_agent_memory.local_e2e.v1",
      rpcUrl,
      chainId: String(DEFAULT_CHAIN_ID),
      deployed: {
        baseOnchainAgentMemory: deployedBaseOnchainAgentMemory,
        taskTarget: deployedTaskTarget,
      },
      transactions: {
        registerAgent: registerTxHash,
        setToolPolicy: policyTxHash,
        step: stepFixture.transactionHash,
        pause: pauseTxHash,
        correctMemory: correctionTxHash,
      },
      indexer: {
        observations: indexerState.observations.length,
        cursors: indexerState.cursors.length,
        rejectedLogs: indexerState.rejectedLogs.length,
        duplicates: indexerState.duplicates.length,
      },
      verifier: {
        reports: verifierReports.length,
        statusCounts,
      },
      outputs: {
        receiptsPath,
        indexerPath,
        verifierPath,
        reportPath: resolve(OUT_DIR, "report.json"),
      },
      localOnly: true,
    };
    writeJson(report.outputs.reportPath, report);
    return report;
  } finally {
    if (process.platform === "win32" && anvil.pid !== undefined) {
      spawnSync("taskkill", ["/pid", String(anvil.pid), "/t", "/f"], { stdio: "ignore", shell: true });
    } else {
      anvil.kill("SIGTERM");
    }
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  runAgentMemoryLocalE2E()
    .then((report) => {
      console.log(JSON.stringify(report, null, 2));
    })
    .catch((error) => {
      console.error(error instanceof Error ? error.message : String(error));
      process.exitCode = 1;
    });
}
