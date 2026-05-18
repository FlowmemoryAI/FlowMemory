#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

const rawArgs = process.argv.slice(2);
const args = new Set(rawArgs);
const planOnly = args.has("--plan-only");
const liveCheck = args.has("--live-check");
const envCheck = args.has("--env-check");
const evidenceCheck = args.has("--evidence");
const requireLiveProof = args.has("--require-live-proof");
const acceptancePackage = args.has("--acceptance-package");
const deploymentNote = args.has("--deployment-note");
const broadcast = args.has("--broadcast");
const swapProof = args.has("--swap-proof");
const readback = args.has("--readback");
const readbackRangePlan = args.has("--readback-range-plan");
const inferReadbackRange = args.has("--infer-readback-range")
  || process.env.BASE_SEPOLIA_V4_HOOK_INFER_READBACK_RANGE === "true";
const allowEmptyReadback = args.has("--allow-empty-readback");
const allowIncompleteAcceptance = args.has("--allow-incomplete");
const json = args.has("--json");

const BASE_SEPOLIA_CHAIN_ID = "84532";
const DEFAULT_PUBLIC_RPC_URL = "https://sepolia.base.org";
const CREATE2_DEPLOYER = "0x4e59b44847b379578588920cA78FbF26c0B4956C";
const DEFAULT_FLOWMEMORY_HOOK_SALT =
  "0x0000000000000000000000000000000000000000000000004915000000000000";
const ESTIMATED_SWAP_PROOF_BROADCAST_WEI = 50000000000000n;

const UNISWAP_BASE_SEPOLIA = {
  poolManager: "0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408",
  universalRouter: "0x492e6456D9528771018DeB9E87ef7750Ef184104",
  positionManager: "0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80",
  stateView: "0x571291b572ed32ce6751A2Cb2486EbEe8DEfB9B4",
  quoter: "0x4A6513c898fe1B2d0E78d3b0e0A4a151589B1cBa",
  poolSwapTest: "0x8B5bcC363ddE2614281aD875bad385E0A785D3B9",
  poolModifyLiquidityTest: "0x37429cd17cb1454c34e7f50b09725202fd533039",
  permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
};

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
    process.env.BASE_SEPOLIA_V4_HOOK_PROOF_PLAN_OUT ?? "fixtures/deployments/base-sepolia-v4-hook-proof-plan.json",
  ),
);
const artifactOut = resolve(
  readArgValue(
    "--artifact-out",
    process.env.BASE_SEPOLIA_V4_HOOK_PROOF_ARTIFACT_OUT
      ?? (envCheck
        ? "fixtures/deployments/base-sepolia-v4-hook-env-check.latest.json"
        : deploymentNote
          ? "fixtures/deployments/base-sepolia-v4-hook-deployment-note.latest.json"
        : acceptancePackage
          ? "fixtures/deployments/base-sepolia-v4-hook-acceptance.latest.json"
        : evidenceCheck
          ? "fixtures/deployments/base-sepolia-v4-hook-evidence.latest.json"
        : readbackRangePlan
        ? "fixtures/deployments/base-sepolia-v4-hook-readback-range.latest.json"
        : readback
        ? "fixtures/deployments/base-sepolia-v4-hook-readback.latest.json"
        : "fixtures/deployments/base-sepolia-v4-hook-proof.latest.json"),
  ),
);
const envCheckArtifactPath = resolve(
  readArgValue(
    "--env-artifact",
    process.env.BASE_SEPOLIA_V4_HOOK_ENV_CHECK_ARTIFACT
      ?? "fixtures/deployments/base-sepolia-v4-hook-env-check.latest.json",
  ),
);
const evidenceArtifactPath = resolve(
  readArgValue(
    "--evidence-artifact",
    process.env.BASE_SEPOLIA_V4_HOOK_EVIDENCE_ARTIFACT
      ?? "fixtures/deployments/base-sepolia-v4-hook-evidence.latest.json",
  ),
);
const proofArtifactPath = resolve(
  readArgValue(
    "--proof-artifact",
    process.env.BASE_SEPOLIA_V4_HOOK_PROOF_ARTIFACT
      ?? "fixtures/deployments/base-sepolia-v4-hook-proof.latest.json",
  ),
);
const readbackArtifactPath = resolve(
  readArgValue(
    "--readback-artifact",
    process.env.BASE_SEPOLIA_V4_HOOK_READBACK_ARTIFACT
      ?? "fixtures/deployments/base-sepolia-v4-hook-readback.latest.json",
  ),
);
const readbackRangeArtifactPath = resolve(
  readArgValue(
    "--readback-range-artifact",
    process.env.BASE_SEPOLIA_V4_HOOK_READBACK_RANGE_ARTIFACT
      ?? "fixtures/deployments/base-sepolia-v4-hook-readback-range.latest.json",
  ),
);
const flowMemoryArtifactPath = resolve(
  readArgValue(
    "--flowmemory-artifact",
    process.env.BASE_SEPOLIA_V4_HOOK_FLOWMEMORY_ARTIFACT
      ?? "fixtures/deployments/base-sepolia-v4-hook-flowmemory.latest.json",
  ),
);
const acceptanceArtifactPath = resolve(
  readArgValue(
    "--acceptance-artifact",
    process.env.BASE_SEPOLIA_V4_HOOK_ACCEPTANCE_ARTIFACT
      ?? "fixtures/deployments/base-sepolia-v4-hook-acceptance.latest.json",
  ),
);
const rpcUrl = readArgValue(
  "--rpc-url",
  process.env.BASE_SEPOLIA_RPC_URL ?? process.env.BASE_SEPOLIA_PUBLIC_RPC_URL ?? DEFAULT_PUBLIC_RPC_URL,
);
const explicitRpcProvided =
  rawArgs.includes("--rpc-url") || Boolean(process.env.BASE_SEPOLIA_RPC_URL || process.env.BASE_SEPOLIA_PUBLIC_RPC_URL);
const deployerKey = process.env.BASE_SEPOLIA_DEPLOYER_KEY_HEX ?? process.env.FLOWMEMORY_HOOK_DEPLOYER_KEY_HEX;
const operatorSalt = readArgValue("--salt", process.env.FLOWMEMORY_HOOK_SALT ?? null);
const explicitSalt = operatorSalt ?? DEFAULT_FLOWMEMORY_HOOK_SALT;
const readbackFromBlock = readArgValue("--from-block", process.env.BASE_SEPOLIA_V4_HOOK_READBACK_FROM_BLOCK ?? null);
const readbackToBlock = readArgValue("--to-block", process.env.BASE_SEPOLIA_V4_HOOK_READBACK_TO_BLOCK ?? null);
const readbackFinalizedBlock = readArgValue(
  "--finalized-block",
  process.env.BASE_SEPOLIA_V4_HOOK_READBACK_FINALIZED_BLOCK ?? null,
);
const readbackStateOut = resolve(
  readArgValue(
    "--state-out",
    process.env.BASE_SEPOLIA_V4_HOOK_READBACK_STATE_OUT
      ?? "fixtures/deployments/base-sepolia-v4-hook-readback-state.latest.json",
  ),
);
const readbackCheckpointOut = resolve(
  readArgValue(
    "--checkpoint-out",
    process.env.BASE_SEPOLIA_V4_HOOK_READBACK_CHECKPOINT_OUT
      ?? "fixtures/deployments/base-sepolia-v4-hook-readback-checkpoint.latest.json",
  ),
);
const generatedAt = readArgValue("--generated-at", process.env.BASE_SEPOLIA_V4_HOOK_PROOF_GENERATED_AT ?? null)
  ?? readExistingGeneratedAt(planOut)
  ?? new Date().toISOString();

function readExistingGeneratedAt(path) {
  if (!existsSync(path)) return null;
  try {
    const parsed = JSON.parse(readFileSync(path, "utf8"));
    return typeof parsed.generatedAt === "string" ? parsed.generatedAt : null;
  } catch {
    return null;
  }
}

function runCapture(command, commandArgs, options = {}) {
  const result = spawnSync(command, commandArgs, {
    cwd: process.cwd(),
    encoding: "utf8",
    shell: false,
    ...options,
  });
  if (result.error) {
    throw new Error(`${redactedCommand(command, commandArgs)} failed: ${result.error.message}`);
  }
  if (result.status !== 0) {
    const detail = result.stderr?.trim() || result.stdout?.trim() || `exit code ${result.status}`;
    throw new Error(`${redactedCommand(command, commandArgs)} failed: ${detail}`);
  }
  return result.stdout.trim();
}

function runInherit(command, commandArgs, options = {}) {
  const result = spawnSync(command, commandArgs, {
    cwd: process.cwd(),
    stdio: "inherit",
    shell: false,
    ...options,
  });
  if (result.error) {
    throw new Error(`${redactedCommand(command, commandArgs)} failed: ${result.error.message}`);
  }
  if (result.status !== 0) {
    throw new Error(`${redactedCommand(command, commandArgs)} failed with exit code ${result.status ?? "unknown"}`);
  }
  return result.status;
}

function redactedCommand(command, commandArgs) {
  const redactedArgs = [];
  const secretValueFlags = new Set(["--private-key", "--rpc-url", "--etherscan-api-key"]);
  for (let i = 0; i < commandArgs.length; i++) {
    const arg = commandArgs[i];
    redactedArgs.push(arg);
    if (secretValueFlags.has(arg) && i + 1 < commandArgs.length) {
      redactedArgs.push(`<redacted-${arg.slice(2)}>`);
      i++;
    }
  }
  return `${command} ${redactedArgs.join(" ")}`;
}

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function readJsonIfExists(path) {
  if (!existsSync(path)) return null;
  return JSON.parse(readFileSync(path, "utf8"));
}

function requirePrivateKeyForForgeRun() {
  if (!deployerKey) {
    throw new Error("BASE_SEPOLIA_DEPLOYER_KEY_HEX or FLOWMEMORY_HOOK_DEPLOYER_KEY_HEX is required for dry-run/broadcast");
  }
  if (!/^0x[0-9a-fA-F]{64}$/.test(deployerKey)) {
    throw new Error("deployer private key must be a 0x-prefixed 32-byte hex key");
  }
}

