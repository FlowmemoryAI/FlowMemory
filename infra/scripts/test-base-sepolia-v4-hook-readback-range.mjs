#!/usr/bin/env node
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

const repoRoot = resolve(import.meta.dirname, "../..");
const proofRunner = resolve(repoRoot, "infra/scripts/run-base-sepolia-v4-hook-proof.mjs");
const tempDir = mkdtempSync(join(tmpdir(), "flowmemory-v4-hook-range-"));
const INIT_TX_HASH = `0x${"aa".repeat(32)}`;
const LIQUIDITY_TX_HASH = `0x${"bb".repeat(32)}`;
const SWAP_TX_HASH = `0x${"cc".repeat(32)}`;
const FAILED_TX_HASH = `0x${"dd".repeat(32)}`;

try {
  const planPath = join(tempDir, "plan.json");
  const explicitRangePath = join(tempDir, "explicit-range.json");
  const inferredRangePath = join(tempDir, "inferred-range.json");
  const acceptancePath = join(tempDir, "acceptance.json");
  const dryRunProofPath = join(tempDir, "dry-run-proof.json");
  const broadcastProofPath = join(tempDir, "broadcast-proof.json");
  const matchingReadbackPath = join(tempDir, "matching-readback.json");
  const linkedReadbackPath = join(tempDir, "linked-readback.json");
  const linkedFlowMemoryPath = join(tempDir, "linked-flowmemory.json");
  const diagnosticNotePath = join(tempDir, "diagnostic-note.json");
  const acceptedAcceptancePath = join(tempDir, "accepted-acceptance.json");
  const acceptedNotePath = join(tempDir, "accepted-note.json");

  runOk([
    proofRunner,
    "--plan-only",
    "--plan-out",
    planPath,
    "--json",
  ]);
  const plan = readJson(planPath);
  assert.match(plan.hook.expectedRuntime.runtimeBytecodeHash, /^0x[0-9a-f]{64}$/);
  assert.equal(plan.hook.expectedRuntime.runtimeByteLength > 0, true);
  assert.equal(plan.hook.expectedRuntime.immutableConstructorArgs.poolManager, plan.hook.constructorArgs.poolManager);

  const explicit = runOk([
    proofRunner,
    "--readback-range-plan",
    "--plan-out",
    planPath,
    "--artifact-out",
    explicitRangePath,
    "--from-block",
    "41616089",
    "--to-block",
    "41616090",
    "--json",
  ]);
  assert.equal(explicit.artifact.range.source, "operator-explicit");
  assert.equal(explicit.artifact.range.fromBlock, "41616089");
  assert.equal(explicit.artifact.range.toBlock, "41616090");

  writeJson(dryRunProofPath, proofArtifact(plan, {
    mode: "swap-proof-dry-run",
    broadcast: false,
    receipts: [{ status: "1", blockNumber: "500" }],
  }));
  const dryRunResult = runRaw([
    proofRunner,
    "--readback-range-plan",
    "--infer-readback-range",
    "--plan-out",
    planPath,
    "--proof-artifact",
    dryRunProofPath,
    "--artifact-out",
    inferredRangePath,
    "--json",
  ]);
  assert.notEqual(dryRunResult.status, 0);
  assert.match(`${dryRunResult.stderr}\n${dryRunResult.stdout}`, /non-broadcast proof artifact mode: swap-proof-dry-run/);

  writeJson(broadcastProofPath, proofArtifact(plan, {
    mode: "swap-proof-broadcast",
    broadcast: true,
    receipts: [
      { status: "1", blockNumber: "700", transactionHash: INIT_TX_HASH },
      { status: "0", blockNumber: "701", transactionHash: FAILED_TX_HASH },
      { status: "1", blockNumber: "702", transactionHash: LIQUIDITY_TX_HASH },
      { status: "1", blockNumber: "704", transactionHash: SWAP_TX_HASH },
    ],
    transactions: [
      { hash: INIT_TX_HASH, function: "initialize((address,address,uint24,int24,address),uint160)" },
      {
        hash: LIQUIDITY_TX_HASH,
        function: "modifyLiquidity((address,address,uint24,int24,address),(int24,int24,int256,bytes32),bytes)",
      },
      {
        hash: SWAP_TX_HASH,
        function: "swap((address,address,uint24,int24,address),(bool,int256,uint160),(bool,bool),bytes)",
      },
    ],
  }));
  const inferred = runOk([
    proofRunner,
    "--readback-range-plan",
    "--infer-readback-range",
    "--plan-out",
    planPath,
    "--proof-artifact",
    broadcastProofPath,
    "--artifact-out",
    inferredRangePath,
    "--json",
  ]);
  assert.equal(inferred.artifact.range.source, "broadcast-proof-artifact-receipts");
  assert.equal(inferred.artifact.range.fromBlock, "700");
  assert.equal(inferred.artifact.range.toBlock, "704");
  assert.equal(inferred.artifact.range.finalizedBlock, "704");
  assert.equal(inferred.artifact.range.receiptCount, 4);
  assert.equal(inferred.artifact.range.successfulReceiptBlockCount, 3);

  writeJson(matchingReadbackPath, readbackArtifact(plan, {
    rangeSource: "broadcast-proof-artifact-receipts",
    fromBlock: "700",
    toBlock: "704",
    finalizedBlock: "704",
    observationCount: 0,
  }));
  const diagnosticAcceptance = runOk([
    proofRunner,
    "--acceptance-package",
    "--allow-incomplete",
    "--plan-out",
    planPath,
    "--proof-artifact",
    dryRunProofPath,
    "--readback-range-artifact",
    inferredRangePath,
    "--readback-artifact",
    matchingReadbackPath,
    "--artifact-out",
    acceptancePath,
    "--json",
  ]);
  assert.equal(diagnosticAcceptance.artifact.liveProofAccepted, false);
  assert.equal(
    diagnosticAcceptance.artifact.checks.find((check) => check.name === "readback.rangeMatchesReadbackArtifact")?.ok,
    true,
  );
  assert.ok(diagnosticAcceptance.artifact.failedChecks.includes("broadcast.swapProofArtifact"));
  assert.ok(diagnosticAcceptance.artifact.failedChecks.includes("liveCode.plannedHookRuntimeMatchesArtifact"));
  assert.ok(diagnosticAcceptance.artifact.failedChecks.includes("readback.flowPulseObserved"));
  assert.ok(diagnosticAcceptance.artifact.failedChecks.includes("flowmemory.signalsLinkedToBroadcastReceipts"));
  assert.match(diagnosticAcceptance.artifact.launchLanguage.blocked, /Do not claim/);

  const strictDiagnosticNote = runRaw([
    proofRunner,
    "--deployment-note",
    "--plan-out",
    planPath,
    "--acceptance-artifact",
    acceptancePath,
    "--artifact-out",
    diagnosticNotePath,
    "--json",
  ]);
  assert.notEqual(strictDiagnosticNote.status, 0);
  assert.match(strictDiagnosticNote.stdout, /"liveProofAccepted": false/);

  const allowedDiagnosticNote = runOk([
    proofRunner,
    "--deployment-note",
    "--allow-incomplete",
    "--plan-out",
    planPath,
    "--acceptance-artifact",
    acceptancePath,
    "--artifact-out",
    diagnosticNotePath,
    "--json",
  ]);
  assert.equal(allowedDiagnosticNote.artifact.liveProofAccepted, false);
  assert.ok(allowedDiagnosticNote.artifact.blockedClaims.includes("production mainnet readiness"));
  assert.match(allowedDiagnosticNote.artifact.claimLanguage.blocked, /Do not claim/);

  writeJson(linkedReadbackPath, readbackArtifact(plan, {
    rangeSource: "broadcast-proof-artifact-receipts",
    fromBlock: "700",
    toBlock: "704",
    finalizedBlock: "704",
    observationCount: 1,
  }));
  writeJson(linkedFlowMemoryPath, flowMemoryArtifact(SWAP_TX_HASH));
  const linkedAcceptance = runOk([
    proofRunner,
    "--acceptance-package",
    "--allow-incomplete",
    "--plan-out",
    planPath,
    "--proof-artifact",
    broadcastProofPath,
    "--readback-range-artifact",
    inferredRangePath,
    "--readback-artifact",
    linkedReadbackPath,
    "--flowmemory-artifact",
    linkedFlowMemoryPath,
    "--artifact-out",
    acceptancePath,
    "--json",
  ]);
  assert.equal(
    linkedAcceptance.artifact.checks.find((check) => check.name === "flowmemory.signalsLinkedToBroadcastReceipts")
      ?.ok,
    true,
  );
  assert.equal(
    linkedAcceptance.artifact.checks.find((check) => check.name === "broadcast.poolManagerActionsSucceeded")?.ok,
    true,
  );

  writeJson(acceptedAcceptancePath, acceptedAcceptanceArtifact(linkedAcceptance.artifact));
  const acceptedNote = runOk([
    proofRunner,
    "--deployment-note",
    "--plan-out",
    planPath,
    "--acceptance-artifact",
    acceptedAcceptancePath,
    "--artifact-out",
    acceptedNotePath,
    "--json",
  ]);
  assert.equal(acceptedNote.artifact.liveProofAccepted, true);
  assert.equal(acceptedNote.artifact.poolManagerProof.actionsSucceeded, true);
  assert.equal(acceptedNote.artifact.flowMemory.signalTxHashesLinkedToBroadcastReceipts, true);
  assert.match(acceptedNote.artifact.claimLanguage.allowed, /Base Sepolia public-testnet proof/);

  const strictAcceptance = runRaw([
    proofRunner,
    "--acceptance-package",
    "--plan-out",
    planPath,
    "--proof-artifact",
    dryRunProofPath,
    "--readback-range-artifact",
    inferredRangePath,
    "--readback-artifact",
    matchingReadbackPath,
    "--artifact-out",
    acceptancePath,
    "--json",
  ]);
  assert.notEqual(strictAcceptance.status, 0);
  assert.match(strictAcceptance.stdout, /"liveProofAccepted": false/);

  console.log("Base Sepolia v4 hook readback range and acceptance checks passed.");
} finally {
  rmSync(tempDir, { recursive: true, force: true });
}

