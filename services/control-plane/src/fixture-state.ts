import { existsSync, readFileSync } from "node:fs";
import { dirname, isAbsolute, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { buildLaunchCore, type LaunchCorePaths } from "../../flowmemory/src/generate-launch-core.ts";
import type { LaunchCoreOutput } from "../../flowmemory/src/types.ts";
import {
  indexFlowPulseReceipts,
  loadIndexerFixtureReceipts,
  persistedIndexerState,
  type PersistedIndexerState,
} from "../../indexer/src/index.ts";
import {
  loadVerifierArtifactFixture,
  persistedVerifierReports,
  verifyObservations,
  type ArtifactResolverFixture,
  type PersistedVerifierReports,
} from "../../verifier/src/index.ts";
import { makeObservation, validateDeposit } from "../../bridge-relayer/src/observe-base-lockbox.ts";
import type {
  ControlPlanePaths,
  DataSourceRecord,
  JsonObject,
  LoadedControlPlaneState,
} from "./types.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");

export const DEFAULT_CONTROL_PLANE_PATHS: ControlPlanePaths = {
  launchCorePath: "fixtures/launch-core/flowmemory-launch-v0.json",
  indexerPath: "services/indexer/out/indexer-state.json",
  verifierPath: "services/verifier/out/reports.json",
  artifactsPath: "services/verifier/fixtures/artifacts.json",
  localDevnetPath: "devnet/local/state.json",
  localDevnetLaunchPath: "devnet/local/launch-v0-state.json",
  devnetPath: "fixtures/launch-core/generated/devnet/state.json",
  devnetIndexerHandoffPath: "fixtures/launch-core/generated/devnet/indexer-handoff.json",
  devnetVerifierHandoffPath: "fixtures/launch-core/generated/devnet/verifier-handoff.json",
  devnetControlPlaneHandoffPath: "fixtures/launch-core/generated/devnet/control-plane-handoff.json",
  txFixturesPath: "fixtures/handoff/sample-txs.json",
  txIntakePath: "devnet/local/intake/transactions.ndjson",
  bridgeObservationPath: "services/bridge-relayer/out/bridge-observation.json",
  bridgeRuntimeHandoffPath: "fixtures/bridge/local-runtime-bridge-handoff.json",
  bridgeObservationIntakePath: "devnet/local/intake/bridge-observations.ndjson",
  walletTransferProofPath: "devnet/local/production-l1-wallet/transfer-e2e/wallet-e2e-proof.json",
  walletPublicMetadataPath: "devnet/local/wallet/flowchain-operator/flowchain-operator-public-metadata.json",
};

export function resolveControlPlanePath(path: string): string {
  return isAbsolute(path) ? path : resolve(REPO_ROOT, path);
}

function readJson<T>(path: string): T {
  return JSON.parse(readFileSync(resolveControlPlanePath(path), "utf8")) as T;
}

function sourceRecord(
  name: string,
  path: string,
  status: DataSourceRecord["status"],
  recovery?: string,
): DataSourceRecord {
  return {
    schema: "flowmemory.control_plane.data_source.v0",
    name,
    path,
    status,
    recovery,
  };
}

type JsonFileRead<T> =
  | { status: "loaded"; value: T }
  | { status: "missing" }
  | { status: "degraded"; recovery: string };

type NdjsonRead = {
  rows: JsonObject[];
  status: "loaded" | "missing" | "degraded";
  recovery?: string;
};

function jsonError(error: unknown): string {
  return error instanceof Error ? error.message.replace(/\s+/g, " ") : "unknown JSON parse error";
}

function readJsonFile<T>(path: string): JsonFileRead<T> {
  if (!existsSync(resolveControlPlanePath(path))) {
    return { status: "missing" };
  }
  try {
    return { status: "loaded", value: readJson<T>(path) };
  } catch (error) {
    return {
      status: "degraded",
      recovery: `skipped malformed JSON at ${path}: ${jsonError(error)}`,
    };
  }
}

function maybeReadJson(path: string): JsonObject | null {
  const result = readJsonFile<JsonObject>(path);
  return result.status === "loaded" ? result.value : null;
}