function redactedEnv() {
  return {
    BASE_SEPOLIA_RPC_URL: process.env.BASE_SEPOLIA_RPC_URL ? "<set>" : "<missing>",
    BASE_SEPOLIA_PUBLIC_RPC_URL: process.env.BASE_SEPOLIA_PUBLIC_RPC_URL ? "<set>" : "<default-public>",
    BASE_SEPOLIA_DEPLOYER_KEY_HEX: process.env.BASE_SEPOLIA_DEPLOYER_KEY_HEX ? "<set:redacted>" : "<missing>",
    FLOWMEMORY_HOOK_DEPLOYER_KEY_HEX: process.env.FLOWMEMORY_HOOK_DEPLOYER_KEY_HEX ? "<set:redacted>" : "<missing>",
    FLOWMEMORY_HOOK_SALT: operatorSalt ? "<set>" : "<default-mined>",
    BASE_SEPOLIA_BASESCAN_API_KEY: process.env.BASE_SEPOLIA_BASESCAN_API_KEY ? "<set:redacted>" : "<missing>",
    BASESCAN_API_KEY: process.env.BASESCAN_API_KEY ? "<set:redacted>" : "<missing>",
    FLOWMEMORY_HOOK_PROOF_OPERATOR: process.env.FLOWMEMORY_HOOK_PROOF_OPERATOR
      ? "<set>"
      : deployerKey
        ? "<derived-from-deployer-key>"
        : "<missing>",
    FLOWMEMORY_HOOK_PROOF_TOKEN_MINT: process.env.FLOWMEMORY_HOOK_PROOF_TOKEN_MINT ? "<set>" : "<default>",
    FLOWMEMORY_HOOK_PROOF_LIQUIDITY_DELTA: process.env.FLOWMEMORY_HOOK_PROOF_LIQUIDITY_DELTA
      ? "<set>"
      : "<default>",
    FLOWMEMORY_HOOK_PROOF_SWAP_AMOUNT: process.env.FLOWMEMORY_HOOK_PROOF_SWAP_AMOUNT ? "<set>" : "<default>",
  };
}

function assertHex32(value, name) {
  if (!/^0x[0-9a-fA-F]{64}$/.test(value)) {
    throw new Error(`${name} must be a 0x-prefixed 32-byte hex value`);
  }
}

function buildInitCode() {
  runCapture("forge", ["build"]);
  const bytecode = runCapture("forge", ["inspect", "FlowMemoryAfterSwapHook", "bytecode"]);
  const constructorArgs = runCapture("cast", [
    "abi-encode",
    "constructor(address)",
    UNISWAP_BASE_SEPOLIA.poolManager,
  ]);
  return `${bytecode}${constructorArgs.slice(2)}`;
}

function patchRuntimeBytecodeImmutables(runtimeBytecode, immutableReferences, replacementHex32) {
  if (typeof runtimeBytecode !== "string" || !/^0x[0-9a-fA-F]*$/.test(runtimeBytecode)) {
    throw new Error("FlowMemoryAfterSwapHook deployed bytecode artifact is missing a valid runtime object");
  }
  if (!/^0x[0-9a-fA-F]{64}$/.test(replacementHex32)) {
    throw new Error("immutable replacement must be a 32-byte hex value");
  }

  const bytes = runtimeBytecode.slice(2).split("");
  const references = Object.values(immutableReferences ?? {}).flat();
  if (references.length === 0) {
    return runtimeBytecode;
  }

  for (const reference of references) {
    const start = Number(reference?.start);
    const length = Number(reference?.length);
    if (!Number.isInteger(start) || !Number.isInteger(length) || start < 0 || length !== 32) {
      throw new Error(`unsupported immutable reference in FlowMemoryAfterSwapHook artifact: ${JSON.stringify(reference)}`);
    }
    const nibbleStart = start * 2;
    const nibbleLength = length * 2;
    bytes.splice(nibbleStart, nibbleLength, replacementHex32.slice(2).toLowerCase());
  }

  return `0x${bytes.join("")}`;
}

function buildExpectedHookRuntimeIdentity() {
  const artifactPath = resolve("out/FlowMemoryAfterSwapHook.sol/FlowMemoryAfterSwapHook.json");
  const artifact = readJsonIfExists(artifactPath);
  if (!artifact) {
    throw new Error(`missing FlowMemoryAfterSwapHook artifact after forge build: ${artifactPath}`);
  }

  const encodedPoolManager = runCapture("cast", [
    "abi-encode",
    "constructor(address)",
    UNISWAP_BASE_SEPOLIA.poolManager,
  ]);
  const runtimeBytecode = patchRuntimeBytecodeImmutables(
    artifact.deployedBytecode?.object,
    artifact.deployedBytecode?.immutableReferences,
    encodedPoolManager,
  );
  const runtimeBytecodeHash = runCapture("cast", ["keccak", runtimeBytecode]);
  const immutableReferenceCount = Object.values(artifact.deployedBytecode?.immutableReferences ?? {})
    .reduce((count, references) => count + (Array.isArray(references) ? references.length : 0), 0);

  return {
    artifact: "out/FlowMemoryAfterSwapHook.sol/FlowMemoryAfterSwapHook.json",
    runtimeBytecodeHash,
    runtimeByteLength: (runtimeBytecode.length - 2) / 2,
    immutableReferenceCount,
    immutableConstructorArgs: {
      poolManager: UNISWAP_BASE_SEPOLIA.poolManager,
    },
  };
}

function resolveProofOperator() {
  if (!deployerKey) {
    throw new Error("deployer private key is required before resolving the proof operator");
  }

  const derivedOperator = runCapture("cast", ["wallet", "address", "--private-key", deployerKey]).trim();
  if (!/^0x[0-9a-fA-F]{40}$/.test(derivedOperator)) {
    throw new Error(`could not derive a valid deployer address from the provided private key`);
  }

  const explicitOperator = process.env.FLOWMEMORY_HOOK_PROOF_OPERATOR;
  if (!explicitOperator) {
    return derivedOperator;
  }
  if (!/^0x[0-9a-fA-F]{40}$/.test(explicitOperator)) {
    throw new Error("FLOWMEMORY_HOOK_PROOF_OPERATOR must be a 0x-prefixed address");
  }
  if (explicitOperator.toLowerCase() !== derivedOperator.toLowerCase()) {
    throw new Error(
      "FLOWMEMORY_HOOK_PROOF_OPERATOR must match the deployer signer for the swap-proof script; the proof tokens are minted, approved, and swapped by the broadcast signer.",
    );
  }
  return explicitOperator;
}

function weiToEthDecimal(weiValue) {
  const wei = BigInt(weiValue);
  const whole = wei / 1000000000000000000n;
  const fraction = (wei % 1000000000000000000n).toString().padStart(18, "0").replace(/0+$/, "");
  return fraction.length > 0 ? `${whole}.${fraction}` : whole.toString();
}

function runEnvCheck(plan) {
  const missing = [];
  const errors = [];
  let chainId = null;
  let chainIdOk = false;
  let deployerAddress = null;
  let balanceWei = null;
  let deployerKeyFormatOk = false;

  if (!explicitRpcProvided) {
    missing.push("BASE_SEPOLIA_RPC_URL or BASE_SEPOLIA_PUBLIC_RPC_URL");
  }

  try {
    chainId = runCapture("cast", ["chain-id", "--rpc-url", rpcUrl]);
    chainIdOk = chainId === BASE_SEPOLIA_CHAIN_ID;
    if (!chainIdOk) {
      errors.push(`RPC chain id ${chainId} does not match Base Sepolia ${BASE_SEPOLIA_CHAIN_ID}`);
    }
  } catch (error) {
    errors.push(error.message);
  }

  if (!deployerKey) {
    missing.push("BASE_SEPOLIA_DEPLOYER_KEY_HEX or FLOWMEMORY_HOOK_DEPLOYER_KEY_HEX");
  } else if (!/^0x[0-9a-fA-F]{64}$/.test(deployerKey)) {
    errors.push("deployer private key must be a 0x-prefixed 32-byte hex key");
  } else {
    deployerKeyFormatOk = true;
    try {
      deployerAddress = runCapture("cast", ["wallet", "address", "--private-key", deployerKey]).trim();
    } catch (error) {
      errors.push(error.message);
    }
  }

  if (deployerAddress && chainIdOk) {
    try {
      balanceWei = runCapture("cast", ["balance", deployerAddress, "--rpc-url", rpcUrl]);
    } catch (error) {
      errors.push(error.message);
    }
  }

  const balanceAppearsFunded =
    typeof balanceWei === "string" && BigInt(balanceWei) >= ESTIMATED_SWAP_PROOF_BROADCAST_WEI;
  const broadcastReady =
    missing.length === 0 && errors.length === 0 && deployerKeyFormatOk && chainIdOk && balanceAppearsFunded;

  return {
    schema: "flowmemory.base_sepolia.v4_hook_env_check.v0",
    generatedAt,
    mode: "env-check",
    productionReady: false,
    broadcastReady,
    planPath: planOut,
    hook: plan.hook,
    environment: redactedEnv(),
    rpc: {
      providedByOperator: explicitRpcProvided,
      usingDefaultPublicRpc: rpcUrl === DEFAULT_PUBLIC_RPC_URL && !explicitRpcProvided,
      chainId,
      chainIdOk,
    },
    deployer: {
      keyPresent: Boolean(deployerKey),
      keyFormatOk: deployerKeyFormatOk,
      address: deployerAddress,
      balance: balanceWei
        ? {
          wei: balanceWei,
          eth: weiToEthDecimal(balanceWei),
          estimatedSwapProofWei: ESTIMATED_SWAP_PROOF_BROADCAST_WEI.toString(),
          estimatedSwapProofEth: weiToEthDecimal(ESTIMATED_SWAP_PROOF_BROADCAST_WEI),
          appearsFundedForSwapProofEstimate: balanceAppearsFunded,
        }
        : null,
    },
    missing,
    errors,
    nextSteps: broadcastReady
      ? [
        "Run npm run hook:base-sepolia:swap-proof:broadcast -- --json.",
        "Run npm run hook:base-sepolia:readback-range -- --infer-readback-range --json to derive the readback window from successful broadcast receipts.",
        "Run npm run hook:base-sepolia:readback:auto -- --json, or run hook:base-sepolia:readback manually with an operator-reviewed block range.",
      ]
      : [
        "Set a Base Sepolia RPC URL and a funded testnet deployer key in the local shell only.",
        "Rerun npm run hook:base-sepolia:env-check -- --json until broadcastReady is true.",
      ],
    boundaries: plan.boundaries,
  };
}

function selectedScriptFileName(selectedScript) {
  return selectedScript.split(":")[0].split(/[\\/]/).pop();
}

function foundryRunPath(selectedScript, isBroadcast) {
  const scriptFile = selectedScriptFileName(selectedScript);
  return resolve(
    "broadcast",
    scriptFile,
    BASE_SEPOLIA_CHAIN_ID,
    isBroadcast ? "run-latest.json" : join("dry-run", "run-latest.json"),
  );
}

