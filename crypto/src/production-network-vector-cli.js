#!/usr/bin/env node
import { writeFileSync } from "node:fs";

import { buildProductionNetworkVectors } from "./production-network-vectors.js";

const args = parseArgs(process.argv.slice(2));
const vectors = await buildProductionNetworkVectors();
const serialized = `${JSON.stringify(vectors, null, 2)}\n`;

if (args.out) {
  writeFileSync(args.out, serialized);
} else {
  process.stdout.write(serialized);
}

function parseArgs(argv) {
  const parsed = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith("--")) {
      continue;
    }
    const key = arg.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith("--")) {
      parsed[key] = true;
    } else {
      parsed[key] = next;
      i += 1;
    }
  }
  return parsed;
}
