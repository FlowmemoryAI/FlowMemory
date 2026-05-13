#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

const args = new Set(process.argv.slice(2));
const requireSlither = args.has("--require-slither");
const checkFormat = args.has("--check-format");
const repoRoot = process.cwd();

function run(command, commandArgs, options = {}) {
  const result = spawnSync(command, commandArgs, {
    cwd: repoRoot,
    stdio: "inherit",
    shell: false,
    ...options,
  });

  if (result.status !== 0) {
    throw new Error(`contract hardening failed with exit code ${result.status ?? "unknown"}`);
  }
}

if (process.platform === "win32") {
  const psArgs = [
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    resolve(repoRoot, "infra/scripts/contracts-static-analysis.ps1"),
  ];
  if (checkFormat) psArgs.push("-CheckFormat");
  if (requireSlither) psArgs.push("-RequireSlither");
  run("powershell.exe", psArgs);
} else {
  run("bash", [resolve(repoRoot, "infra/scripts/contracts-static-analysis.sh")], {
    env: {
      ...process.env,
      REQUIRE_SLITHER: requireSlither ? "1" : process.env.REQUIRE_SLITHER ?? "0",
      CHECK_FORGE_FMT: checkFormat ? "1" : process.env.CHECK_FORGE_FMT ?? "0",
    },
  });
}