function readbackArtifact(plan, { rangeSource, fromBlock, toBlock, finalizedBlock, observationCount }) {
  return {
    schema: "flowmemory.base_sepolia.v4_hook_readback_artifact.v0",
    generatedAt: "2026-05-17T12:00:00.000Z",
    mode: "readback",
    productionReady: false,
    proofComplete: observationCount > 0,
    planPath: "test-plan.json",
    hook: plan.hook,
    indexer: {
      status: 0,
      statePath: "test-state.json",
      checkpointPath: "test-checkpoint.json",
      rangeSource,
      inferredFromProofArtifact: "broadcast-proof.json",
      fromBlock,
      toBlock,
      finalizedBlock,
      observationCount,
      rejectedLogCount: 0,
      duplicateCount: 0,
      dashboardCanonicalObservationCount: 0,
      lastIndexedBlock: toBlock,
      nextFromBlock: String(Number(toBlock) + 1),
      emptyRange: observationCount === 0,
      hasIntegrityWarnings: false,
    },
    boundaries: plan.boundaries,
  };
}

function flowMemoryArtifact(txHash) {
  return {
    schema: "flowmemory.base_sepolia.v4_hook_flowmemory_evidence.v0",
    generatedAt: "2026-05-17T12:00:00.000Z",
    mode: "base-sepolia-v4-hook-proof",
    productionReady: false,
    liveProofComplete: true,
    stage: "live-proof-complete",
    checks: {
      planEvidenceHookMatch: true,
      planReadbackHookMatch: true,
      checkpointIncludesHookAddress: true,
      observationCount: 1,
      canonicalObservationCount: 1,
      swapMemorySignalObservationCount: 1,
      allObservationsFromHook: true,
      allObservationsBaseSepolia: true,
      allObservationsFlowPulse: true,
      allObservationsReceiptSuccess: true,
    },
    memorySignals: [
      {
        txHash,
        contractEvent: {
          receiptLocator: {
            txHash,
          },
        },
      },
    ],
    memoryReceipts: [{ receiptId: "receipt:test" }],
    rootflowTransitions: [{ transitionId: "transition:test" }],
    acceptance: {
      livePoolManagerSwapObserved: true,
      dashboardFixtureGenerated: true,
    },
  };
}