function readNdjson(path: string): NdjsonRead {
  const resolved = resolveControlPlanePath(path);
  if (!existsSync(resolved)) {
    return { rows: [], status: "missing" };
  }
  const rows: JsonObject[] = [];
  let malformedRows = 0;
  readFileSync(resolved, "utf8")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .forEach((line) => {
      try {
        rows.push(JSON.parse(line) as JsonObject);
      } catch {
        malformedRows += 1;
      }
    });
  if (malformedRows > 0) {
    return {
      rows,
      status: "degraded",
      recovery: `skipped ${malformedRows} malformed NDJSON row(s) at ${path}`,
    };
  }
  return { rows, status: rows.length === 0 ? "missing" : "loaded" };
}

function loadOrBuildIndexer(path: string, sources: Record<string, DataSourceRecord>): PersistedIndexerState {
  if (existsSync(resolveControlPlanePath(path))) {
    const persisted = readJsonFile<PersistedIndexerState>(path);
    if (persisted.status === "loaded") {
      sources.indexer = sourceRecord("indexer", path, "loaded");
      return persisted.value;
    }

    const state = indexFlowPulseReceipts(loadIndexerFixtureReceipts(), {
      finalizedBlockNumber: "123458",
    });
    sources.indexer = sourceRecord(
      "indexer",
      path,
      "degraded",
      `${persisted.recovery}; built in memory from services/indexer/fixtures/flowpulse-receipts.json`,
    );
    return persistedIndexerState(state);
  }

  const state = indexFlowPulseReceipts(loadIndexerFixtureReceipts(), {
    finalizedBlockNumber: "123458",
  });
  sources.indexer = sourceRecord("indexer", path, "recovered", "built in memory from services/indexer/fixtures/flowpulse-receipts.json");
  return persistedIndexerState(state);
}

function loadOrBuildVerifier(
  path: string,
  indexer: PersistedIndexerState,
  resolver: ArtifactResolverFixture,
  sources: Record<string, DataSourceRecord>,
): PersistedVerifierReports {
  if (existsSync(resolveControlPlanePath(path))) {
    const persisted = readJsonFile<PersistedVerifierReports>(path);
    if (persisted.status === "loaded") {
      sources.verifier = sourceRecord("verifier", path, "loaded");
      return persisted.value;
    }

    const reports = verifyObservations(indexer.state.observations, resolver);
    sources.verifier = sourceRecord(
      "verifier",
      path,
      "degraded",
      `${persisted.recovery}; built in memory from indexer observations and artifact fixtures`,
    );
    return persistedVerifierReports(reports);
  }

  const reports = verifyObservations(indexer.state.observations, resolver);
  sources.verifier = sourceRecord("verifier", path, "recovered", "built in memory from indexer observations and artifact fixtures");
  return persistedVerifierReports(reports);
}

function loadArtifacts(path: string, sources: Record<string, DataSourceRecord>): ArtifactResolverFixture {
  if (existsSync(resolveControlPlanePath(path))) {
    const fixture = readJsonFile<ArtifactResolverFixture>(path);
    if (fixture.status === "loaded") {
      sources.artifacts = sourceRecord("artifacts", path, "loaded");
      return fixture.value;
    }

    sources.artifacts = sourceRecord(
      "artifacts",
      path,
      "degraded",
      `${fixture.recovery}; loaded default services/verifier artifact fixture`,
    );
    return loadVerifierArtifactFixture();
  }

  sources.artifacts = sourceRecord("artifacts", path, "recovered", "loaded default services/verifier artifact fixture");
  return loadVerifierArtifactFixture();
}

function launchPaths(paths: ControlPlanePaths): LaunchCorePaths {
  return {
    indexerPath: paths.indexerPath,
    verifierPath: paths.verifierPath,
    devnetPath: paths.devnetPath,
    hardwarePath: "hardware/fixtures/flowrouter_sample_seed42.json",
    launchOutPath: paths.launchCorePath,
    transitionsOutPath: "fixtures/launch-core/rootflow-transitions.json",
    dashboardOutPath: "fixtures/dashboard/flowmemory-dashboard-v0.json",
    dashboardRuntimePath: "apps/dashboard/public/data/flowmemory-dashboard-v0.json",
  };
}