function parseTupleValue(value) {
  if (typeof value !== "string") return [];
  const trimmed = value.trim();
  if (!trimmed.startsWith("(") || !trimmed.endsWith(")")) return [];
  return trimmed.slice(1, -1).split(",").map((part) => part.trim());
}

function parseProofReturn(returns) {
  const parts = parseTupleValue(returns?.proof?.value);
  if (parts.length !== 13) return null;
  return {
    chainId: parts[0],
    operator: parts[1],
    hookAddress: parts[2],
    token0: parts[3],
    token1: parts[4],
    poolId: parts[5],
    rootfieldId: parts[6],
    commitment: parts[7],
    parentPulseId: parts[8],
    hookSalt: parts[9],
    initCodeHash: parts[10],
    liquidityDelta: parts[11],
    swapAmountSpecified: parts[12],
  };
}

function parseDeploymentReturn(returns) {
  const parts = parseTupleValue(returns?.deployment?.value);
  if (parts.length !== 7) return null;
  return {
    chainId: parts[0],
    poolManager: parts[1],
    create2Deployer: parts[2],
    salt: parts[3],
    initCodeHash: parts[4],
    hookAddress: parts[5],
    alreadyDeployed: parts[6],
  };
}

function decimalFromHexOrNumber(value) {
  if (typeof value === "number") return String(value);
  if (typeof value !== "string") return null;
  if (value.startsWith("0x")) return BigInt(value).toString();
  return value;
}

function summarizeFoundryRun(selectedScript, isBroadcast) {
  const path = foundryRunPath(selectedScript, isBroadcast);
  const foundryRun = readJsonIfExists(path);
  if (!foundryRun) {
    return { path, present: false };
  }

  const transactions = Array.isArray(foundryRun.transactions) ? foundryRun.transactions : [];
  const receipts = Array.isArray(foundryRun.receipts) ? foundryRun.receipts : [];
  return {
    path,
    present: true,
    chain: foundryRun.chain ?? null,
    commit: foundryRun.commit ?? null,
    timestamp: foundryRun.timestamp ?? null,
    transactionCount: transactions.length,
    receiptCount: receipts.length,
    transactions: transactions.map((entry) => ({
      hash: entry.hash ?? null,
      transactionType: entry.transactionType ?? null,
      contractName: entry.contractName ?? null,
      contractAddress: entry.contractAddress ?? null,
      function: entry.function ?? null,
      from: entry.transaction?.from ?? null,
      to: entry.transaction?.to ?? null,
      nonce: decimalFromHexOrNumber(entry.transaction?.nonce),
      value: decimalFromHexOrNumber(entry.transaction?.value),
      chainId: decimalFromHexOrNumber(entry.transaction?.chainId),
    })),
    receipts: receipts.map((receipt) => ({
      transactionHash: receipt.transactionHash ?? receipt.hash ?? null,
      blockNumber: decimalFromHexOrNumber(receipt.blockNumber),
      status: decimalFromHexOrNumber(receipt.status),
      contractAddress: receipt.contractAddress ?? null,
      to: receipt.to ?? null,
      logs: Array.isArray(receipt.logs) ? receipt.logs.length : null,
    })),
    proof: parseProofReturn(foundryRun.returns),
    deployment: parseDeploymentReturn(foundryRun.returns),
  };
}

function receiptBlockNumber(receipt) {
  const decimal = decimalFromHexOrNumber(receipt?.blockNumber);
  if (decimal === null || decimal === undefined || decimal === "") {
    return null;
  }
  return BigInt(decimal);
}

function inferReadbackRangeFromProofArtifact(plan) {
  const artifact = readJsonIfExists(proofArtifactPath);
  if (!artifact) {
    throw new Error(`cannot infer readback range because proof artifact is missing: ${proofArtifactPath}`);
  }
  if (artifact.mode !== "swap-proof-broadcast" || artifact.forge?.broadcast !== true) {
    throw new Error(`cannot infer readback range from non-broadcast proof artifact mode: ${artifact.mode ?? "<missing>"}`);
  }
  if (!sameAddress(artifact.hook?.hookAddress, plan.hook.hookAddress)) {
    throw new Error("cannot infer readback range because proof artifact hook address does not match the current plan");
  }
  if (!proofMatchesPlan(artifact.proof, plan)) {
    throw new Error("cannot infer readback range because proof artifact proof fields do not match the current plan");
  }

  const receipts = Array.isArray(artifact.foundryRun?.receipts) ? artifact.foundryRun.receipts : [];
  const successfulReceiptBlocks = receipts
    .filter((receipt) => String(receipt.status ?? "") === "1")
    .map(receiptBlockNumber)
    .filter((block) => block !== null);
  if (successfulReceiptBlocks.length === 0) {
    throw new Error("cannot infer readback range because the broadcast proof artifact has no successful receipt block numbers");
  }

  const fromBlock = successfulReceiptBlocks.reduce((left, right) => left < right ? left : right).toString();
  const toBlock = successfulReceiptBlocks.reduce((left, right) => left > right ? left : right).toString();

  return {
    source: "broadcast-proof-artifact-receipts",
    proofArtifactPath,
    receiptCount: receipts.length,
    successfulReceiptBlockCount: successfulReceiptBlocks.length,
    fromBlock,
    toBlock,
    finalizedBlock: toBlock,
  };
}

function resolveReadbackRange(plan) {
  if (readbackFromBlock && readbackToBlock) {
    return {
      source: "operator-explicit",
      fromBlock: readbackFromBlock,
      toBlock: readbackToBlock,
      finalizedBlock: readbackFinalizedBlock,
      proofArtifactPath: null,
    };
  }
  if (inferReadbackRange) {
    const inferred = inferReadbackRangeFromProofArtifact(plan);
    return {
      ...inferred,
      fromBlock: readbackFromBlock ?? inferred.fromBlock,
      toBlock: readbackToBlock ?? inferred.toBlock,
      finalizedBlock: readbackFinalizedBlock ?? inferred.finalizedBlock,
    };
  }
  return {
    source: "missing",
    fromBlock: readbackFromBlock,
    toBlock: readbackToBlock,
    finalizedBlock: readbackFinalizedBlock,
    proofArtifactPath: null,
  };
}

function requireReadbackInputs(range) {
  if (!explicitRpcProvided) {
    throw new Error("--readback requires --rpc-url, BASE_SEPOLIA_RPC_URL, or BASE_SEPOLIA_PUBLIC_RPC_URL");
  }
  if (!range.fromBlock) {
    throw new Error("--readback requires --from-block or --infer-readback-range");
  }
  if (!range.toBlock) {
    throw new Error("--readback requires --to-block or --infer-readback-range");
  }
}

function runReadback(plan) {
  const range = resolveReadbackRange(plan);
  requireReadbackInputs(range);
  const indexerArgs = [
    "services/indexer/src/base-sepolia.ts",
    "--rpc-url",
    rpcUrl,
    "--address",
    plan.hook.hookAddress,
    "--from-block",
    range.fromBlock,
    "--to-block",
    range.toBlock,
    "--out",
    readbackStateOut,
    "--checkpoint-out",
    readbackCheckpointOut,
  ];
  if (range.finalizedBlock) {
    indexerArgs.push("--finalized-block", range.finalizedBlock);
  }

  const status = runInherit("node", indexerArgs);
  const state = readJsonIfExists(readbackStateOut);
  const checkpoint = readJsonIfExists(readbackCheckpointOut);
  const observationCount = Number(checkpoint?.observationCount ?? state?.observations?.length ?? 0);
  if (!allowEmptyReadback && observationCount < 1) {
    throw new Error(
      `Base Sepolia hook readback found ${observationCount} FlowPulse observations for ${plan.hook.hookAddress}; rerun with the correct deploy/swap block range or --allow-empty-readback for diagnostics only.`,
    );
  }

  return {
    schema: "flowmemory.base_sepolia.v4_hook_readback_artifact.v0",
    generatedAt,
    mode: "readback",
    productionReady: false,
    proofComplete: observationCount > 0,
    planPath: planOut,
    hook: plan.hook,
    indexer: {
      status,
      statePath: readbackStateOut,
      checkpointPath: readbackCheckpointOut,
      rangeSource: range.source,
      inferredFromProofArtifact: range.proofArtifactPath,
      fromBlock: range.fromBlock,
      toBlock: range.toBlock,
      finalizedBlock: range.finalizedBlock,
      observationCount,
      rejectedLogCount: checkpoint?.rejectedLogCount ?? null,
      duplicateCount: checkpoint?.duplicateCount ?? null,
      dashboardCanonicalObservationCount: checkpoint?.dashboardFeed?.dashboardCanonicalObservationCount ?? null,
      lastIndexedBlock: checkpoint?.lastIndexedBlock ?? null,
      nextFromBlock: checkpoint?.nextFromBlock ?? null,
      emptyRange: checkpoint?.emptyRange ?? null,
      hasIntegrityWarnings: checkpoint?.dashboardFeed?.hasIntegrityWarnings ?? null,
    },
    nextSteps:
      observationCount > 0
        ? ["Generate Flow Memory / Rootflow state and dashboard evidence from this live Base Sepolia observation."]
        : ["Rerun readback over the block range that contains the real Base Sepolia swap transaction."],
    boundaries: plan.boundaries,
  };
}

function runReadbackRangePlan(plan) {
  const range = resolveReadbackRange(plan);
  if (!range.fromBlock || !range.toBlock) {
    throw new Error("readback range plan requires explicit --from-block/--to-block or --infer-readback-range");
  }

  return {
    schema: "flowmemory.base_sepolia.v4_hook_readback_range.v0",
    generatedAt,
    mode: "readback-range-plan",
    productionReady: false,
    planPath: planOut,
    hook: plan.hook,
    range,
    command: `npm run hook:base-sepolia:readback -- --rpc-url $BASE_SEPOLIA_RPC_URL --from-block ${range.fromBlock} --to-block ${range.toBlock}${range.finalizedBlock ? ` --finalized-block ${range.finalizedBlock}` : ""} --json`,
    autoReadbackCommand: "npm run hook:base-sepolia:readback:auto -- --json",
    boundaries: plan.boundaries,
  };
}

function sameAddress(left, right) {
  return typeof left === "string" && typeof right === "string" && left.toLowerCase() === right.toLowerCase();
}

function findLiveCheck(plan, name) {
  return plan.liveCheck?.checks?.find((check) => check.name === name) ?? null;
}

function hasTransactionFunction(artifact, fragment) {
  const transactions = artifact?.foundryRun?.transactions;
  return Array.isArray(transactions) && transactions.some((tx) => String(tx.function ?? "").includes(fragment));
}

