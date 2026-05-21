import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { canonicalJson } from "../../shared/src/index.ts";
import { buildAgentBondFixture, DEFAULT_AGENT_BOND_FIXTURE_PATH } from "./agent-bonds.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const DEFAULT_REPORT_PATH = "fixtures/agent-bonds/replay-report.json";

function writeJson(path: string, value: unknown): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

export function replayAgentBondFixture(
  fixturePath = DEFAULT_AGENT_BOND_FIXTURE_PATH,
  reportPath = DEFAULT_REPORT_PATH,
): { match: boolean; reportPath: string } {
  process.chdir(REPO_ROOT);
  const committed = canonicalJson(JSON.parse(readFileSync(fixturePath, "utf8")) as Record<string, unknown>);
  const regenerated = canonicalJson(buildAgentBondFixture() as unknown as Record<string, unknown>);
  const match = committed === regenerated;
  writeJson(reportPath, {
    schema: "flowmemory.agent_bonds.replay_report.v1",
    fixturePath,
    match,
    checkedAt: new Date().toISOString(),
  });
  if (!match) {
    throw new Error(`Agent Bonds fixture replay mismatch for ${fixturePath}`);
  }
  return { match, reportPath: resolve(reportPath) };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const result = replayAgentBondFixture(process.argv[2] ?? DEFAULT_AGENT_BOND_FIXTURE_PATH, process.argv[3] ?? DEFAULT_REPORT_PATH);
  console.log(JSON.stringify({ service: "flowmemory-agent-bonds-replay", ...result }, null, 2));
}
