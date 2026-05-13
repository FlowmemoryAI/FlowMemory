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
  devnetPath: "fixtures/launch-core/generated/devnet/state.json",
  devnetIndexerHandoffPath: "fixtures/launch-core/generated/devnet/indexer-handoff.json",
  devnetVerifierHandoffPath: "fixtures/launch-core/generated/devnet/verifier-handoff.json",
  devnetControlPlaneHandoffPath: "fixtures/launch-core/generated/devnet/control-plane-handoff.json",
  txFixturesPath: "fixtures/handoff/sample-txs.json",
};

function resolveRepoPath(path: string): string {
  return isAbsolute(path) ? path : resolve(REPO_ROOT, path);
}

function readJson<T>(path: string): T {
  return JSON.parse(readFileSync(resolveRepoPath(path), "utf8")) as T;
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

function maybeReadJson(path: string): JsonObject | null {
  if (!existsSync(resolveRepoPath(path))) {
    return null;
  }
  return readJson<JsonObject>(path);
}

function loadOrBuildIndexer(path: string, sources: Record<string, DataSourceRecord>): PersistedIndexerState {
  if (existsSync(resolveRepoPath(path))) {
    sources.indexer = sourceRecord("indexer", path, "loaded");
    return readJson<PersistedIndexerState>(path);
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
  if (existsSync(resolveRepoPath(path))) {
    sources.verifier = sourceRecord("verifier", path, "loaded");
    return readJson<PersistedVerifierReports>(path);
  }

  const reports = verifyObservations(indexer.state.observations, resolver);
  sources.verifier = sourceRecord("verifier", path, "recovered", "built in memory from indexer observations and artifact fixtures");
  return persistedVerifierReports(reports);
}

function loadArtifacts(path: string, sources: Record<string, DataSourceRecord>): ArtifactResolverFixture {
  if (existsSync(resolveRepoPath(path))) {
    sources.artifacts = sourceRecord("artifacts", path, "loaded");
    return readJson<ArtifactResolverFixture>(path);
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
  if (existsSync(resolveRepoPath(paths.launchCorePath))) {
    sources.launchCore = sourceRecord("launchCore", paths.launchCorePath, "loaded");
    return readJson<LaunchCoreOutput>(paths.launchCorePath);
  }

  sources.launchCore = sourceRecord("launchCore", paths.launchCorePath, "recovered", "built in memory from indexer and verifier state");
  return buildLaunchCore(indexer, verifier, launchPaths(paths));
}

function loadOptionalSource(
  name: string,
  path: string,
  sources: Record<string, DataSourceRecord>,
): JsonObject | null {
  const value = maybeReadJson(path);
  sources[name] = sourceRecord(name, path, value === null ? "missing" : "loaded");
  return value;
}

export function controlPlanePaths(overrides: Partial<ControlPlanePaths> = {}): ControlPlanePaths {
  return {
    ...DEFAULT_CONTROL_PLANE_PATHS,
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
  const devnet = loadOptionalSource("devnet", paths.devnetPath, sources);
  const devnetIndexerHandoff = loadOptionalSource("devnetIndexerHandoff", paths.devnetIndexerHandoffPath, sources);
  const devnetVerifierHandoff = loadOptionalSource("devnetVerifierHandoff", paths.devnetVerifierHandoffPath, sources);
  const devnetControlPlaneHandoff = loadOptionalSource("devnetControlPlaneHandoff", paths.devnetControlPlaneHandoffPath, sources);
  const txFixtures = loadOptionalSource("txFixtures", paths.txFixturesPath, sources);

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
    sources,
  };
}

export function repoRoot(): string {
  return REPO_ROOT;
}
