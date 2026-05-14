import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "../../..");
const destinationDir = resolve(repoRoot, "apps/dashboard/public/data");
const fixtureCopies = [
  {
    label: "dashboard fixture",
    source: resolve(repoRoot, "fixtures/dashboard/flowmemory-dashboard-v0.json"),
    destination: resolve(destinationDir, "flowmemory-dashboard-v0.json"),
  },
  {
    label: "Base canary dashboard fixture",
    source: resolve(repoRoot, "fixtures/dashboard/flowmemory-dashboard-base-canary-v0.json"),
    destination: resolve(destinationDir, "flowmemory-dashboard-base-canary-v0.json"),
  },
  {
    label: "FlowChain local devnet state",
    source: resolve(repoRoot, "fixtures/launch-core/generated/devnet/state.json"),
    destination: resolve(destinationDir, "flowchain-local-devnet-state.json"),
  },
  {
    label: "FlowChain local devnet dashboard state",
    source: resolve(repoRoot, "fixtures/launch-core/generated/devnet/dashboard-state.json"),
    destination: resolve(destinationDir, "flowchain-local-devnet-dashboard-state.json"),
  },
  {
    label: "FlowChain bridge test deposit",
    source: resolve(repoRoot, "fixtures/bridge/base-sepolia-mock-deposit.json"),
    destination: resolve(destinationDir, "flowchain-bridge-test-deposit.json"),
  },
  {
    label: "FlowChain L1 explorer fallback",
    source: resolve(repoRoot, "fixtures/dashboard/flowchain-l1-explorer-fallback.json"),
    destination: resolve(destinationDir, "flowchain-l1-explorer-fallback.json"),
  },
];

mkdirSync(destinationDir, { recursive: true });

for (const fixture of fixtureCopies) {
  if (!existsSync(fixture.source)) {
    throw new Error(`Missing ${fixture.label}: ${fixture.source}`);
  }
  copyFileSync(fixture.source, fixture.destination);
  console.log(`Synced ${fixture.label}: ${fixture.destination}`);
}
