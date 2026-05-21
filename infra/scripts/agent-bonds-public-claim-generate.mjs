#!/usr/bin/env node
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { buildPublicClaimPackage } from "../../services/flowmemory/src/agent-bonds-public-claim.ts";
const claim = buildPublicClaimPackage({ claimLevel: process.argv[2] ?? "integration_beta" });
const outPath = resolve(`fixtures/agent-bonds/claims/generated-${claim.claimLevel}.json`);
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, `${JSON.stringify(claim, null, 2)}
`);
console.log(JSON.stringify({ service: "flowmemory-agent-bonds-public-claim-generate", outPath, enabled: claim.enabled, claimLevel: claim.claimLevel }, null, 2));
