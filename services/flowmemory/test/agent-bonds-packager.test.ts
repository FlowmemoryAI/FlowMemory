import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
process.chdir(REPO_ROOT);
const READINESS_REPORT_PATH = resolve(REPO_ROOT, "local-runtime/local/agent-bonds-readiness/agent-bonds-readiness-report.json");

const maybeMetaTest = process.env.FLOWMEMORY_SKIP_AGENT_BONDS_META === "1" ? test.skip : test;


function seedGreenReadinessReport(): void {
  mkdirSync(dirname(READINESS_REPORT_PATH), { recursive: true });
  writeFileSync(READINESS_REPORT_PATH, JSON.stringify({ schema: "flowmemory.agent_bonds.readiness_report.v1", ok: true, steps: [] }, null, 2));
}

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


maybeMetaTest("public launch packager reports owner-input blockers for the template file", () => {
  const result = runNodeScript([
    "infra/scripts/agent-bonds-public-launch-package.mjs",
    "fixtures/agent-bonds/owner-inputs.template.json",
    "fixtures/agent-bonds/generated",
  ]);

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /blocked_owner_inputs/);
  assert.match(result.stdout, /must be a real deployed address/);
});

maybeMetaTest("public launch packager builds generated packet and reports external-signoff block", () => {
  seedGreenReadinessReport();
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-agent-bonds-packager-"));
  const ownerInputsPath = join(dir, "owner-inputs.json");
  const outputPrefix = join(dir, "generated");

  writeFileSync(ownerInputsPath, JSON.stringify({
    schema: "flowmemory.agent_bonds_owner_inputs.v1",
    network: {
      chainId: 8453,
      networkName: "base-mainnet-capped-pilot"
    },
    contracts: {
      settlementToken: "0x1111111111111111111111111111111111111111",
      stakeToken: "0x2222222222222222222222222222222222222222",
      escrow: "0x3333333333333333333333333333333333333333",
      stakeRegistry: "0x4444444444444444444444444444444444444444",
      policyRegistry: "0x5555555555555555555555555555555555555555",
      manager: "0x6666666666666666666666666666666666666666",
      multisig: "0x7777777777777777777777777777777777777777"
    },
    roles: {
      multisigOwners: [
        "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        "0xcccccccccccccccccccccccccccccccccccccccc"
      ],
      threshold: 2,
      pauseGuardian: "0xdddddddddddddddddddddddddddddddddddddddd",
      resolutionAuthority: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
      designatedVerifier: "0xffffffffffffffffffffffffffffffffffffffff",
      confirmingVerifier: "0x9999999999999999999999999999999999999999",
      requester: "0x1234567890123456789012345678901234567890",
      agent: "0x0987654321098765432109876543210987654321"
    },
    caps: {
      maxPayoutPerTask: "100000000",
      maxOpenExposure: "160000000",
      maxOpenTasks: 1
    },
    policy: {
      requiredConfirmations: 1,
      minAvailabilityWindowSeconds: 86400
    },
    signoffs: {
      externalReviewer: "Independent Reviewer LLC",
      ownerSigner: "Owner Signoff",
      runtimeOperator: "Runtime Operator",
      goNoGoOwner: "Owner"
    }
  }, null, 2));

  const result = runNodeScript([
    "infra/scripts/agent-bonds-public-launch-package.mjs",
    ownerInputsPath,
    outputPrefix,
  ]);

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /blocked_external_signoff/);
  assert.match(result.stdout, /launch-approval\.json/);
});
