import { ShieldCheck, BrainCircuit, PlayCircle, GitBranch } from "lucide-react";

import { EmptyState } from "../components/EmptyState";
import { HashValue } from "../components/HashValue";
import { ProvenanceLine } from "../components/ProvenanceLine";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import type { BaseAgentMemoryScoutRecord, DashboardData } from "../data/types";

function asScoutRecords(data: DashboardData): BaseAgentMemoryScoutRecord[] {
  return data.baseAgentMemoryScouts;
}

export function BaseAgentMemoryView({ data }: { data: DashboardData }) {
  const scouts = asScoutRecords(data);

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="base-native agent memory"
        title="On-Chain Task Scout"
        detail="Fixture-backed local/test proof that a bounded Base agent can preview a deterministic action, commit memory, and expose replayable state."
      />

      {scouts.length === 0 ? (
        <EmptyState title="No task-scout fixture loaded" detail="Run npm run flowmemory:agent-memory:local or npm run launch:v0 to generate the Base agent-memory fixture bundle." />
      ) : (
        scouts.map((scout) => (
          <section className="overview-grid" key={scout.id}>
            <div className="panel panel-wide">
              <div className="panel-heading">
                <div>
                  <BrainCircuit size={18} aria-hidden="true" />
                  <h2>Agent memory root and identity</h2>
                </div>
                <StatusBadge status={scout.status as never} compact />
              </div>
              <div className="record-list">
                <article className="record-row">
                  <div>
                    <div className="record-title">
                      <HashValue value={scout.agentId} label="agent id" />
                    </div>
                    <p>
                      Rootfield <HashValue value={scout.rootfieldId} trim="short" /> now points at latest memory root <HashValue value={scout.latestMemoryRoot} trim="short" /> after sequence {scout.sequence}.
                    </p>
                    <ProvenanceLine provenance={scout.provenance} lastUpdated={scout.lastUpdated} />
                  </div>
                  <dl className="record-facts">
                    <div>
                      <dt>view</dt>
                      <dd><HashValue value={scout.viewId} trim="short" /></dd>
                    </div>
                    <div>
                      <dt>local only</dt>
                      <dd>{scout.localOnly ? "true" : "false"}</dd>
                    </div>
                    <div>
                      <dt>verified memory</dt>
                      <dd>{scout.verifiedMemoryCount}</dd>
                    </div>
                    <div>
                      <dt>pending memory</dt>
                      <dd>{scout.pendingMemoryCount}</dd>
                    </div>
                    <div>
                      <dt>failed memory</dt>
                      <dd>{scout.failedMemoryCount}</dd>
                    </div>
                  </dl>
                </article>
              </div>
            </div>

            <div className="panel">
              <div className="panel-heading">
                <div>
                  <PlayCircle size={18} aria-hidden="true" />
                  <h2>Preview and step</h2>
                </div>
                <span>{scout.action}</span>
              </div>
              <div className="compact-list">
                <article>
                  <StatusBadge status={scout.status as never} compact />
                  <div>
                    <strong>Preview hash</strong>
                    <small><HashValue value={scout.previewHash} trim="short" /></small>
                  </div>
                </article>
                <article>
                  <StatusBadge status="verified" compact />
                  <div>
                    <strong>Reason code</strong>
                    <small>{scout.reasonCode}</small>
                  </div>
                </article>
                <article>
                  <StatusBadge status="verified" compact />
                  <div>
                    <strong>Action receipt</strong>
                    <small><HashValue value={scout.actionReceiptId} trim="short" /></small>
                  </div>
                </article>
              </div>
            </div>

            <div className="panel panel-wide">
              <div className="panel-heading">
                <div>
                  <GitBranch size={18} aria-hidden="true" />
                  <h2>Replay and memory transition</h2>
                </div>
                <span>{scout.checksPassed}/{scout.checksTotal} checks</span>
              </div>
              <div className="record-list">
                <article className="record-row">
                  <div>
                    <div className="record-title">
                      <StatusBadge status={scout.status as never} compact />
                      <strong>Replay path is deterministic</strong>
                    </div>
                    <p>
                      Memory delta <HashValue value={scout.memoryDeltaId} trim="short" /> and verifier report <HashValue value={scout.verifierReportId} trim="short" /> explain why this task scout accepted the task and updated memory.
                    </p>
                    <ProvenanceLine provenance={scout.provenance} lastUpdated={scout.lastUpdated} />
                  </div>
                  <dl className="record-facts">
                    <div>
                      <dt>checks passed</dt>
                      <dd>{scout.checksPassed}</dd>
                    </div>
                    <div>
                      <dt>checks total</dt>
                      <dd>{scout.checksTotal}</dd>
                    </div>
                    <div>
                      <dt>warnings</dt>
                      <dd>{scout.replayWarnings.length === 0 ? "none" : scout.replayWarnings.join(", ")}</dd>
                    </div>
                  </dl>
                </article>
              </div>
            </div>

            <div className="panel">
              <div className="panel-heading">
                <div>
                  <ShieldCheck size={18} aria-hidden="true" />
                  <h2>Why this matters</h2>
                </div>
              </div>
              <ul className="bullet-list">
                <li>`eth_call` previewable next step through the fixture preview hash.</li>
                <li>Public compact memory root instead of hidden gateway-only mutable memory.</li>
                <li>Replayable receipt, memory delta, and verifier report path.</li>
                <li>Bounded task-scout action space instead of unrestricted agent execution.</li>
              </ul>
            </div>
          </section>
        ))
      )}
    </div>
  );
}
