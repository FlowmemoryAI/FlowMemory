#!/usr/bin/env node
import { cpSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const OUT_DIR = resolve(REPO_ROOT, "out/agent-bonds-operator-bundle");

const FILES = [
  "fixtures/agent-bonds/agent-bonds-v1.json",
  "fixtures/agent-bonds/replay-report.json",
  "fixtures/agent-bonds/economic-sim-report.json",
  "fixtures/agent-bonds/discovered-live-references.json",
  "fixtures/agent-bonds/pilot-config.template.json",
  "fixtures/agent-bonds/launch-approval.template.json",
  "fixtures/agent-bonds/owner-inputs.template.json",
  "fixtures/agent-bonds/owner-inputs.canary-reference.json",
  "fixtures/agent-bonds/approvals/external-review.template.json",
  "fixtures/agent-bonds/approvals/operator-separation.template.json",
  "fixtures/agent-bonds/approvals/runtime-evidence.template.json",
  "fixtures/agent-bonds/approvals/go-no-go.template.json",
  "fixtures/agent-bonds/approvals/README.md",
  "schemas/flowmemory/agent-bonds-launch-approval.schema.json",
  "schemas/flowmemory/agent-bonds-external-review-attestation.schema.json",
  "schemas/flowmemory/agent-bonds-operator-separation-attestation.schema.json",
  "schemas/flowmemory/agent-bonds-runtime-evidence-attestation.schema.json",
  "schemas/flowmemory/agent-bonds-go-no-go-attestation.schema.json",
  "schemas/flowmemory/agent-bonds-owner-inputs.schema.json",
  "infra/scripts/agent-bonds-public-launch-assemble.mjs",
  "infra/scripts/agent-bonds-owner-inputs-validate.mjs",
  "devnet/local/agent-bonds-readiness/agent-bonds-readiness-report.json",
  "devnet/local/agent-bonds-readiness/goal-audit-report.json",
  "docs/AGENT_BONDS_PUBLIC_LAUNCH_BOUNDARY.md",
  "docs/OPERATIONS/AGENT_BONDS_CAPPED_PILOT_RUNBOOK.md",
  "docs/OPERATIONS/AGENT_BONDS_MONITORING_AND_RECOVERY.md",
  "docs/OPERATIONS/AGENT_BONDS_PILOT_CONFIG.md",
  "docs/OPERATIONS/AGENT_BONDS_DEPLOYMENT.md",
  "docs/OPERATIONS/AGENT_BONDS_EXTERNAL_REVIEW_PACKET.md",
  "docs/OPERATIONS/AGENT_BONDS_DISCOVERED_LIVE_REFERENCES.md",
  "docs/OPERATIONS/AGENT_BONDS_OPERATOR_SEPARATION_CHECKLIST.md",
  "docs/OPERATIONS/AGENT_BONDS_PUBLIC_LAUNCH_APPROVAL.md",
  "docs/OPERATIONS/AGENT_BONDS_OWNER_INPUTS.md",
  "docs/reviews/AGENT_BONDS_V1_SECURITY_REVIEW.md",
  "docs/reviews/AGENT_BONDS_READINESS_AUDIT.md",
  "docs/reviews/AGENT_BONDS_GOAL_COMPLETION_MATRIX.md",
];

function main() {
  process.chdir(REPO_ROOT);
  mkdirSync(OUT_DIR, { recursive: true });
  const copied = [];
  for (const relativePath of FILES) {
    const source = resolve(REPO_ROOT, relativePath);
    if (!existsSync(source)) {
      throw new Error(`missing bundle file: ${relativePath}`);
    }
    const destination = resolve(OUT_DIR, relativePath);
    mkdirSync(dirname(destination), { recursive: true });
    cpSync(source, destination, { force: true });
    copied.push(relativePath);
  }
  writeFileSync(resolve(OUT_DIR, "README.txt"), [
    "FlowMemory Agent Bonds operator bundle",
    "",
    "1. validate pilot config",
    "2. review readiness report",
    "3. replay fixture",
    "4. review economics report",
    "5. read public boundary and runbooks",
    "6. complete operator separation checklist",
    "7. hand external reviewer the review packet",
    ""
  ].join("\n"), "utf8");
  console.log(JSON.stringify({ service: "flowmemory-agent-bonds-operator-bundle", outDir: OUT_DIR, files: copied.length }, null, 2));
}

main();