function transactionHashesForFunction(artifact, fragment) {
  const transactions = artifact?.foundryRun?.transactions;
  if (!Array.isArray(transactions)) return [];
  return transactions
    .filter((tx) => String(tx.function ?? "").includes(fragment))
    .map((tx) => normalizeTxHash(tx.hash ?? tx.transactionHash))
    .filter(Boolean);
}

function successfulReceiptMatchesForFunction(artifact, fragment) {
  const transactionHashes = transactionHashesForFunction(artifact, fragment);
  const successfulReceiptHashes = new Set(successfulReceiptTxHashesFromProofArtifact(artifact));
  const successfulTransactionHashes = transactionHashes.filter((hash) => successfulReceiptHashes.has(hash));
  return {
    transactionHashes,
    successfulTransactionHashes,
    allTransactionsSucceeded: transactionHashes.length > 0 && transactionHashes.length === successfulTransactionHashes.length,
  };
}

function proofMatchesPlan(proof, plan) {
  return Boolean(
    proof
      && proof.chainId === BASE_SEPOLIA_CHAIN_ID
      && sameAddress(proof.hookAddress, plan.hook.hookAddress)
      && proof.hookSalt === plan.hook.salt
      && proof.initCodeHash === plan.hook.initCodeHash
      && /^0x[0-9a-fA-F]{64}$/.test(proof.poolId ?? "")
      && /^0x[0-9a-fA-F]{64}$/.test(proof.rootfieldId ?? "")
      && /^0x[0-9a-fA-F]{64}$/.test(proof.commitment ?? ""),
  );
}

function runEvidenceCheck(plan) {
  const envArtifact = readJsonIfExists(envCheckArtifactPath);
  const proofArtifact = readJsonIfExists(proofArtifactPath);
  const readbackArtifact = readJsonIfExists(readbackArtifactPath);
  const requiredLiveCodeNames = [
    "create2Deployer",
    "poolManager",
    "universalRouter",
    "positionManager",
    "stateView",
    "quoter",
    "poolSwapTest",
    "poolModifyLiquidityTest",
    "permit2",
  ];
  const requiredLiveCodePresent =
    plan.liveCheck?.chainIdOk === true
    && requiredLiveCodeNames.every((name) => findLiveCheck(plan, name)?.codePresent === true);
  const plannedHookLiveCodeCheck = findLiveCheck(plan, "plannedFlowMemoryAfterSwapHook");
  const plannedHookCodePresent = plannedHookLiveCodeCheck?.codePresent === true;
  const plannedHookRuntimeBytecodeMatches =
    plannedHookLiveCodeCheck?.runtimeBytecodeHashMatches === true
    && plannedHookLiveCodeCheck?.expectedRuntimeBytecodeHash === plan.hook.expectedRuntime?.runtimeBytecodeHash;

  const dryRunProofReady = Boolean(
    proofArtifact
      && proofArtifact.mode === "swap-proof-dry-run"
      && proofArtifact.forge?.status === 0
      && proofArtifact.forge?.broadcast === false
      && proofArtifact.foundryRun?.present === true
      && Number(proofArtifact.foundryRun?.transactionCount ?? 0) >= 12
      && proofMatchesPlan(proofArtifact.proof, plan)
      && hasTransactionFunction(proofArtifact, "initialize(")
      && hasTransactionFunction(proofArtifact, "modifyLiquidity(")
      && hasTransactionFunction(proofArtifact, "swap("),
  );
  const broadcastProofReady = Boolean(
    proofArtifact
      && proofArtifact.mode === "swap-proof-broadcast"
      && proofArtifact.forge?.status === 0
      && proofArtifact.forge?.broadcast === true
      && proofArtifact.foundryRun?.present === true
      && Number(proofArtifact.foundryRun?.receiptCount ?? 0) > 0
      && proofMatchesPlan(proofArtifact.proof, plan),
  );
  const readbackProofReady = Boolean(
    readbackArtifact
      && readbackArtifact.mode === "readback"
      && readbackArtifact.proofComplete === true
      && Number(readbackArtifact.indexer?.observationCount ?? 0) > 0
      && readbackArtifact.indexer?.hasIntegrityWarnings === false
      && sameAddress(readbackArtifact.hook?.hookAddress, plan.hook.hookAddress),
  );
  const envReady = envArtifact?.broadcastReady === true;
  const complete =
    requiredLiveCodePresent
    && plannedHookCodePresent
    && plannedHookRuntimeBytecodeMatches
    && broadcastProofReady
    && readbackProofReady;
  const stage = complete
    ? "live-proof-complete"
    : readbackProofReady
      ? "readback-observed-without-broadcast-artifact"
      : broadcastProofReady
        ? "broadcast-awaiting-readback"
        : dryRunProofReady
          ? "dry-run-proof-ready"
          : envReady
            ? "broadcast-env-ready"
            : "pending-operator-env-or-dry-run";

  const missing = [];
  if (!requiredLiveCodePresent) missing.push("official Base Sepolia Uniswap v4 contract code check");
  if (!plannedHookCodePresent) missing.push("deployed FlowMemoryAfterSwapHook code at the mined hook address");
  if (plannedHookCodePresent && !plannedHookRuntimeBytecodeMatches) {
    missing.push("deployed FlowMemoryAfterSwapHook runtime bytecode hash matching the local compiled artifact");
  }
  if (!envReady) missing.push("local env-check with funded Base Sepolia deployer");
  if (!dryRunProofReady) missing.push("successful swap-proof dry-run artifact");
  if (!broadcastProofReady) missing.push("broadcast swap-proof artifact with receipts");
  if (!readbackProofReady) missing.push("non-empty Base Sepolia hook FlowPulse readback artifact");

  return {
    schema: "flowmemory.base_sepolia.v4_hook_evidence.v0",
    generatedAt,
    mode: "evidence",
    productionReady: false,
    liveProofComplete: complete,
    stage,
    planPath: planOut,
    inputs: {
      envArtifactPath: envCheckArtifactPath,
      proofArtifactPath,
      readbackArtifactPath,
    },
    hook: plan.hook,
    evidence: {
      officialContractsCodePresent: requiredLiveCodePresent,
      plannedHookCodePresent,
      plannedHookRuntimeBytecodeMatches,
      plannedHookRuntimeCodeHash: plannedHookLiveCodeCheck?.codeHash ?? null,
      expectedHookRuntimeCodeHash: plan.hook.expectedRuntime?.runtimeBytecodeHash ?? null,
      envBroadcastReady: envReady,
      dryRunProofReady,
      broadcastProofReady,
      readbackProofReady,
      readbackObservationCount: Number(readbackArtifact?.indexer?.observationCount ?? 0),
      readbackProofComplete: readbackArtifact?.proofComplete === true,
      dryRunTransactionCount: Number(proofArtifact?.foundryRun?.transactionCount ?? 0),
      broadcastReceiptCount: Number(proofArtifact?.foundryRun?.receiptCount ?? 0),
    },
    missing,
    nextSteps: complete
      ? ["Generate Flow Memory / Rootflow dashboard evidence from the live Base Sepolia observation."]
      : [
        "Run npm run hook:base-sepolia:env-check -- --json until broadcastReady is true.",
        "Run npm run hook:base-sepolia:swap-proof:broadcast -- --json with the funded testnet key.",
        "Run npm run hook:base-sepolia:readback-range -- --infer-readback-range --json to derive the readback window from broadcast receipts.",
        "Run npm run hook:base-sepolia:readback:auto -- --json or npm run hook:base-sepolia:readback with an operator-reviewed range, and require proofComplete true.",
        "Rerun npm run hook:base-sepolia:evidence -- --json.",
      ],
    claimBoundary: complete
      ? "This is still public-testnet evidence, not production mainnet readiness."
      : "Do not claim the real Uniswap v4 PoolManager hook proof is live until liveProofComplete is true.",
    boundaries: plan.boundaries,
  };
}

function positiveInteger(value) {
  const number = Number(value ?? 0);
  return Number.isInteger(number) && number > 0;
}

function sameHook(left, plan) {
  return sameAddress(left?.hookAddress, plan.hook.hookAddress);
}

function normalizeOptionalBlock(value) {
  if (value === undefined || value === null || value === "") return null;
  return String(value);
}

function normalizeTxHash(value) {
  if (typeof value !== "string" || !/^0x[0-9a-fA-F]{64}$/.test(value)) return null;
  return value.toLowerCase();
}

function successfulReceiptTxHashesFromProofArtifact(artifact) {
  const receipts = Array.isArray(artifact?.foundryRun?.receipts) ? artifact.foundryRun.receipts : [];
  const hashes = receipts
    .filter((receipt) => decimalFromHexOrNumber(receipt?.status) === "1")
    .map((receipt) => normalizeTxHash(receipt?.transactionHash ?? receipt?.hash))
    .filter(Boolean);
  return Array.from(new Set(hashes));
}

function flowMemorySignalTxHashes(artifact) {
  const signals = Array.isArray(artifact?.memorySignals) ? artifact.memorySignals : [];
  const hashes = signals
    .map((signal) => normalizeTxHash(signal?.txHash ?? signal?.contractEvent?.receiptLocator?.txHash))
    .filter(Boolean);
  return Array.from(new Set(hashes));
}

function acceptanceCheck(name, ok, evidence, remediation) {
  return {
    name,
    ok: Boolean(ok),
    evidence,
    ...(remediation ? { remediation } : {}),
  };
}

