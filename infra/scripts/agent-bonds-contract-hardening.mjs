#!/usr/bin/env node
import { spawnSync } from "node:child_process";

function run(command, args) {
  const result = spawnSync(command, args, { cwd: process.cwd(), stdio: "inherit", shell: false });
  if (result.status !== 0) {
    throw new Error(`Agent Bonds contract hardening failed: ${command} ${args.join(" ")}`);
  }
}

const SLITHER_ARGS = ["--compile-force-framework", "solc", "--solc-args", "--base-path . --include-path contracts --allow-paths .,contracts", "--exclude", "timestamp,assembly", "--exclude-informational", "--fail-none"];


const FORGE_SKIP_ARGS = ["--skip", "contracts/public-agent-network/*", "--skip", "contracts/public-agent-network/**/*"];


run("forge", ["test", "--match-path", "tests/AgentBondManager.t.sol", ...FORGE_SKIP_ARGS]);
run("forge", ["test", "--match-path", "tests/AgentBondTimelockedMultisig.t.sol", ...FORGE_SKIP_ARGS]);
run("forge", ["test", "--match-path", "tests/AgentUnderwriterPool.t.sol", ...FORGE_SKIP_ARGS]);
run("forge", ["test", "--match-path", "tests/AgentCreditAttestationRegistry.t.sol", ...FORGE_SKIP_ARGS]);
run("forge", ["test", "--match-path", "tests/AgentBondManagerRecourse.t.sol", ...FORGE_SKIP_ARGS]);
run("slither", ["contracts/AgentBondManager.sol", ...SLITHER_ARGS]);
run("slither", ["contracts/AgentBondTimelockedMultisig.sol", ...SLITHER_ARGS]);
run("slither", ["contracts/AgentUnderwriterPool.sol", ...SLITHER_ARGS]);
run("slither", ["contracts/UnderwriterPoolRegistry.sol", ...SLITHER_ARGS]);
run("slither", ["contracts/AgentCreditAttestationRegistry.sol", ...SLITHER_ARGS]);

console.log(JSON.stringify({ service: "flowmemory-agent-bonds-contract-hardening", ok: true }, null, 2));
