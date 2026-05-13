import { mkdirSync, readFileSync, rmSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { canonicalJson } from "../../shared/src/index.ts";
import { DEFAULT_LAUNCH_CORE_PATHS, generateLaunchCore, type LaunchCorePaths } from "./generate-launch-core.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const TEMP_ROOT = "out/flowmemory-fixture-drift";

const fixturePairs: Array<[keyof LaunchCorePaths, string]> = [
  ["launchOutPath", DEFAULT_LAUNCH_CORE_PATHS.launchOutPath],
  ["transitionsOutPath", DEFAULT_LAUNCH_CORE_PATHS.transitionsOutPath],
  ["dashboardOutPath", DEFAULT_LAUNCH_CORE_PATHS.dashboardOutPath],
  ["dashboardRuntimePath", DEFAULT_LAUNCH_CORE_PATHS.dashboardRuntimePath],
];

function readCanonical(path: string): string {
  return canonicalJson(JSON.parse(readFileSync(resolve(REPO_ROOT, path), "utf8")));
}

function tempPath(name: keyof LaunchCorePaths): string {
  if (name === "launchOutPath") return `${TEMP_ROOT}/flowmemory-launch-v0.json`;
  if (name === "transitionsOutPath") return `${TEMP_ROOT}/rootflow-transitions.json`;
  if (name === "dashboardOutPath") return `${TEMP_ROOT}/flowmemory-dashboard-v0.json`;
  if (name === "dashboardRuntimePath") return `${TEMP_ROOT}/dashboard-runtime/flowmemory-dashboard-v0.json`;
  throw new Error(`unsupported generated fixture path key: ${name}`);
}

export function checkFixtureDrift(): void {
  process.chdir(REPO_ROOT);
  rmSync(resolve(REPO_ROOT, TEMP_ROOT), { recursive: true, force: true });
  mkdirSync(resolve(REPO_ROOT, TEMP_ROOT), { recursive: true });

  const tempPaths: LaunchCorePaths = {
    ...DEFAULT_LAUNCH_CORE_PATHS,
    launchOutPath: tempPath("launchOutPath"),
    transitionsOutPath: tempPath("transitionsOutPath"),
    dashboardOutPath: tempPath("dashboardOutPath"),
    dashboardRuntimePath: tempPath("dashboardRuntimePath"),
  };

  generateLaunchCore(tempPaths);

  const drifted = fixturePairs
    .map(([key, committedPath]) => {
      const generatedPath = tempPath(key);
      return readCanonical(committedPath) === readCanonical(generatedPath)
        ? null
        : { committedPath, generatedPath };
    })
    .filter((result): result is { committedPath: string; generatedPath: string } => result !== null);

  if (drifted.length > 0) {
    throw new Error(`Generated launch fixtures are stale:\n${drifted
      .map((result) => `- ${result.committedPath} differs from ${result.generatedPath}`)
      .join("\n")}\nRun npm run launch:v0 and commit the regenerated fixtures.`);
  }

  console.log(JSON.stringify({
    service: "flowmemory-fixture-drift-check",
    checked: fixturePairs.map(([, path]) => path),
    status: "clean",
  }, null, 2));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  checkFixtureDrift();
}