function runAcceptancePackage(plan) {
  const envArtifact = readJsonIfExists(envCheckArtifactPath);
  const proofArtifact = readJsonIfExists(proofArtifactPath);
  const readbackRangeArtifact = readJsonIfExists(readbackRangeArtifactPath);
  const readbackArtifact = readJsonIfExists(readbackArtifactPath);
  const flowMemoryArtifact = readJsonIfExists(flowMemoryArtifactPath);
  const evidenceArtifact = runEvidenceCheck(plan);
  const flowMemoryChecks = flowMemoryArtifact?.checks ?? {};

  const readbackObservationCount = Number(readbackArtifact?.indexer?.observationCount ?? 0);
  const flowMemoryObservationCount = Number(flowMemoryArtifact?.checks?.observationCount ?? 0);
  const canonicalObservationCount = Number(flowMemoryChecks.canonicalObservationCount ?? 0);
  const swapMemorySignalObservationCount = Number(flowMemoryChecks.swapMemorySignalObservationCount ?? 0);
  const memorySignalCount = Number(flowMemoryArtifact?.memorySignals?.length ?? 0);
  const memoryReceiptCount = Number(flowMemoryArtifact?.memoryReceipts?.length ?? 0);
  const rootflowTransitionCount = Number(flowMemoryArtifact?.rootflowTransitions?.length ?? 0);
  const successfulBroadcastReceiptTxHashes = successfulReceiptTxHashesFromProofArtifact(proofArtifact);
  const initializeReceiptMatch = successfulReceiptMatchesForFunction(proofArtifact, "initialize(");
  const modifyLiquidityReceiptMatch = successfulReceiptMatchesForFunction(proofArtifact, "modifyLiquidity(");
  const swapReceiptMatch = successfulReceiptMatchesForFunction(proofArtifact, "swap(");
  const flowMemoryTxHashes = flowMemorySignalTxHashes(flowMemoryArtifact);
  const successfulBroadcastReceiptTxHashSet = new Set(successfulBroadcastReceiptTxHashes);
  const flowMemoryTxHashesMissingFromBroadcastReceipts =
    flowMemoryTxHashes.filter((txHash) => !successfulBroadcastReceiptTxHashSet.has(txHash));
  const readbackRange = readbackRangeArtifact?.range ?? null;
  const readbackRangeSource = readbackRange?.source ?? null;
  const readbackIndexer = readbackArtifact?.indexer ?? null;
  const rangeFromBlock = normalizeOptionalBlock(readbackRange?.fromBlock);
  const rangeToBlock = normalizeOptionalBlock(readbackRange?.toBlock);
  const rangeFinalizedBlock = normalizeOptionalBlock(readbackRange?.finalizedBlock);
  const readbackFromBlockValue = normalizeOptionalBlock(readbackIndexer?.fromBlock);
  const readbackToBlockValue = normalizeOptionalBlock(readbackIndexer?.toBlock);
  const readbackFinalizedBlockValue = normalizeOptionalBlock(readbackIndexer?.finalizedBlock);
  const readbackRangeMatchesReadbackArtifact =
    readbackRangeArtifact?.mode === "readback-range-plan"
    && readbackArtifact?.mode === "readback"
    && sameHook(readbackRangeArtifact?.hook, plan)
    && sameHook(readbackArtifact?.hook, plan)
    && Boolean(rangeFromBlock)
    && Boolean(rangeToBlock)
    && rangeFromBlock === readbackFromBlockValue
    && rangeToBlock === readbackToBlockValue
    && rangeFinalizedBlock === readbackFinalizedBlockValue
    && readbackIndexer?.rangeSource === readbackRangeSource;
  const acceptedReadbackRangeSource =
    readbackRangeSource === "operator-explicit" || readbackRangeSource === "broadcast-proof-artifact-receipts";

  const checks = [
    acceptanceCheck(
      "env.broadcastReady",
      envArtifact?.broadcastReady === true,
      {
        artifact: envCheckArtifactPath,
        broadcastReady: envArtifact?.broadcastReady ?? null,
        chainIdOk: envArtifact?.rpc?.chainIdOk ?? null,
        keyPresent: envArtifact?.deployer?.keyPresent ?? null,
        appearsFundedForSwapProofEstimate:
          envArtifact?.deployer?.balance?.appearsFundedForSwapProofEstimate ?? null,
      },
      "Run npm run hook:base-sepolia:env-check -- --json with a Base Sepolia RPC URL and funded testnet deployer key.",
    ),
    acceptanceCheck(
      "liveCode.officialUniswapContracts",
      evidenceArtifact.evidence.officialContractsCodePresent === true,
      {
        artifact: planOut,
        officialContractsCodePresent: evidenceArtifact.evidence.officialContractsCodePresent,
      },
      "Run npm run hook:base-sepolia:check -- --json and verify the official Base Sepolia v4 addresses still have code.",
    ),
    acceptanceCheck(
      "liveCode.plannedHookDeployed",
      evidenceArtifact.evidence.plannedHookCodePresent === true,
      {
        hookAddress: plan.hook.hookAddress,
        plannedHookCodePresent: evidenceArtifact.evidence.plannedHookCodePresent,
      },
      "Broadcast the hook/swap proof so FlowMemoryAfterSwapHook has code at the mined address.",
    ),
    acceptanceCheck(
      "liveCode.plannedHookRuntimeMatchesArtifact",
      evidenceArtifact.evidence.plannedHookRuntimeBytecodeMatches === true,
      {
        hookAddress: plan.hook.hookAddress,
        runtimeCodeHash: evidenceArtifact.evidence.plannedHookRuntimeCodeHash ?? null,
        expectedRuntimeCodeHash: evidenceArtifact.evidence.expectedHookRuntimeCodeHash ?? null,
        expectedRuntimeArtifact: plan.hook.expectedRuntime?.artifact ?? null,
        expectedRuntimeByteLength: plan.hook.expectedRuntime?.runtimeByteLength ?? null,
        immutableConstructorArgs: plan.hook.expectedRuntime?.immutableConstructorArgs ?? null,
      },
      "Verify the deployed mined hook runtime bytecode hash matches the locally compiled FlowMemoryAfterSwapHook artifact with the Base Sepolia PoolManager immutable.",
    ),
    acceptanceCheck(
      "broadcast.swapProofArtifact",
      proofArtifact?.mode === "swap-proof-broadcast"
        && proofArtifact?.forge?.broadcast === true
        && proofArtifact?.forge?.status === 0
        && positiveInteger(proofArtifact?.foundryRun?.receiptCount)
        && proofMatchesPlan(proofArtifact?.proof, plan),
      {
        artifact: proofArtifactPath,
        mode: proofArtifact?.mode ?? null,
        broadcast: proofArtifact?.forge?.broadcast ?? null,
        forgeStatus: proofArtifact?.forge?.status ?? null,
        receiptCount: proofArtifact?.foundryRun?.receiptCount ?? null,
        proofMatchesPlan: proofMatchesPlan(proofArtifact?.proof, plan),
      },
      "Run npm run hook:base-sepolia:swap-proof:broadcast -- --json with the funded testnet key.",
    ),
    acceptanceCheck(
      "broadcast.poolManagerSwapIncluded",
      hasTransactionFunction(proofArtifact, "initialize(")
        && hasTransactionFunction(proofArtifact, "modifyLiquidity(")
        && hasTransactionFunction(proofArtifact, "swap("),
      {
        hasInitialize: hasTransactionFunction(proofArtifact, "initialize("),
        hasModifyLiquidity: hasTransactionFunction(proofArtifact, "modifyLiquidity("),
        hasSwap: hasTransactionFunction(proofArtifact, "swap("),
      },
      "Use the full swap-proof script so the proof includes pool initialization, liquidity, and a swap.",
    ),
    acceptanceCheck(
      "broadcast.poolManagerActionsSucceeded",
      initializeReceiptMatch.allTransactionsSucceeded
        && modifyLiquidityReceiptMatch.allTransactionsSucceeded
        && swapReceiptMatch.allTransactionsSucceeded,
      {
        initialize: initializeReceiptMatch,
        modifyLiquidity: modifyLiquidityReceiptMatch,
        swap: swapReceiptMatch,
      },
      "Regenerate the broadcast swap-proof artifact and confirm the initialize, modifyLiquidity, and swap transactions all have successful receipts.",
    ),
    acceptanceCheck(
      "readback.rangeSelected",
      readbackRangeArtifact?.mode === "readback-range-plan"
        && acceptedReadbackRangeSource
        && Boolean(readbackRange?.fromBlock)
        && Boolean(readbackRange?.toBlock),
      {
        artifact: readbackRangeArtifactPath,
        mode: readbackRangeArtifact?.mode ?? null,
        source: readbackRangeSource,
        fromBlock: readbackRange?.fromBlock ?? null,
        toBlock: readbackRange?.toBlock ?? null,
        finalizedBlock: readbackRange?.finalizedBlock ?? null,
      },
      "Run npm run hook:base-sepolia:readback-range -- --infer-readback-range --json or record an operator-reviewed explicit range.",
    ),
    acceptanceCheck(
      "readback.rangeMatchesReadbackArtifact",
      readbackRangeMatchesReadbackArtifact,
      {
        rangeArtifact: readbackRangeArtifactPath,
        readbackArtifact: readbackArtifactPath,
        rangeMode: readbackRangeArtifact?.mode ?? null,
        readbackMode: readbackArtifact?.mode ?? null,
        rangeHookMatchesPlan: sameHook(readbackRangeArtifact?.hook, plan),
        readbackHookMatchesPlan: sameHook(readbackArtifact?.hook, plan),
        rangeSource: readbackRangeSource,
        readbackRangeSource: readbackIndexer?.rangeSource ?? null,
        rangeFromBlock,
        readbackFromBlock: readbackFromBlockValue,
        rangeToBlock,
        readbackToBlock: readbackToBlockValue,
        rangeFinalizedBlock,
        readbackFinalizedBlock: readbackFinalizedBlockValue,
      },
      "Regenerate readback from the selected range artifact so the accepted range and readback artifact describe the same block window.",
    ),
    acceptanceCheck(
      "readback.flowPulseObserved",
      readbackArtifact?.mode === "readback"
        && readbackArtifact?.proofComplete === true
        && readbackObservationCount > 0
        && readbackArtifact?.indexer?.hasIntegrityWarnings === false
        && sameHook(readbackArtifact?.hook, plan),
      {
        artifact: readbackArtifactPath,
        mode: readbackArtifact?.mode ?? null,
        proofComplete: readbackArtifact?.proofComplete ?? null,
        observationCount: readbackObservationCount,
        hasIntegrityWarnings: readbackArtifact?.indexer?.hasIntegrityWarnings ?? null,
        hookMatchesPlan: sameHook(readbackArtifact?.hook, plan),
      },
      "Run npm run hook:base-sepolia:readback:auto -- --json or read back the operator-reviewed block range.",
    ),
    acceptanceCheck(
      "evidence.liveProofComplete",
      evidenceArtifact.liveProofComplete === true,
      {
        artifact: evidenceArtifactPath,
        stage: evidenceArtifact.stage,
        liveProofComplete: evidenceArtifact.liveProofComplete,
        missing: evidenceArtifact.missing,
      },
      "Rerun npm run hook:base-sepolia:evidence -- --json after broadcast and non-empty readback.",
    ),
    acceptanceCheck(
      "flowmemory.liveObjectsGenerated",
      flowMemoryArtifact?.liveProofComplete === true
        && flowMemoryArtifact?.acceptance?.livePoolManagerSwapObserved === true
        && memorySignalCount > 0
        && memoryReceiptCount > 0
        && rootflowTransitionCount > 0,
      {
        artifact: flowMemoryArtifactPath,
        liveProofComplete: flowMemoryArtifact?.liveProofComplete ?? null,
        livePoolManagerSwapObserved: flowMemoryArtifact?.acceptance?.livePoolManagerSwapObserved ?? null,
        memorySignals: memorySignalCount,
        memoryReceipts: memoryReceiptCount,
        rootflowTransitions: rootflowTransitionCount,
        dashboardFixtureGenerated: flowMemoryArtifact?.acceptance?.dashboardFixtureGenerated ?? null,
      },
      "Run npm run hook:base-sepolia:flowmemory without --allow-incomplete after live proof is complete.",
    ),
    acceptanceCheck(
      "flowmemory.observationIntegrity",
      flowMemoryObservationCount > 0
        && flowMemoryChecks.planEvidenceHookMatch === true
        && flowMemoryChecks.planReadbackHookMatch === true
        && flowMemoryChecks.checkpointIncludesHookAddress === true
        && flowMemoryChecks.allObservationsFromHook === true
        && flowMemoryChecks.allObservationsBaseSepolia === true
        && flowMemoryChecks.allObservationsFlowPulse === true
        && flowMemoryChecks.allObservationsReceiptSuccess === true,
      {
        observationCount: flowMemoryObservationCount,
        planEvidenceHookMatch: flowMemoryChecks.planEvidenceHookMatch ?? null,
        planReadbackHookMatch: flowMemoryChecks.planReadbackHookMatch ?? null,
        checkpointIncludesHookAddress: flowMemoryChecks.checkpointIncludesHookAddress ?? null,
        allObservationsFromHook: flowMemoryChecks.allObservationsFromHook ?? null,
        allObservationsBaseSepolia: flowMemoryChecks.allObservationsBaseSepolia ?? null,
        allObservationsFlowPulse: flowMemoryChecks.allObservationsFlowPulse ?? null,
        allObservationsReceiptSuccess: flowMemoryChecks.allObservationsReceiptSuccess ?? null,
      },
      "Regenerate Flow Memory evidence from the live readback; every observation must be a successful FlowPulse from the planned Base Sepolia hook.",
    ),
    acceptanceCheck(
      "flowmemory.swapSignalEvidence",
      canonicalObservationCount > 0
        && swapMemorySignalObservationCount > 0
        && memorySignalCount >= swapMemorySignalObservationCount
        && memoryReceiptCount >= swapMemorySignalObservationCount
        && rootflowTransitionCount >= swapMemorySignalObservationCount,
      {
        canonicalObservationCount,
        swapMemorySignalObservationCount,
        memorySignals: memorySignalCount,
        memoryReceipts: memoryReceiptCount,
        rootflowTransitions: rootflowTransitionCount,
      },
      "Run a real PoolManager swap that emits at least one unique successful SWAP_MEMORY_SIGNAL and regenerate Flow Memory evidence.",
    ),
    acceptanceCheck(
      "flowmemory.signalsLinkedToBroadcastReceipts",
      successfulBroadcastReceiptTxHashes.length > 0
        && flowMemoryTxHashes.length > 0
        && flowMemoryTxHashesMissingFromBroadcastReceipts.length === 0,
      {
        successfulBroadcastReceiptTxHashCount: successfulBroadcastReceiptTxHashes.length,
        flowMemorySignalTxHashCount: flowMemoryTxHashes.length,
        matchedFlowMemorySignalTxHashCount:
          flowMemoryTxHashes.length - flowMemoryTxHashesMissingFromBroadcastReceipts.length,
        missingFlowMemorySignalTxHashes: flowMemoryTxHashesMissingFromBroadcastReceipts,
      },
      "Regenerate Flow Memory evidence from the same successful broadcast receipt transactions that produced the accepted readback.",
    ),
    acceptanceCheck(
      "flowmemory.countsAgree",
      readbackObservationCount > 0
        && flowMemoryObservationCount === readbackObservationCount
        && evidenceArtifact.evidence.readbackObservationCount === readbackObservationCount,
      {
        readbackObservationCount,
        flowMemoryObservationCount,
        evidenceReadbackObservationCount: evidenceArtifact.evidence.readbackObservationCount,
      },
      "Regenerate evidence, readback, and Flow Memory artifacts from the same live block range.",
    ),
  ];

  const failedChecks = checks.filter((check) => !check.ok).map((check) => check.name);
  const liveProofAccepted = failedChecks.length === 0;

  return {
    schema: "flowmemory.base_sepolia.v4_hook_acceptance.v0",
    generatedAt,
    mode: "acceptance-package",
    productionReady: false,
    liveProofAccepted,
    allowIncomplete: allowIncompleteAcceptance,
    stage: liveProofAccepted ? "live-proof-accepted" : evidenceArtifact.stage,
    planPath: planOut,
    sourcePaths: {
      envCheck: envCheckArtifactPath,
      evidence: evidenceArtifactPath,
      proof: proofArtifactPath,
      readbackRange: readbackRangeArtifactPath,
      readback: readbackArtifactPath,
      flowMemory: flowMemoryArtifactPath,
    },
    hook: plan.hook,
    network: plan.network,
    checks,
    failedChecks,
    counts: {
      readbackObservations: readbackObservationCount,
      flowMemoryObservations: flowMemoryObservationCount,
      canonicalObservations: canonicalObservationCount,
      swapMemorySignalObservations: swapMemorySignalObservationCount,
      memorySignals: memorySignalCount,
      memoryReceipts: memoryReceiptCount,
      rootflowTransitions: rootflowTransitionCount,
      successfulBroadcastReceiptTxHashes: successfulBroadcastReceiptTxHashes.length,
      flowMemorySignalTxHashes: flowMemoryTxHashes.length,
    },
    launchLanguage: liveProofAccepted
      ? {
        allowed:
          "FlowMemory completed a Base Sepolia public-testnet proof: a real Uniswap v4 PoolManager swap called the mined afterSwap-only hook, emitted FlowPulse, and generated Flow Memory / Rootflow evidence from readback.",
        blocked:
          "This remains public-testnet evidence only; do not claim production mainnet readiness, production L1 readiness, audited cryptography, free storage, or AI running on-chain.",
      }
      : {
        allowed:
          "FlowMemory has local/test V0 coverage and a dry-run-ready Base Sepolia Uniswap v4 hook proof path.",
        blocked:
          "Do not claim the real Base Sepolia PoolManager hook proof is live until this acceptance package has liveProofAccepted: true.",
      },
    nextSteps: liveProofAccepted
      ? [
        "Record the acceptance artifact path in the deployment note.",
        "Keep launch language scoped to public-testnet proof evidence.",
      ]
      : [
        "Run npm run hook:base-sepolia:env-check -- --json until broadcastReady is true.",
        "Run npm run hook:base-sepolia:swap-proof:broadcast -- --json.",
        "Run npm run hook:base-sepolia:readback-range -- --infer-readback-range --json.",
        "Run npm run hook:base-sepolia:readback:auto -- --json.",
        "Run npm run hook:base-sepolia:flowmemory.",
        "Rerun npm run hook:base-sepolia:acceptance -- --json.",
      ],
    boundaries: [
      ...plan.boundaries,
      "Acceptance requires all source artifacts to agree; diagnostic artifacts generated with --allow-incomplete are not acceptance evidence.",
    ],
  };
}

