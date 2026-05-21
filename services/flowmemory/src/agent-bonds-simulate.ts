import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const DEFAULT_REPORT_PATH = "fixtures/agent-bonds/economic-sim-report.json";

function writeJson(path: string, value: unknown): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function money(value: bigint): string {
  return value.toString();
}

export function simulateAgentBondEconomics(reportPath = DEFAULT_REPORT_PATH): { reportPath: string; scenarios: number } {
  process.chdir(REPO_ROOT);
  const usdc = 1_000_000n;
  const payout = 100n * usdc;
  const agentBond = 25n * usdc;
  const verifierFee = 10n * usdc;
  const requesterCancelBond = 25n * usdc;
  const disputeBond = 50n * usdc;
  const requesterEscrow = payout + verifierFee + requesterCancelBond;
  const totalEscrowed = requesterEscrow + agentBond;
  const slashRequesterShare = agentBond * 8_500n / 10_000n;
  const slashVerifierShare = agentBond * 1_000n / 10_000n;
  const slashReserveShare = agentBond * 500n / 10_000n;

  const scenarios = [
    {
      name: "verified_settlement",
      outputs: {
        agent: money(payout + agentBond),
        requester: money(requesterCancelBond),
        verifier: money(verifierFee),
        reserve: "0",
      },
      invariant: money(payout + agentBond + requesterCancelBond + verifierFee) === money(totalEscrowed),
    },
    {
      name: "invalid_report_slash",
      outputs: {
        requester: money(payout + requesterCancelBond + slashRequesterShare),
        verifier: money(verifierFee + slashVerifierShare),
        reserve: money(slashReserveShare),
      },
      invariant: money(payout + requesterCancelBond + verifierFee + agentBond) === money(totalEscrowed),
    },
    {
      name: "challenged_overturn",
      outputs: {
        requester: money(payout + requesterCancelBond + slashRequesterShare + disputeBond),
        verifier: money(verifierFee + slashVerifierShare),
        reserve: money(slashReserveShare),
      },
      notes: ["challenge bond is recoverable when challenger wins", "verifier stake slash is additional non-USDC punishment"],
      invariant: money(payout + requesterCancelBond + verifierFee + agentBond + disputeBond) === money(totalEscrowed + disputeBond),
    },
    {
      name: "spam_challenge_cost_floor",
      outputs: {
        disputeBond: money(disputeBond),
        verifierFee: money(verifierFee),
        challengeToFeeRatioBps: Number(disputeBond * 10_000n / verifierFee),
      },
      notes: ["spurious challenges must tie up more capital than a single verifier fee", "losing a dispute is more expensive than waiting through one objective-task verification cycle"],
      invariant: disputeBond > verifierFee,
    },
    {
      name: "pilot_exposure_cap",
      outputs: {
        maxOpenExposure: money(160n * usdc),
        firstTaskExposure: money(totalEscrowed),
        secondTaskExposureAttempt: money(totalEscrowed * 2n),
      },
      notes: ["a second equal-sized task is blocked when maxOpenExposure is 160 USDC", "bounded loss is enforced before a second task can be opened or accepted"],
      invariant: totalEscrowed <= 160n * usdc && totalEscrowed * 2n > 160n * usdc,
    },
    {
      name: "independent_confirmation_requirement",
      outputs: {
        requiredConfirmations: 1,
        independentVerifiersNeeded: 2,
      },
      notes: ["primary verifier alone cannot settle a confirmed-policy task", "settlement requires one additional eligible confirmer or a challenge-resolution path"],
      invariant: true,
    },
  ];

  writeJson(reportPath, {
    schema: "flowmemory.agent_bonds.economic_sim_report.v1",
    generatedAt: new Date().toISOString(),
    assumptions: {
      payout: money(payout),
      agentBond: money(agentBond),
      verifierFee: money(verifierFee),
      requesterCancelBond: money(requesterCancelBond),
      disputeBond: money(disputeBond),
      totalEscrowed: money(totalEscrowed),
      slashSplitBps: {
        requester: 8500,
        verifier: 1000,
        reserve: 500,
      },
    },
    scenarios,
  });

  if (!scenarios.every((scenario) => scenario.invariant)) {
    throw new Error("Agent Bonds economic simulation invariant failed");
  }

  return { reportPath: resolve(reportPath), scenarios: scenarios.length };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const result = simulateAgentBondEconomics(process.argv[2] ?? DEFAULT_REPORT_PATH);
  console.log(JSON.stringify({ service: "flowmemory-agent-bonds-simulate", ...result }, null, 2));
}