function loadOrBuildLaunchCore(
  paths: ControlPlanePaths,
  indexer: PersistedIndexerState,
  verifier: PersistedVerifierReports,
  sources: Record<string, DataSourceRecord>,
): LaunchCoreOutput {
  if (existsSync(resolveControlPlanePath(paths.launchCorePath))) {
    const launchCore = readJsonFile<LaunchCoreOutput>(paths.launchCorePath);
    if (launchCore.status === "loaded") {
      sources.launchCore = sourceRecord("launchCore", paths.launchCorePath, "loaded");
      return launchCore.value;
    }

    sources.launchCore = sourceRecord(
      "launchCore",
      paths.launchCorePath,
      "degraded",
      `${launchCore.recovery}; built in memory from indexer and verifier state`,
    );
    return buildLaunchCore(indexer, verifier, launchPaths(paths));
  }

  sources.launchCore = sourceRecord("launchCore", paths.launchCorePath, "recovered", "built in memory from indexer and verifier state");
  return buildLaunchCore(indexer, verifier, launchPaths(paths));
}

function loadOptionalSource(
  name: string,
  path: string,
  sources: Record<string, DataSourceRecord>,
): JsonObject | null {
  const result = readJsonFile<JsonObject>(path);
  if (result.status === "loaded") {
    sources[name] = sourceRecord(name, path, "loaded");
    return result.value;
  }
  if (result.status === "degraded") {
    sources[name] = sourceRecord(name, path, "degraded", result.recovery);
    return null;
  }
  sources[name] = sourceRecord(name, path, "missing");
  return null;
}

function loadDevnetSource(paths: ControlPlanePaths, sources: Record<string, DataSourceRecord>): JsonObject | null {
  const skipped: string[] = [];
  for (const [path, recovery] of [
    [paths.localDevnetPath, undefined],
    [paths.localDevnetLaunchPath, "loaded from devnet/local launch runtime state"],
    [paths.devnetPath, "loaded committed devnet fixture fallback"],
  ] as const) {
    const result = readJsonFile<JsonObject>(path);
    if (result.status === "loaded") {
      const status = skipped.length > 0 ? "degraded" : path === paths.localDevnetPath ? "loaded" : "recovered";
      const combinedRecovery = skipped.length > 0
        ? `${skipped.join("; ")}; ${recovery ?? "loaded usable devnet runtime state"}`
        : recovery;
      sources.devnet = sourceRecord("devnet", path, status, combinedRecovery);
      return result.value;
    }
    if (result.status === "degraded") {
      skipped.push(result.recovery);
    }
  }
  sources.devnet = skipped.length > 0
    ? sourceRecord("devnet", paths.localDevnetPath, "degraded", `no usable devnet JSON source loaded; ${skipped.join("; ")}`)
    : sourceRecord("devnet", paths.localDevnetPath, "missing");
  return null;
}

function loadTxIntake(path: string, sources: Record<string, DataSourceRecord>): JsonObject[] {
  const intake = readNdjson(path);
  sources.txIntake = sourceRecord("txIntake", path, intake.status, intake.recovery);
  return intake.rows;
}

function loadBridgeObservations(paths: ControlPlanePaths, sources: Record<string, DataSourceRecord>): JsonObject[] {
  const observations: JsonObject[] = [];
  const persisted = readJsonFile<JsonObject>(paths.bridgeObservationPath);
  if (persisted.status === "loaded") {
    observations.push(persisted.value);
    sources.bridgeObservation = sourceRecord("bridgeObservation", paths.bridgeObservationPath, "loaded");
  } else {
    const bridgeFixturePath = "fixtures/bridge/base-sepolia-mock-deposit.json";
    const fixture = readJsonFile<JsonObject>(bridgeFixturePath);
    if (fixture.status === "loaded") {
      observations.push(makeObservation(validateDeposit(fixture.value), "mock") as unknown as JsonObject);
      sources.bridgeObservation = sourceRecord(
        "bridgeObservation",
        bridgeFixturePath,
        persisted.status === "degraded" ? "degraded" : "recovered",
        persisted.status === "degraded"
          ? `${persisted.recovery}; built from committed mock bridge deposit fixture`
          : "built from committed mock bridge deposit fixture",
      );
    } else {
      sources.bridgeObservation = sourceRecord(
        "bridgeObservation",
        paths.bridgeObservationPath,
        persisted.status === "degraded" || fixture.status === "degraded" ? "degraded" : "missing",
        [persisted.status === "degraded" ? persisted.recovery : null, fixture.status === "degraded" ? fixture.recovery : null]
          .filter((entry): entry is string => entry !== null)
          .join("; ") || undefined,
      );
    }
  }

  const intake = readNdjson(paths.bridgeObservationIntakePath);
  if (intake.rows.length > 0) {
    observations.push(...intake.rows);
  }
  sources.bridgeObservationIntake = sourceRecord("bridgeObservationIntake", paths.bridgeObservationIntakePath, intake.status, intake.recovery);
  return observations;
}

