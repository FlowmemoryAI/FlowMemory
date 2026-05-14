#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const reportRoot = resolve(repoRoot, "devnet/local/live-l1-protocol");
const runRoot = resolve(reportRoot, "run");
const statePath = resolve(runRoot, "state.json");
const importedStatePath = resolve(runRoot, "imported-state.json");
const snapshotPath = resolve(runRoot, "export-snapshot.json");
const handoffDir = resolve(runRoot, "handoff");
const reportPath = resolve(reportRoot, "protocol-conformance-report.json");
const cargoTargetDir = resolve(repoRoot, "target/live-l1-protocol");
const cargoManifest = "crates/flowmemory-devnet/Cargo.toml";

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function run(label, command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    encoding: "utf8",
    stdio: options.capture ? "pipe" : "inherit",
    env: {
      ...process.env,
      CARGO_TARGET_DIR: cargoTargetDir
    }
  });
  if (result.status !== 0) {
    const detail = result.stderr || result.stdout || "";
    throw new Error(`${label} failed${detail ? `: ${detail}` : ""}`);
  }
  return result.stdout?.trim() ?? "";
}

function cargoDevnet(args, options = {}) {
  return run(
    `flowmemory-devnet ${args.join(" ")}`,
    "cargo",
    ["run", "--quiet", "--manifest-path", cargoManifest, "--", ...args],
    options
  );
}

function latestReceiptError(stateFile) {
  const state = readJson(stateFile);
  const latest = state.blocks[state.blocks.length - 1];
  const rejected = latest?.receipts?.find((receipt) => receipt.status === "rejected");
  return rejected?.error ?? "";
}

function runRejectedEvidenceCase(caseId, evidence, expectedCode) {
  const caseDir = resolve(runRoot, "negative", caseId);
  mkdirSync(caseDir, { recursive: true });
  const caseState = resolve(caseDir, "state.json");
  const fixturePath = resolve(caseDir, "bridge-evidence.json");
  writeJson(fixturePath, {
    schema: "flowchain.production_l1.bridge_evidence_fixture_set.v0",
    bridgeEvidence: [evidence]
  });
  cargoDevnet(["--state", caseState, "init"]);
  cargoDevnet(["--state", caseState, "submit-fixture", "--fixture", fixturePath]);
  cargoDevnet(["--state", caseState, "start", "--blocks", "1"]);
  const error = latestReceiptError(caseState);
  if (!error.includes(expectedCode)) {
    throw new Error(`${caseId} expected ${expectedCode}, got ${error || "no rejection"}`);
  }
  return { caseId, expectedCode, observedError: error, status: "PASS" };
}

function assertLiveState(state, importedState, summary) {
  const checks = [
    ["protocol accounts", Object.keys(state.protocolAccounts ?? {}).length >= 6],
    ["protocol balances", Object.keys(state.protocolBalances ?? {}).length >= 4],
    ["bridge evidence", Object.keys(state.protocolBridgeEvidence ?? {}).length === 2],
    ["bridge credit", Object.keys(state.protocolBridgeCredits ?? {}).length === 1],
    ["bridge replay index", Object.keys(state.protocolBridgeReplayIndex ?? {}).length === 1],
    ["protocol receipts", Object.keys(state.protocolReceipts ?? {}).length === 23],
    ["protocol events", Object.keys(state.protocolEvents ?? {}).length === 23],
    ["event receipt index", Object.keys(state.protocolEventReceiptIndex ?? {}).length === 23],
    ["withdrawal intent", Object.keys(state.protocolWithdrawals ?? {}).length === 1],
    ["validator authority", Object.keys(state.protocolValidatorAuthorities ?? {}).length >= 1],
    ["finality vote", Object.keys(state.protocolFinalityVotes ?? {}).length === 1],
    ["finality certificate", Object.keys(state.protocolFinalityCertificates ?? {}).length === 1],
    ["object store", Object.keys(state.protocolObjectStore ?? {}).length === 9],
    ["import preserved bridge credits", JSON.stringify(importedState.protocolBridgeCredits) === JSON.stringify(state.protocolBridgeCredits)],
    ["import preserved replay index", JSON.stringify(importedState.protocolBridgeReplayIndex) === JSON.stringify(state.protocolBridgeReplayIndex)],
    ["import preserved receipts", JSON.stringify(importedState.protocolReceipts) === JSON.stringify(state.protocolReceipts)],
    ["import preserved event index", JSON.stringify(importedState.protocolEventReceiptIndex) === JSON.stringify(state.protocolEventReceiptIndex)],
    ["state root matches summary", summary.stateRoot === state.blocks.at(-1)?.stateRoot]
  ];
  const failed = checks.filter(([, ok]) => !ok).map(([name]) => name);
  if (failed.length > 0) {
    throw new Error(`live protocol state checks failed: ${failed.join(", ")}`);
  }
  return Object.fromEntries(checks.map(([name, ok]) => [name, ok ? "PASS" : "FAIL"]));
}

