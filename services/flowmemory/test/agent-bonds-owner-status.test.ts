import assert from "node:assert/strict";
import { resolve, dirname } from "node:path";
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

test("owner-input status reports discovered live address matches and unresolved fields", () => {
  const result = runNodeScript([
    "infra/scripts/agent-bonds-owner-inputs-status.mjs",
    "fixtures/agent-bonds/owner-inputs.canary-reference.json",
    "fixtures/agent-bonds/discovered-live-references.json",
  ]);

  assert.equal(result.status, 0, result.stderr);
  const payload = JSON.parse(result.stdout) as Record<string, unknown>;
  assert.equal(payload.service, "flowmemory-agent-bonds-owner-inputs-status");
  assert.equal(payload.knownLiveAddress, "0x3A6fBA5a78216ba3a8DA8d8F501dee2C8186aFf9");
  assert.ok(Array.isArray(payload.knownReferenceMatches));
  assert.ok((payload.knownReferenceMatches as string[]).length >= 1);
  assert.ok((payload.counts as Record<string, unknown>).unresolved as number > 0);
});
