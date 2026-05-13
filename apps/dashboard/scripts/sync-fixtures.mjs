import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "../../..");
const destinationDir = resolve(repoRoot, "apps/dashboard/public/data");
const fixtures = [
  "flowmemory-dashboard-v0.json",
  "flowmemory-dashboard-base-canary-v0.json",
];

mkdirSync(destinationDir, { recursive: true });

for (const fixture of fixtures) {
  const source = resolve(repoRoot, "fixtures/dashboard", fixture);
  const destination = resolve(destinationDir, fixture);
  if (existsSync(source)) {
    copyFileSync(source, destination);
    console.log(`Synced dashboard fixture: ${destination}`);
  }
}