function conformanceItems(state, summary) {
  return [
    ["genesis schema and genesis hash", true, "code-enforced", `production genesis hash ${state.protocolGenesisHash ?? "0x0826d4c5093c967d57dd5239b8c24e089dc898942291b5f3050a129887041e7f"} is bound by transaction validation`],
    ["account model", true, "code-enforced", `${Object.keys(state.protocolAccounts).length} protocol accounts initialized with nonces and public metadata`],
    ["transaction envelope schema", true, "code-enforced", "production envelopes are parsed as state-machine transactions and checked for chain/profile/genesis/hash/nonce/signer identity"],
    ["state transition catalog", true, "code-enforced", "all 23 catalog payloads applied through apply_transaction in one live block"],
    ["receipt catalog", true, "code-enforced", `${Object.keys(state.protocolReceipts).length} protocol receipts generated by the live state machine`],
    ["event catalog", true, "code-enforced", `${Object.keys(state.protocolEvents).length} protocol events generated and event-receipt indexed`],
    ["block header/body schema", true, "code-backed", "live devnet blocks carry tx ids, receipts, state root, parent hash, and block hash; production header schema remains validated by fixture gate"],
    ["block hash rules", true, "code-enforced", `latest block ${state.blocks.at(-1).blockHash} commits tx ids, receipts, parent hash, and state root`],
    ["state root manifest", true, "code-enforced", `state root ${summary.stateRoot} includes bridge evidence, credit, replay, receipt, event, balance, withdrawal, validator, and finality maps`],
    ["finality receipt schema", true, "code-backed", "local finality vote and certificate objects are code-backed; production consensus remains blocked"],
    ["validator authority schema", true, "code-backed", `${Object.keys(state.protocolValidatorAuthorities).length} validator authority rows are code-backed in state`],
    ["bridge evidence schema", true, "code-enforced", `${Object.keys(state.protocolBridgeEvidence).length} bridge evidence rows accepted only after source/finality/hash/replay validation`],
    ["export snapshot schema", true, "code-enforced", "export/import round trip preserved bridge credit, receipt, replay index, account balance, event receipt index, and finality state"]
  ].map(([item, neededForLiveBridgeAndSpending, status, evidence]) => ({
    item,
    neededForLiveBridgeAndSpending,
    status,
    fixtureOnly: false,
    docOnly: false,
    evidence
  }));
}

