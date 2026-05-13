import { copyFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "../../..");
const source = resolve(repoRoot, "fixtures/dashboard/flowmemory-dashboard-v0.json");
const destinationDir = resolve(repoRoot, "apps/dashboard/public/data");
const destination = resolve(destinationDir, "flowmemory-dashboard-v0.json");

mkdirSync(destinationDir, { recursive: true });
copyFileSync(source, destination);

console.log(`Synced dashboard fixture: ${destination}`);

