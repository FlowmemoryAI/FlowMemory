import assert from "node:assert/strict";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
process.chdir(REPO_ROOT);

function runNodeScript(args: string[]): { status: number | null; stdout: string; stderr: string } {
  const result = spawnSync("node", args, {
    cwd: REPO_ROOT,
    encoding: "utf8",
  });
  return {
    status: result.status,
    stdout: result.stdout,
    stderr: result.stderr,
  };
}

test("owner input materializer writes launch packet scaffolding from one file", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-agent-bonds-materialize-"));
  const pilotConfigPath = join(dir, "pilot-config.json");
  const externalReviewPath = join(dir, "external-review.json");
  const operatorSeparationPath = join(dir, "operator-separation.json");
  const runtimeEvidencePath = join(dir, "runtime-evidence.json");
  const goNoGoPath = join(dir, "go-no-go.json");
  const launchApprovalPath = join(dir, "launch-approval.json");

  const result = runNodeScript([
    "infra/scripts/agent-bonds-owner-inputs-materialize.mjs",
    "fixtures/agent-bonds/owner-inputs.template.json",
    pilotConfigPath,
    externalReviewPath,
    operatorSeparationPath,
    runtimeEvidencePath,
    goNoGoPath,
    launchApprovalPath,
  ]);

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /flowmemory-agent-bonds-owner-inputs-materialize/);

  const pilotConfig = JSON.parse(readFileSync(pilotConfigPath, "utf8")) as Record<string, unknown>;
  const launchApproval = JSON.parse(readFileSync(launchApprovalPath, "utf8")) as Record<string, unknown>;
  const externalReview = JSON.parse(readFileSync(externalReviewPath, "utf8")) as Record<string, unknown>;

  assert.equal(pilotConfig.schema, "flowmemory.agent_bonds_pilot_config.v1");
  assert.equal(launchApproval.schema, "flowmemory.agent_bonds_launch_approval.v1");
  assert.equal(externalReview.schema, "flowmemory.agent_bonds_external_review_attestation.v1");
  assert.equal((launchApproval.externalReview as Record<string, unknown>).reviewer, (externalReview.reviewer as string));
  assert.equal((launchApproval.externalReview as Record<string, unknown>).completed, false);
});