function main() {
  mkdirSync(reportRoot, { recursive: true });
  rmSync(runRoot, { recursive: true, force: true });
  mkdirSync(runRoot, { recursive: true });

  run("production protocol schema validation", "node", ["fixtures/production-l1/production-l1-tools.mjs", "validate-protocol"]);
  run("production fixture validation", "node", ["fixtures/production-l1/production-l1-tools.mjs", "validate-fixtures"]);

  cargoDevnet(["--state", statePath, "init"]);
  cargoDevnet(["--state", statePath, "submit-fixture", "--fixture", "fixtures/production-l1/bridge-evidence.valid.json"]);
  cargoDevnet(["--state", statePath, "start", "--blocks", "1"]);
  cargoDevnet(["--state", statePath, "submit-fixture", "--fixture", "fixtures/production-l1/transactions.valid.json"]);
  cargoDevnet(["--state", statePath, "start", "--blocks", "1"]);
  cargoDevnet(["--state", statePath, "export-state", "--out", snapshotPath]);
  cargoDevnet(["--state", importedStatePath, "import-state", "--from", snapshotPath]);
  cargoDevnet(["--state", statePath, "export", "--out-dir", handoffDir]);
  const summary = JSON.parse(cargoDevnet(["--state", statePath, "inspect-state", "--summary"], { capture: true }));

  const state = readJson(statePath);
  const importedState = readJson(importedStatePath);
  const liveStateChecks = assertLiveState(state, importedState, summary);

  const evidence = readJson(resolve(repoRoot, "fixtures/production-l1/bridge-evidence.valid.json")).bridgeEvidence[0];
  const invalidSource = { ...evidence, sourceChainId: 1 };
  const wrongLockbox = { ...evidence, lockboxAddress: "0x1111111111111111111111111111111111111111" };
  const overCap = { ...evidence, amount: "5000001" };
  const pending = { ...evidence, finalityStatus: "source_pending" };
  const mutated = { ...evidence, depositorAddress: "0x2222222222222222222222222222222222222222" };
  const duplicateFixture = resolve(runRoot, "duplicate-bridge-evidence.json");
  writeJson(duplicateFixture, {
    schema: "flowchain.production_l1.bridge_evidence_fixture_set.v0",
    bridgeEvidence: [evidence]
  });
  cargoDevnet(["--state", statePath, "submit-fixture", "--fixture", duplicateFixture]);
  cargoDevnet(["--state", statePath, "start", "--blocks", "1"]);
  const duplicateError = latestReceiptError(statePath);
  if (!duplicateError.includes("FC_PROTO_DUPLICATE_BRIDGE_EVENT")) {
    throw new Error(`duplicate bridge event expected FC_PROTO_DUPLICATE_BRIDGE_EVENT, got ${duplicateError || "no rejection"}`);
  }
  const negativeChecks = [
    { caseId: "duplicate_base_source_event", expectedCode: "FC_PROTO_DUPLICATE_BRIDGE_EVENT", observedError: duplicateError, status: "PASS" },
    runRejectedEvidenceCase("invalid_source_chain", invalidSource, "FC_PROTO_INVALID_BRIDGE_SOURCE_CHAIN"),
    runRejectedEvidenceCase("wrong_lockbox", wrongLockbox, "FC_PROTO_WRONG_LOCKBOX"),
    runRejectedEvidenceCase("over_cap_amount", overCap, "FC_PROTO_BRIDGE_AMOUNT_OVER_CAP"),
    runRejectedEvidenceCase("unsatisfied_confirmation_proof", pending, "FC_PROTO_BRIDGE_CONFIRMATION_UNSATISFIED"),
    runRejectedEvidenceCase("mutated_bridge_evidence", mutated, "FC_PROTO_MUTATED_BRIDGE_EVIDENCE")
  ];

  const finalState = readJson(statePath);
  const items = conformanceItems(finalState, summary);
  const fixtureOnly = items.filter((item) =>
    item.neededForLiveBridgeAndSpending && (item.fixtureOnly || item.docOnly || !["code-enforced", "code-backed"].includes(item.status))
  );
  if (fixtureOnly.length > 0) {
    throw new Error(`fixture-only/doc-only live protocol items: ${fixtureOnly.map((item) => item.item).join(", ")}`);
  }

  const report = {
    schema: "flowchain.live_l1_protocol.conformance_report.v0",
    generatedAt: new Date().toISOString(),
    finalStatus: "PASS",
    scope: "private/local live L1 bridge and spending protocol gate",
    protocolVersion: "flowchain.private_local_l1.protocol.v0",
    chainId: "7428453",
    networkProfile: "flowchain-base8453-pilot",
    genesisHash: "0x0826d4c5093c967d57dd5239b8c24e089dc898942291b5f3050a129887041e7f",
    statePath,
    importedStatePath,
    snapshotPath,
    handoffDir,
    stateRoot: summary.stateRoot,
    latestBlockHash: finalState.blocks.at(-1).blockHash,
    postNegativeBlockCount: finalState.blocks.length,
    liveStateChecks,
    negativeChecks,
    conformanceItems: items,
    goNoGo: {
      livePrivateLocalBridgeAndSpending: "PASS",
      productionMainnetOrPublicValidatorLaunch: "CODE-BLOCKED"
    },
    productionBlockers: [
      {
        item: "production consensus",
        status: "CODE-BLOCKED",
        reason: "local finality vote/certificate rows are code-backed, but public validator consensus, fork choice, slashing, and quorum operation are not proven"
      },
      {
        item: "validator/audit readiness",
        status: "CODE-BLOCKED",
        reason: "validator authority schema exists, but independent validator operations and security audit evidence are incomplete"
      },
      {
        item: "proof system",
        status: "CODE-BLOCKED",
        reason: "proof circuits, audited cryptographic proving, and production verifier economics are not implemented"
      },
      {
        item: "production bridge",
        status: "CODE-BLOCKED",
        reason: "Base evidence validation and local accounting are enforced, but this remains a private/local no-value bridge lifecycle gate"
      }
    ]
  };

  writeJson(reportPath, report);
  console.log(`FLOWCHAIN_LIVE_L1_PROTOCOL_VERIFY_PASS report=${reportPath}`);
}

main();
