import { ShieldCheck, Wallet, Workflow } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { HashValue } from "../components/HashValue";
import { ProvenanceLine } from "../components/ProvenanceLine";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import type { DashboardData } from "../data/types";

export function AgentBondsView({ data }: { data: DashboardData }) {
  const gate = data.agentBondPhase2Gate;
  const passport = data.agentBondPassports[0];
  const envelope = data.bondedTaskEnvelopes.find((entry) => entry.taskClass === "data.extract") ?? data.bondedTaskEnvelopes[0];
  const decision = data.agentBondRecourseDecisions[0];
  const waterfall = data.agentBondFailureWaterfalls[0];
  const policy = data.agentBondRecoursePolicies[0];

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="agent bonds"
        title="Requester-facing API/data pilot"
        detail="The narrow pilot wedge is objective API/data work with escrow, verifier receipts, optional recourse, and machine-readable failure waterfalls."
      />

      <section className="metric-grid" aria-label="Agent Bonds Phase 2 readiness">
        <article className="metric-tile">
          <span>Phase 2 gate</span>
          <strong>{gate.foundationReady ? "Ready" : "Blocked"}</strong>
          <div>
            <StatusBadge status={gate.foundationReady ? "verified" : "unresolved"} compact />
            <small>Passport / Envelope / Receipt required</small>
          </div>
        </article>
        <article className="metric-tile">
          <span>Recourse policy</span>
          <strong>{policy ? policy.taskClasses.join(", ") : "none"}</strong>
          <div>
            <StatusBadge status={policy ? "verified" : "stale"} compact />
            <small>low-risk API/data task scope</small>
          </div>
        </article>
        <article className="metric-tile">
          <span>Decision</span>
          <strong>{decision?.decisionStatus ?? "missing"}</strong>
          <div>
            <StatusBadge status={decision?.decisionStatus === "approved" ? "verified" : "pending"} compact />
            <small>recourse quote result</small>
          </div>
        </article>
        <article className="metric-tile">
          <span>Waterfall</span>
          <strong>{waterfall?.terminalState ?? "missing"}</strong>
          <div>
            <StatusBadge status={waterfall ? "verified" : "stale"} compact />
            <small>explicit refund / slash / recourse split</small>
          </div>
        </article>
      </section>

      <div className="overview-grid">
        <div className="panel panel-wide">
          <div className="panel-heading">
            <div>
              <Wallet size={18} aria-hidden="true" />
              <h2>Requester quote flow</h2>
            </div>
            <span>{envelope ? envelope.taskClass : "no envelope"}</span>
          </div>
          {envelope && decision && policy ? (
            <div className="record-list">
              <article className="record-row">
                <div>
                  <div className="record-title">
                    <StatusBadge status={decision.decisionStatus === "approved" ? "verified" : "pending"} compact />
                    <strong>{envelope.taskClass}</strong>
                  </div>
                  <p>{passport?.displayName ?? "Agent"} can be quoted for this template through a canonical Bonded Task Envelope.</p>
                  <ProvenanceLine provenance={envelope.provenance} lastUpdated={envelope.lastUpdated} />
                </div>
                <dl className="record-facts">
                  <div>
                    <dt>Envelope</dt>
                    <dd><HashValue value={envelope.envelopeHash} trim="short" /></dd>
                  </div>
                  <div>
                    <dt>Payout</dt>
                    <dd>{envelope.payoutUSDC} USDC units</dd>
                  </div>
                  <div>
                    <dt>Funding</dt>
                    <dd>{envelope.fundingMode}</dd>
                  </div>
                  <div>
                    <dt>Coverage</dt>
                    <dd>{decision.approvedCoverageUSDC} USDC units</dd>
                  </div>
                  <div>
                    <dt>Premium</dt>
                    <dd>{decision.premiumUSDC} USDC units</dd>
                  </div>
                  <div>
                    <dt>Reasons</dt>
                    <dd>{decision.reasonCodes.join(", ")}</dd>
                  </div>
                  <div>
                    <dt>Policy attestation</dt>
                    <dd>{decision.policyAttestationId ? <HashValue value={decision.policyAttestationId} trim="short" /> : "required"}</dd>
                  </div>
                </dl>
              </article>
            </div>
          ) : (
            <EmptyState title="No API/data pilot quote" detail="Generate launch fixtures to project the API/data pilot quote flow." />
          )}
        </div>

        <div className="panel">
          <div className="panel-heading">
            <div>
              <Workflow size={18} aria-hidden="true" />
              <h2>Failure waterfall</h2>
            </div>
            <span>{waterfall?.terminalState ?? "no failure model"}</span>
          </div>
          {waterfall ? (
            <div className="record-list compact-list">
              <article className="record-row">
                <div>
                  <div className="record-title">
                    <StatusBadge status="failed" compact />
                    <HashValue value={waterfall.waterfallId} trim="short" label="waterfall" />
                  </div>
                  <p>Requester refund, slash, and optional recourse are represented as separate components instead of one opaque payout.</p>
                  <ProvenanceLine provenance={waterfall.provenance} lastUpdated={waterfall.lastUpdated} />
                </div>
                <dl className="record-facts">
                  <div>
                    <dt>Requester total</dt>
                    <dd>{waterfall.toRequesterUSDC} USDC units</dd>
                  </div>
                  <div>
                    <dt>Recourse</dt>
                    <dd>{waterfall.recourseUSDC} USDC units</dd>
                  </div>
                  <div>
                    <dt>Slashed</dt>
                    <dd>{waterfall.slashedUSDC} USDC units</dd>
                  </div>
                </dl>
              </article>
            </div>
          ) : (
            <EmptyState title="No waterfall projected" detail="Failure waterfall artifacts are missing from the current dashboard payload." />
          )}
        </div>

        <div className="panel panel-wide">
          <div className="panel-heading">
            <div>
              <ShieldCheck size={18} aria-hidden="true" />
              <h2>Boundary reminders</h2>
            </div>
            <span>claim guardrails</span>
          </div>
          <ul className="compact-checklist">
            <li>Optional USDC recourse is task-scoped and capped by approved locked coverage.</li>
            <li>Project-token stake and USDC recourse are separate economic layers.</li>
            <li>Recourse is not insurance and does not guarantee reimbursement.</li>
            <li>Broad public launch remains blocked by default even when the technical gate is green.</li>
          </ul>
        </div>
      </div>
    </div>
  );
}