function acceptedAcceptanceArtifact(artifact) {
  return {
    ...artifact,
    liveProofAccepted: true,
    stage: "live-proof-accepted",
    failedChecks: [],
    checks: artifact.checks.map((check) => ({ ...check, ok: true })),
    launchLanguage: {
      allowed:
        "FlowMemory completed a Base Sepolia public-testnet proof: a real Uniswap v4 PoolManager swap called the mined afterSwap-only hook, emitted FlowPulse, and generated Flow Memory / Rootflow evidence from readback.",
      blocked:
        "This remains public-testnet evidence only; do not claim production mainnet readiness, production L1 readiness, audited cryptography, free storage, or AI running on-chain.",
    },
  };
}

function proofArtifact(plan, { mode, broadcast, receipts, transactions = [] }) {
  return {
    schema: "flowmemory.base_sepolia.v4_hook_swap_proof_artifact.v0",
    generatedAt: "2026-05-17T12:00:00.000Z",
    mode,
    productionReady: false,
    planPath: "test-plan.json",
    hook: plan.hook,
    forge: {
      status: 0,
      script: "script/RunBaseSepoliaV4HookSwapProof.s.sol:RunBaseSepoliaV4HookSwapProof",
      broadcast,
    },
    foundryRun: {
      present: true,
      transactionCount: 12,
      receiptCount: receipts.length,
      receipts,
      transactions,
    },
    proof: {
      chainId: "84532",
      operator: "0x5555555555555555555555555555555555555555",
      hookAddress: plan.hook.hookAddress,
      token0: "0x1111111111111111111111111111111111111111",
      token1: "0x2222222222222222222222222222222222222222",
      poolId: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      rootfieldId: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      commitment: "0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
      parentPulseId: "0x0000000000000000000000000000000000000000000000000000000000000000",
      hookSalt: plan.hook.salt,
      initCodeHash: plan.hook.initCodeHash,
      liquidityDelta: "1000000000000000000",
      swapAmountSpecified: "-10000000000000000",
    },
  };
}

function runOk(args) {
  const result = runRaw(args);
  if (result.status !== 0) {
    throw new Error(`node ${args.join(" ")} failed:\n${result.stderr || result.stdout}`);
  }
  return parseJsonFromStdout(result.stdout);
}

function runRaw(args) {
  return spawnSync(process.execPath, args, {
    cwd: repoRoot,
    encoding: "utf8",
    shell: false,
  });
}

function parseJsonFromStdout(stdout) {
  const start = stdout.indexOf("{");
  assert.notEqual(start, -1, `stdout did not contain JSON:\n${stdout}`);
  return JSON.parse(stdout.slice(start));
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}