export function controlPlanePaths(overrides: Partial<ControlPlanePaths> = {}): ControlPlanePaths {
  return {
    ...DEFAULT_CONTROL_PLANE_PATHS,
    bridgeRuntimeHandoffPath: process.env.FLOWCHAIN_CONTROL_PLANE_BRIDGE_RUNTIME_HANDOFF_PATH
      ?? DEFAULT_CONTROL_PLANE_PATHS.bridgeRuntimeHandoffPath,
    bridgeObservationPath: process.env.FLOWCHAIN_CONTROL_PLANE_BRIDGE_OBSERVATION_PATH
      ?? DEFAULT_CONTROL_PLANE_PATHS.bridgeObservationPath,
    walletPublicMetadataPath: process.env.FLOWCHAIN_CONTROL_PLANE_WALLET_PUBLIC_METADATA_PATH
      ?? DEFAULT_CONTROL_PLANE_PATHS.walletPublicMetadataPath,
    ...overrides,
  };
}

export function loadControlPlaneState(overrides: Partial<ControlPlanePaths> = {}): LoadedControlPlaneState {
  const paths = controlPlanePaths(overrides);
  const sources: Record<string, DataSourceRecord> = {};
  const artifacts = loadArtifacts(paths.artifactsPath, sources);
  const indexer = loadOrBuildIndexer(paths.indexerPath, sources);
  const verifier = loadOrBuildVerifier(paths.verifierPath, indexer, artifacts, sources);
  const launchCore = loadOrBuildLaunchCore(paths, indexer, verifier, sources);
  const devnet = loadDevnetSource(paths, sources);
  const devnetIndexerHandoff = loadOptionalSource("devnetIndexerHandoff", paths.devnetIndexerHandoffPath, sources);
  const devnetVerifierHandoff = loadOptionalSource("devnetVerifierHandoff", paths.devnetVerifierHandoffPath, sources);
  const devnetControlPlaneHandoff = loadOptionalSource("devnetControlPlaneHandoff", paths.devnetControlPlaneHandoffPath, sources);
  const txFixtures = loadOptionalSource("txFixtures", paths.txFixturesPath, sources);
  const txIntake = loadTxIntake(paths.txIntakePath, sources);
  const bridgeObservations = loadBridgeObservations(paths, sources);
  const bridgeRuntimeHandoff = loadOptionalSource("bridgeRuntimeHandoff", paths.bridgeRuntimeHandoffPath, sources);
  const walletTransferProof = loadOptionalSource("walletTransferProof", paths.walletTransferProofPath, sources);
  const walletPublicMetadata = loadOptionalSource("walletPublicMetadata", paths.walletPublicMetadataPath, sources);

  return {
    schema: "flowmemory.control_plane.state.v0",
    launchCore,
    indexer,
    verifier,
    artifacts,
    devnet,
    devnetIndexerHandoff,
    devnetVerifierHandoff,
    devnetControlPlaneHandoff,
    txFixtures,
    txIntake,
    bridgeObservations,
    bridgeRuntimeHandoff,
    walletTransferProof,
    walletPublicMetadata,
    paths,
    sources,
  };
}

export function repoRoot(): string {
  return REPO_ROOT;
}