function acceptanceCheckByName(artifact, name) {
  return Array.isArray(artifact?.checks)
    ? artifact.checks.find((check) => check.name === name) ?? null
    : null;
}

function readArtifactFromAcceptanceSource(acceptance, sourceName, fallbackPath) {
  return readJsonIfExists(acceptance?.sourcePaths?.[sourceName] ?? fallbackPath);
}

function runDeploymentNote(plan) {
  const acceptanceArtifact = readJsonIfExists(acceptanceArtifactPath);
  const failedChecks = Array.isArray(acceptanceArtifact?.failedChecks) ? acceptanceArtifact.failedChecks : [];
  const allChecksOk =
    Array.isArray(acceptanceArtifact?.checks)
    && acceptanceArtifact.checks.length > 0
    && acceptanceArtifact.checks.every((check) => check.ok === true);
  const liveProofAccepted = acceptanceArtifact?.liveProofAccepted === true && failedChecks.length === 0 && allChecksOk;
  const envArtifact = readArtifactFromAcceptanceSource(acceptanceArtifact, "envCheck", envCheckArtifactPath);
  const proofArtifact = readArtifactFromAcceptanceSource(acceptanceArtifact, "proof", proofArtifactPath);
  const readbackArtifact = readArtifactFromAcceptanceSource(acceptanceArtifact, "readback", readbackArtifactPath);
  const flowMemoryArtifact = readArtifactFromAcceptanceSource(acceptanceArtifact, "flowMemory", flowMemoryArtifactPath);
  const runtimeCheck = acceptanceCheckByName(acceptanceArtifact, "liveCode.plannedHookRuntimeMatchesArtifact");
  const actionCheck = acceptanceCheckByName(acceptanceArtifact, "broadcast.poolManagerActionsSucceeded");
  const rangeCheck = acceptanceCheckByName(acceptanceArtifact, "readback.rangeSelected");
  const rangeMatchCheck = acceptanceCheckByName(acceptanceArtifact, "readback.rangeMatchesReadbackArtifact");
  const readbackCheck = acceptanceCheckByName(acceptanceArtifact, "readback.flowPulseObserved");
  const signalLinkCheck = acceptanceCheckByName(acceptanceArtifact, "flowmemory.signalsLinkedToBroadcastReceipts");

  return {
    schema: "flowmemory.base_sepolia.v4_hook_deployment_note.v0",
    generatedAt,
    mode: "deployment-note",
    productionReady: false,
    liveProofAccepted,
    allowIncomplete: allowIncompleteAcceptance,
    stage: acceptanceArtifact?.stage ?? "missing-acceptance-artifact",
    sourcePaths: {
      acceptance: acceptanceArtifactPath,
      envCheck: acceptanceArtifact?.sourcePaths?.envCheck ?? envCheckArtifactPath,
      evidence: acceptanceArtifact?.sourcePaths?.evidence ?? evidenceArtifactPath,
      proof: acceptanceArtifact?.sourcePaths?.proof ?? proofArtifactPath,
      readbackRange: acceptanceArtifact?.sourcePaths?.readbackRange ?? readbackRangeArtifactPath,
      readback: acceptanceArtifact?.sourcePaths?.readback ?? readbackArtifactPath,
      flowMemory: acceptanceArtifact?.sourcePaths?.flowMemory ?? flowMemoryArtifactPath,
    },
    hook: acceptanceArtifact?.hook ?? plan.hook,
    network: acceptanceArtifact?.network ?? plan.network,
    operator: {
      fundedTestnetDeployerAddress: envArtifact?.deployer?.address ?? null,
      envBroadcastReady: envArtifact?.broadcastReady ?? null,
      keyMaterialStoredInArtifact: false,
    },
    hookDeployment: {
      hookAddress: acceptanceArtifact?.hook?.hookAddress ?? plan.hook.hookAddress,
      runtimeCodeHash: runtimeCheck?.evidence?.runtimeCodeHash ?? null,
      expectedRuntimeCodeHash:
        runtimeCheck?.evidence?.expectedRuntimeCodeHash ?? plan.hook.expectedRuntime?.runtimeBytecodeHash ?? null,
      runtimeBytecodeMatchesArtifact: runtimeCheck?.ok === true,
      expectedRuntimeArtifact: runtimeCheck?.evidence?.expectedRuntimeArtifact ?? plan.hook.expectedRuntime?.artifact ?? null,
      deploymentTransactions: Array.isArray(proofArtifact?.foundryRun?.transactions)
        ? proofArtifact.foundryRun.transactions
          .filter((tx) => tx.contractName === "FlowMemoryAfterSwapHook")
          .map((tx) => ({
            hash: tx.hash ?? null,
            transactionType: tx.transactionType ?? null,
            contractAddress: tx.contractAddress ?? null,
          }))
        : [],
    },
    poolManagerProof: {
      artifactMode: proofArtifact?.mode ?? null,
      broadcast: proofArtifact?.forge?.broadcast ?? null,
      receiptCount: proofArtifact?.foundryRun?.receiptCount ?? null,
      initialize: actionCheck?.evidence?.initialize ?? null,
      modifyLiquidity: actionCheck?.evidence?.modifyLiquidity ?? null,
      swap: actionCheck?.evidence?.swap ?? null,
      actionsSucceeded: actionCheck?.ok === true,
    },
    readback: {
      range: rangeCheck?.evidence ?? null,
      rangeMatchesReadbackArtifact: rangeMatchCheck?.ok === true,
      observationCount: readbackCheck?.evidence?.observationCount ?? readbackArtifact?.indexer?.observationCount ?? 0,
      proofComplete: readbackCheck?.evidence?.proofComplete ?? readbackArtifact?.proofComplete ?? null,
      flowPulseObserved: readbackCheck?.ok === true,
      statePath: readbackArtifact?.indexer?.statePath ?? null,
      checkpointPath: readbackArtifact?.indexer?.checkpointPath ?? null,
    },
    flowMemory: {
      counts: acceptanceArtifact?.counts ?? null,
      signalTxHashLinkage: signalLinkCheck?.evidence ?? null,
      signalTxHashesLinkedToBroadcastReceipts: signalLinkCheck?.ok === true,
      dashboardFixtureGenerated: flowMemoryArtifact?.acceptance?.dashboardFixtureGenerated ?? null,
      dashboardRuntimePath: flowMemoryArtifact?.sourcePaths?.dashboardRuntime ?? null,
      dashboardFixturePath: flowMemoryArtifact?.sourcePaths?.dashboard ?? null,
    },
    claimLanguage: liveProofAccepted
      ? {
        allowed:
          acceptanceArtifact.launchLanguage?.allowed
          ?? "FlowMemory completed a Base Sepolia public-testnet hook proof and generated Flow Memory evidence from readback.",
        blocked:
          acceptanceArtifact.launchLanguage?.blocked
          ?? "Do not claim production mainnet readiness, production L1 readiness, audited cryptography, free storage, or AI running on-chain.",
      }
      : {
        allowed:
          acceptanceArtifact?.launchLanguage?.allowed
          ?? "FlowMemory has local/test V0 coverage and a dry-run-ready Base Sepolia Uniswap v4 hook proof path.",
        blocked:
          acceptanceArtifact?.launchLanguage?.blocked
          ?? "Do not claim the real Base Sepolia PoolManager hook proof is live until the acceptance package has liveProofAccepted: true.",
      },
    failedChecks,
    nextSteps: liveProofAccepted
      ? [
        "Record this deployment note with the dated Base Sepolia proof artifacts.",
        "Keep public language scoped to public-testnet proof evidence.",
      ]
      : acceptanceArtifact?.nextSteps ?? [
        "Run npm run hook:base-sepolia:acceptance -- --json after the live broadcast, readback, and Flow Memory generation are complete.",
      ],
    blockedClaims: [
      "production mainnet readiness",
      "production L1 readiness",
      "audited cryptography",
      "free storage",
      "AI running on-chain",
      "trustless verifier network",
      "production Uniswap v4 hook deployment",
    ],
    boundaries: [
      ...(plan.boundaries ?? []),
      "This deployment note is non-secret and must not contain private keys, RPC URLs, explorer API keys, seed phrases, or raw signed transactions.",
      "A deployment note generated with --allow-incomplete is diagnostic only and is not live proof evidence.",
    ],
  };
}

