#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const requiredBooleanBlockers = [
  "externalReview.completed must be true",
  "operatorSeparation.completed must be true",
  "runtimeEvidence.multiOperatorRunCompleted must be true",
  "goNoGoDecision.approved must be true",
];

function runNode(args) {
  return spawnSync("node", args, {
    cwd: root,
    encoding: "utf8",
  });
}

function main() {
  const approvalPath = process.argv[2] ?? "fixtures/agent-bonds/launch-approval.template.json";
  const pilotConfigPath = process.argv[3] ?? "fixtures/agent-bonds/pilot-config.template.json";

  const bundle = runNode(["infra/scripts/agent-bonds-operator-bundle.mjs"]);
  if (bundle.status !== 0) {
    throw new Error(`Failed to build operator bundle before blocker audit:\n${bundle.stderr}`);
  }

  const result = runNode([
    "infra/scripts/agent-bonds-public-launch-validate.mjs",
    approvalPath,
    pilotConfigPath,
  ]);

  if (result.status === 0) {
    throw new Error("Public launch validator unexpectedly passed for the provided approval packet.");
  }

  const stderr = result.stderr;
  for (const snippet of requiredBooleanBlockers) {
    if (!stderr.includes(snippet)) {
      throw new Error(`Expected blocker snippet missing: ${snippet}`);
    }
  }

  if (!/placeholder|PENDING/i.test(stderr)) {
    throw new Error("Expected placeholder-based external signoff blockers were not present.");
  }

  const disallowedSignals = [
    "schema validation failed",
    "pilotConfigPath is missing",
    "readiness report must be green",
    "path mismatch",
    "operatorBundlePath is missing",
  ];
  for (const snippet of disallowedSignals) {
    if (stderr.includes(snippet)) {
      throw new Error(`Unexpected non-external blocker present: ${snippet}`);
    }
  }

  console.log(JSON.stringify({
    service: "flowmemory-agent-bonds-public-launch-blockers",
    approvalPath: resolve(root, approvalPath),
    pilotConfigPath: resolve(root, pilotConfigPath),
    status: "external-only-blockers-confirmed",
    ok: true,
  }, null, 2));
}

main();
