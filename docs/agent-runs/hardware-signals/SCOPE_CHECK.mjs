import { execFileSync } from "node:child_process";

function gitLines(args) {
  const output = execFileSync("git", args, { encoding: "utf8" }).trim();
  return output ? output.split(/\r?\n/) : [];
}

const changed = [
  ...gitLines(["diff", "--name-only"]),
  ...gitLines(["diff", "--cached", "--name-only"]),
  ...gitLines(["ls-files", "--others", "--exclude-standard"]),
].filter((filePath, index, allPaths) => allPaths.indexOf(filePath) === index).sort();

const allowedPrefixes = [
  "hardware/",
  "fixtures/hardware/",
  "docs/agent-runs/hardware-signals/",
];

const allowedExact = new Set([
  "schemas/flowmemory/hardware-control-plane-handoff.schema.json",
]);

const forbidden = changed.filter(
  (filePath) => !allowedExact.has(filePath) && !allowedPrefixes.some((prefix) => filePath.startsWith(prefix)),
);

if (forbidden.length > 0) {
  console.error("out-of-scope changed files:");
  for (const filePath of forbidden) {
    console.error(`- ${filePath}`);
  }
  process.exit(1);
}

console.log(`changed-file scope ok: ${changed.length} paths`);
