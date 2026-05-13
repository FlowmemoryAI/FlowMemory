#!/usr/bin/env node
import { spawnSync } from "node:child_process";

const args = new Set(process.argv.slice(2));
const broadcast = args.has("--broadcast");

const rpcUrl = process.env.BASE_SEPOLIA_RPC_URL;
const deployerKey = process.env.BASE_SEPOLIA_DEPLOYER_KEY_HEX;

if (!rpcUrl) {
  throw new Error("BASE_SEPOLIA_RPC_URL is required for Base Sepolia deployment runs");
}

if (!deployerKey) {
  throw new Error("BASE_SEPOLIA_DEPLOYER_KEY_HEX is required for Base Sepolia deployment runs");
}

const forgeArgs = [
  "script",
  "script/DeployLaunchCandidate.s.sol:DeployLaunchCandidate",
  "--rpc-url",
  rpcUrl,
  "--private-key",
  deployerKey,
];

if (broadcast) {
  forgeArgs.push("--broadcast", "--slow");
}

const result = spawnSync("forge", forgeArgs, {
  cwd: process.cwd(),
  stdio: "inherit",
  shell: process.platform === "win32",
});

if (result.status !== 0) {
  throw new Error(`Base Sepolia deploy ${broadcast ? "broadcast" : "dry run"} failed with exit code ${result.status ?? "unknown"}`);
}