function mineOrComputeHookPlan(initCodeHash) {
  if (explicitSalt) {
    assertHex32(explicitSalt, "FLOWMEMORY_HOOK_SALT");
    const address = runCapture("cast", [
      "create2",
      "--deployer",
      CREATE2_DEPLOYER,
      "--salt",
      explicitSalt,
      "--init-code-hash",
      initCodeHash,
    ]);
    return {
      salt: explicitSalt,
      hookAddress: address.trim(),
      miningMode: operatorSalt ? "explicit-salt" : "mined-after-swap-suffix-0040",
    };
  }

  const output = runCapture("cast", [
    "create2",
    "--deployer",
    CREATE2_DEPLOYER,
    "--init-code-hash",
    initCodeHash,
    "--ends-with",
    "0040",
    "--no-random",
    "--threads",
    "0",
  ]);
  const addressMatch = output.match(/Address:\s*(0x[0-9a-fA-F]{40})/);
  const saltMatch = output.match(/Salt:\s*(0x[0-9a-fA-F]{64})/);
  if (!addressMatch || !saltMatch) {
    throw new Error(`could not parse cast create2 output:\n${output}`);
  }
  return { salt: saltMatch[1], hookAddress: addressMatch[1], miningMode: "mined-after-swap-suffix-0040" };
}

function hasAfterSwapOnlyFlag(address) {
  return (BigInt(address) & 0x3fffn) === 0x40n;
}

function liveCodeCheck(addresses, expectedRuntimeHashes = {}) {
  const checks = [];
  const errors = [];
  let chainId = null;
  try {
    chainId = runCapture("cast", ["chain-id", "--rpc-url", rpcUrl]);
  } catch (error) {
    errors.push(error.message);
  }

  for (const [name, address] of Object.entries(addresses)) {
    try {
      const code = runCapture("cast", ["code", address, "--rpc-url", rpcUrl]);
      const expectedRuntimeBytecodeHash = expectedRuntimeHashes[name] ?? null;
      const codeHash =
        code !== "0x" && expectedRuntimeBytecodeHash ? runCapture("cast", ["keccak", code]) : null;
      checks.push({
        name,
        address,
        codePresent: code !== "0x",
        byteLength: code === "0x" ? 0 : (code.length - 2) / 2,
        codeHash,
        expectedRuntimeBytecodeHash,
        runtimeBytecodeHashMatches: expectedRuntimeBytecodeHash ? codeHash === expectedRuntimeBytecodeHash : null,
      });
    } catch (error) {
      checks.push({
        name,
        address,
        codePresent: false,
        byteLength: 0,
        codeHash: null,
        expectedRuntimeBytecodeHash: expectedRuntimeHashes[name] ?? null,
        runtimeBytecodeHashMatches: false,
        error: error.message,
      });
      errors.push(error.message);
    }
  }

  return {
    rpc: rpcUrl === DEFAULT_PUBLIC_RPC_URL ? "default-public-base-sepolia" : "<operator-provided>",
    chainId,
    chainIdOk: chainId === BASE_SEPOLIA_CHAIN_ID,
    checks,
    errors,
  };
}

