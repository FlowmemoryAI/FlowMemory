#!/usr/bin/env node
import { readJson } from "../../services/flowmemory/src/agent-bonds-phase2-shared.ts";
import { validatePublicClaimPackage } from "../../services/flowmemory/src/agent-bonds-public-claim.ts";
const claim = validatePublicClaimPackage(readJson(process.argv[2] ?? "fixtures/agent-bonds/claims/public-claim.integration-beta.json"));
console.log(JSON.stringify({ service: "flowmemory-agent-bonds-public-claim-validate", claimLevel: claim.claimLevel, enabled: claim.enabled, ok: true }, null, 2));