function buildPlan() {
  const initCode = buildInitCode();
  const initCodeHash = runCapture("cast", ["keccak", initCode]);
  const expectedRuntime = buildExpectedHookRuntimeIdentity();
  const hookPlan = mineOrComputeHookPlan(initCodeHash);
  if (!hasAfterSwapOnlyFlag(hookPlan.hookAddress)) {
    throw new Error(`mined hook address does not have afterSwap-only low bits: ${hookPlan.hookAddress}`);
  }

  const addressesToCheck = {
    create2Deployer: CREATE2_DEPLOYER,
    ...UNISWAP_BASE_SEPOLIA,
    plannedFlowMemoryAfterSwapHook: hookPlan.hookAddress,
  };
  const basePlan = {
    schema: "flowmemory.base_sepolia.v4_hook_proof_plan.v0",
    generatedAt,
    mode: planOnly
      ? "plan-only"
      : envCheck
        ? "env-check"
        : evidenceCheck
          ? "evidence"
        : deploymentNote
          ? "deployment-note"
        : acceptancePackage
          ? "acceptance-package"
        : liveCheck
        ? "live-check"
        : readbackRangePlan
          ? "readback-range-plan"
        : readback
          ? "readback"
          : swapProof
            ? broadcast
              ? "swap-proof-broadcast"
              : "swap-proof-dry-run"
            : broadcast
              ? "broadcast"
              : "dry-run",
    productionReady: false,
    network: {
      name: "Base Sepolia",
      chainId: BASE_SEPOLIA_CHAIN_ID,
      explorer: "https://sepolia.basescan.org",
    },
    environment: redactedEnv(),
    uniswapV4: {
      source: "https://developers.uniswap.org/docs/protocols/v4/deployments",
      baseSepolia: UNISWAP_BASE_SEPOLIA,
    },
    hook: {
      contract: "FlowMemoryAfterSwapHook",
      create2Deployer: CREATE2_DEPLOYER,
      constructorArgs: {
        poolManager: UNISWAP_BASE_SEPOLIA.poolManager,
      },
      initCodeHash,
      expectedRuntime,
      salt: hookPlan.salt,
      hookAddress: hookPlan.hookAddress,
      miningMode: hookPlan.miningMode,
      requiredLowBits: "0x0040",
      hasAfterSwapOnlyFlag: true,
      permissions: {
        afterSwap: true,
        beforeSwap: false,
        afterSwapReturnDelta: false,
        dynamicFeeOverride: false,
        custody: false,
      },
    },
    commands: {
      plan: "npm run hook:base-sepolia:plan -- --json",
      envCheck: "npm run hook:base-sepolia:env-check -- --json",
      evidence: "npm run hook:base-sepolia:evidence -- --json",
      requireLiveProof: "npm run hook:base-sepolia:require-live-proof -- --json",
      acceptance:
        "npm run hook:base-sepolia:acceptance -- --json",
      acceptanceDiagnostic:
        "npm run hook:base-sepolia:acceptance -- --allow-incomplete --json",
      deploymentNote:
        "npm run hook:base-sepolia:deployment-note -- --json",
      deploymentNoteDiagnostic:
        "npm run hook:base-sepolia:deployment-note -- --allow-incomplete --json",
      liveCheck: "npm run hook:base-sepolia:check -- --json",
      dryRun:
        "npm run hook:base-sepolia:dry-run -- --json",
      broadcast:
        "npm run hook:base-sepolia:broadcast -- --json",
      swapProofDryRun:
        "npm run hook:base-sepolia:swap-proof:dry-run -- --json",
      swapProofBroadcast:
        "npm run hook:base-sepolia:swap-proof:broadcast -- --json",
      readback:
        "npm run hook:base-sepolia:readback -- --rpc-url $BASE_SEPOLIA_RPC_URL --from-block <deployBlock> --to-block <latestBlock> --finalized-block <safeFinalizedBlock> --json",
      readbackAuto:
        "npm run hook:base-sepolia:readback:auto -- --json",
      readbackRangePlan:
        "npm run hook:base-sepolia:readback-range -- --infer-readback-range --json",
      readFlowPulse:
        "npm run index:base-sepolia -- --rpc-url $BASE_SEPOLIA_RPC_URL --address <FlowMemoryAfterSwapHook> --from-block <deployBlock> --to-block <latestBlock> --finalized-block <safeFinalizedBlock>",
    },
    proofSequence: [
      "Confirm live Base Sepolia Uniswap v4 contract code exists.",
      "Deploy FlowMemoryAfterSwapHook through the standard CREATE2 deployer with the mined salt.",
      "Verify the deployed hook address has afterSwap-only low bits.",
      "Verify the deployed hook runtime bytecode hash matches the compiled FlowMemoryAfterSwapHook artifact with the Base Sepolia PoolManager immutable.",
      "Run the swap-proof script or manually initialize a Base Sepolia test pool whose PoolKey.hooks is the deployed FlowMemoryAfterSwapHook.",
      "Add tiny test liquidity using throwaway testnet proof tokens or reviewed testnet currencies.",
      "Execute one tiny swap through PoolSwapTest or a reviewed router path with FlowMemory hookData.",
      "Read the emitted FlowPulse from the hook with the Base Sepolia indexer.",
      "Generate Flow Memory / Rootflow state and dashboard evidence from the live observation.",
    ],
    swapProofScript: {
      script: "script/RunBaseSepoliaV4HookSwapProof.s.sol:RunBaseSepoliaV4HookSwapProof",
      operatorEnv: "FLOWMEMORY_HOOK_PROOF_OPERATOR",
      defaultTokenMint: "1000e18 per throwaway proof token",
      defaultLiquidityDelta: "1e18",
      defaultSwapAmount: "0.01e18 exact input",
      outputEvent: "FlowMemoryBaseSepoliaV4HookSwapProof",
      note:
        "This is a public-testnet proof script. It deploys throwaway proof tokens and performs a tiny v4 PoolManager swap that should emit FlowPulse from the hook.",
    },
    poolAndSwapTemplates: {
      initializePool:
        "cast send 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408 \"initialize((address,address,uint24,int24,address),uint160)\" \"(<currency0>,<currency1>,3000,60,<FlowMemoryAfterSwapHook>)\" 79228162514264337593543950336 --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $BASE_SEPOLIA_DEPLOYER_KEY_HEX",
      modifyLiquidity:
        "cast send 0x37429cd17cb1454c34e7f50b09725202fd533039 \"modifyLiquidity((address,address,uint24,int24,address),(int24,int24,int256,bytes32),bytes)\" \"(<currency0>,<currency1>,3000,60,<FlowMemoryAfterSwapHook>)\" \"(-600,600,<liquidityDelta>,0x00...)\" <hookData> --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $BASE_SEPOLIA_DEPLOYER_KEY_HEX",
      swap:
        "cast send 0x8B5bcC363ddE2614281aD875bad385E0A785D3B9 \"swap((address,address,uint24,int24,address),(bool,int256,uint160),(bool,bool),bytes)\" \"(<currency0>,<currency1>,3000,60,<FlowMemoryAfterSwapHook>)\" \"(true,<negativeExactInput>,<sqrtPriceLimitX96>)\" \"(false,false)\" <FlowMemoryHookData> --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $BASE_SEPOLIA_DEPLOYER_KEY_HEX",
    },
    boundaries: [
      "Base Sepolia proof is public testnet evidence, not production mainnet readiness.",
      "A deployed hook alone is not enough; the acceptance proof requires a PoolManager swap that emits FlowPulse.",
      "txHash and logIndex are read by the indexer after receipts/logs exist; the hook never claims them.",
      "No private keys, RPC credentials, or explorer API keys are written to this artifact.",
      "Use tiny testnet-only currencies and liquidity for this proof.",
    ],
  };

  if (liveCheck || evidenceCheck || !planOnly) {
    return {
      ...basePlan,
      liveCheck: liveCodeCheck(addressesToCheck, {
        plannedFlowMemoryAfterSwapHook: expectedRuntime.runtimeBytecodeHash,
      }),
    };
  }
  return basePlan;
}

const plan = buildPlan();
writeJson(planOut, plan);

if (envCheck) {
  const artifact = runEnvCheck(plan);
  writeJson(artifactOut, artifact);
  if (json) {
    console.log(JSON.stringify({ ok: true, artifactOut, artifact }, null, 2));
  } else {
    console.log(`Base Sepolia v4 hook env-check artifact written: ${artifactOut}`);
  }
  process.exit(0);
}

if (evidenceCheck) {
  const artifact = runEvidenceCheck(plan);
  writeJson(artifactOut, artifact);
  if (json) {
    console.log(JSON.stringify({ ok: artifact.liveProofComplete || !requireLiveProof, artifactOut, artifact }, null, 2));
  } else {
    console.log(`Base Sepolia v4 hook evidence artifact written: ${artifactOut}`);
  }
  if (requireLiveProof && !artifact.liveProofComplete) {
    process.exit(1);
  }
  process.exit(0);
}

if (acceptancePackage) {
  const artifact = runAcceptancePackage(plan);
  writeJson(artifactOut, artifact);
  if (json) {
    console.log(JSON.stringify({ ok: artifact.liveProofAccepted || allowIncompleteAcceptance, artifactOut, artifact }, null, 2));
  } else {
    console.log(`Base Sepolia v4 hook acceptance package written: ${artifactOut}`);
  }
  if (!allowIncompleteAcceptance && !artifact.liveProofAccepted) {
    process.exit(1);
  }
  process.exit(0);
}

if (deploymentNote) {
  const artifact = runDeploymentNote(plan);
  writeJson(artifactOut, artifact);
  if (json) {
    console.log(JSON.stringify({ ok: artifact.liveProofAccepted || allowIncompleteAcceptance, artifactOut, artifact }, null, 2));
  } else {
    console.log(`Base Sepolia v4 hook deployment note written: ${artifactOut}`);
  }
  if (!allowIncompleteAcceptance && !artifact.liveProofAccepted) {
    process.exit(1);
  }
  process.exit(0);
}

if (readbackRangePlan) {
  const artifact = runReadbackRangePlan(plan);
  writeJson(artifactOut, artifact);
  if (json) {
    console.log(JSON.stringify({ ok: true, artifactOut, artifact }, null, 2));
  } else {
    console.log(`Base Sepolia v4 hook readback range artifact written: ${artifactOut}`);
  }
  process.exit(0);
}

if (readback) {
  const artifact = runReadback(plan);
  writeJson(artifactOut, artifact);
  if (json) {
    console.log(JSON.stringify({ ok: true, artifactOut, artifact }, null, 2));
  } else {
    console.log(`Base Sepolia v4 hook readback artifact written: ${artifactOut}`);
  }
  process.exit(0);
}

if (planOnly || liveCheck) {
  if (json) {
    console.log(JSON.stringify({ ok: true, planOut, plan }, null, 2));
  } else {
    console.log(`Base Sepolia v4 hook proof plan written: ${planOut}`);
  }
  process.exit(0);
}

requirePrivateKeyForForgeRun();

const proofOperator = swapProof ? resolveProofOperator() : null;

const selectedScript = swapProof
  ? "script/RunBaseSepoliaV4HookSwapProof.s.sol:RunBaseSepoliaV4HookSwapProof"
  : "script/DeployFlowMemoryAfterSwapHook.s.sol:DeployFlowMemoryAfterSwapHook";

const forgeArgs = [
  "script",
  selectedScript,
  "--rpc-url",
  rpcUrl,
  "--private-key",
  deployerKey,
  "--chain-id",
  BASE_SEPOLIA_CHAIN_ID,
];

if (broadcast) {
  forgeArgs.push("--broadcast", "--slow");
}

const status = runInherit("forge", forgeArgs, {
  env: {
    ...process.env,
    FLOWMEMORY_HOOK_SALT: plan.hook.salt,
    BASE_SEPOLIA_POOL_MANAGER: UNISWAP_BASE_SEPOLIA.poolManager,
    ...(proofOperator ? { FLOWMEMORY_HOOK_PROOF_OPERATOR: proofOperator } : {}),
  },
});
const foundryRun = summarizeFoundryRun(selectedScript, broadcast);

const artifact = {
  schema: swapProof
    ? "flowmemory.base_sepolia.v4_hook_swap_proof_artifact.v0"
    : "flowmemory.base_sepolia.v4_hook_proof_artifact.v0",
  generatedAt,
  mode: swapProof ? (broadcast ? "swap-proof-broadcast" : "swap-proof-dry-run") : broadcast ? "broadcast" : "dry-run",
  productionReady: false,
  planPath: planOut,
  hook: plan.hook,
  forge: {
    status,
    script: selectedScript,
    broadcast,
  },
  foundryRun,
  ...(foundryRun.proof ? { proof: foundryRun.proof } : {}),
  ...(foundryRun.deployment ? { deployment: foundryRun.deployment } : {}),
  nextSteps: swapProof ? plan.proofSequence.slice(6) : plan.proofSequence.slice(3),
  boundaries: plan.boundaries,
};

writeJson(artifactOut, artifact);

if (json) {
  console.log(JSON.stringify({ ok: true, artifactOut, artifact }, null, 2));
} else {
  console.log(`Base Sepolia v4 hook proof artifact written: ${artifactOut}`);
}
