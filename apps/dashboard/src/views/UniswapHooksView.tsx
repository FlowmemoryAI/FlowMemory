import { Activity, ArrowRight, Boxes, ExternalLink, GitBranch, RadioReceiver, ShieldAlert, ShieldCheck } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { HashValue } from "../components/HashValue";
import { StatusBadge } from "../components/StatusBadge";
import { formatDateTime } from "../data/format";
import type { DashboardData, MemorySignal } from "../data/types";

const BASESCAN_URL = "https://basescan.org";
const HOOK_URI = "flowmemory://uniswap-v4/after-swap";

function isHookSignal(signal: MemorySignal): boolean {
  return signal.signalType === "swap_memory_signal" || signal.uri === HOOK_URI;
}

function basescanAddressUrl(address: string): string {
  return `${BASESCAN_URL}/address/${address}`;
}

function basescanTxUrl(txHash: string): string {
  return `${BASESCAN_URL}/tx/${txHash}`;
}

export function UniswapHooksView({ data }: { data: DashboardData }) {
  const canary = data.metadata.canary;
  const hookContract = canary?.contracts.find((contract) => contract.name.includes("Hook"));
  const hookSignals = data.memorySignals.filter(isHookSignal);
  const hookObservations = data.flowPulseObservations.filter((observation) => observation.uri === HOOK_URI);
  const uniqueTransactions = new Set(hookObservations.map((observation) => observation.txHash)).size;
  const latestHookObservation = [...hookObservations].sort((left, right) => Number(right.blockNumber) - Number(left.blockNumber))[0];

  return (
    <div className="hooks-public-page">
      <header className="hooks-public-nav" aria-label="FlowMemory hooks navigation">
        <a className="hooks-brand" href="/">
          <span className="hooks-brand-mark" aria-hidden="true">
            <GitBranch size={22} />
          </span>
          <span>
            <strong>FlowMemory</strong>
            <small>Uniswap V4 hooks</small>
          </span>
        </a>
        <nav>
          <a href="/canary">Base canary</a>
          <a href="#signals">Signals</a>
          <a href="#path">Path</a>
          <a href="/">Workbench</a>
        </nav>
      </header>

      <main className="hooks-public-main">
        <section className="hooks-hero" aria-label="Uniswap V4 hook public summary">
          <div className="hooks-hero-copy">
            <span className="eyebrow">first public surface</span>
            <h1>Uniswap V4 afterSwap hooks for FlowMemory</h1>
            <p>
              The hook path turns swap activity into FlowPulse memory signals that can be indexed, verified,
              and followed through Rootflow without custody, dynamic fees, or receipt metadata assumptions inside the hook.
            </p>
            <div className="hooks-action-row">
              <a href="#signals">
                Inspect afterSwap signals
                <ArrowRight size={16} aria-hidden="true" />
              </a>
              {hookContract ? (
                <a href={basescanAddressUrl(hookContract.address)} target="_blank" rel="noreferrer">
                  Base contract
                  <ExternalLink size={16} aria-hidden="true" />
                </a>
              ) : null}
            </div>
          </div>

          <div className="hooks-signal-board" aria-label="afterSwap signal route">
            <div className="hooks-board-header">
              <StatusBadge status={hookSignals.length > 0 ? "observed" : "pending"} compact />
              <span>{data.chain.name}</span>
            </div>
            <div className="hooks-flow-line">
              <article>
                <strong>Swap</strong>
                <small>Pool activity</small>
              </article>
              <ArrowRight size={18} aria-hidden="true" />
              <article>
                <strong>afterSwap</strong>
                <small>Hook callback</small>
              </article>
              <ArrowRight size={18} aria-hidden="true" />
              <article>
                <strong>FlowPulse</strong>
                <small>Memory signal</small>
              </article>
            </div>
            <dl className="hooks-board-facts">
              <div>
                <dt>permission target</dt>
                <dd>afterSwap only</dd>
              </div>
              <div>
                <dt>hook delta</dt>
                <dd>zero return delta</dd>
              </div>
              <div>
                <dt>custody</dt>
                <dd>none</dd>
              </div>
              <div>
                <dt>receipt metadata</dt>
                <dd>indexed after execution</dd>
              </div>
            </dl>
          </div>
        </section>

        <section className="hooks-metric-grid" aria-label="Uniswap V4 hook metrics">
          <article>
            <span>afterSwap signals</span>
            <strong>{hookSignals.length}</strong>
            <small>{uniqueTransactions} Base transaction{uniqueTransactions === 1 ? "" : "s"}</small>
          </article>
          <article>
            <span>read window</span>
            <strong>{canary?.readWindow.fromBlock ?? "unknown"}-{canary?.readWindow.toBlock ?? "unknown"}</strong>
            <small>finalized {canary?.readWindow.finalizedBlock ?? data.chain.finalizedBlock}</small>
          </article>
          <article>
            <span>current contract</span>
            <strong>{hookContract?.name ?? "pending"}</strong>
            <small>{hookContract ? "Base canary adapter" : "contract metadata missing"}</small>
          </article>
          <article>
            <span>production gate</span>
            <strong>{canary?.productionReady ? "ready" : "gated"}</strong>
            <small>PoolManager hook deployment is separate</small>
          </article>
        </section>

        <section className="hooks-public-grid">
          <article className="hooks-panel hooks-panel-wide">
            <div className="hooks-panel-heading">
              <div>
                <RadioReceiver size={18} aria-hidden="true" />
                <h2>Public canary evidence</h2>
              </div>
              <span>{formatDateTime(data.metadata.generatedAt)}</span>
            </div>
            <div className="hooks-contract-strip">
              <div>
                <span>chain</span>
                <strong>{data.chain.chainId}</strong>
                <small>{data.chain.environment}</small>
              </div>
              <div>
                <span>contract</span>
                <strong>{hookContract?.name ?? "unknown"}</strong>
                {hookContract ? <HashValue value={hookContract.address} trim="medium" /> : <small>not found</small>}
              </div>
              <div>
                <span>deployed block</span>
                <strong>{hookContract?.block ?? "unknown"}</strong>
                {hookContract ? <HashValue value={hookContract.deployTx} trim="short" /> : <small>no deploy tx</small>}
              </div>
            </div>
          </article>

          <article className="hooks-panel">
            <div className="hooks-panel-heading">
              <div>
                <ShieldCheck size={18} aria-hidden="true" />
                <h2>Hook guarantees</h2>
              </div>
              <span>contract path</span>
            </div>
            <div className="hooks-guarantee-list">
              <span>PoolManager-gated afterSwap candidate</span>
              <span>No token custody or fee override</span>
              <span>FlowPulse event is the public memory boundary</span>
              <span>Transaction hash and log index come from the indexer</span>
            </div>
          </article>

          <article className="hooks-panel">
            <div className="hooks-panel-heading">
              <div>
                <ShieldAlert size={18} aria-hidden="true" />
                <h2>Launch boundary</h2>
              </div>
              <span>honest status</span>
            </div>
            <div className="hooks-boundary-list">
              {(canary?.boundaries ?? ["Production hook deployment remains gated."]).map((boundary) => (
                <span key={boundary}>{boundary}</span>
              ))}
            </div>
          </article>
        </section>

        <section className="hooks-panel hooks-panel-wide" id="signals">
          <div className="hooks-panel-heading">
            <div>
              <Activity size={18} aria-hidden="true" />
              <h2>Observed afterSwap memory signals</h2>
            </div>
            <span>{hookObservations.length} observations</span>
          </div>
          {hookObservations.length > 0 ? (
            <div className="hooks-observation-list">
              {hookObservations.map((observation) => (
                <article key={observation.observationId}>
                  <div className="hooks-observation-main">
                    <StatusBadge status={observation.status} compact />
                    <div>
                      <strong>{observation.summary}</strong>
                      <small>{observation.uri}</small>
                    </div>
                  </div>
                  <dl>
                    <div>
                      <dt>block</dt>
                      <dd>{observation.blockNumber}</dd>
                    </div>
                    <div>
                      <dt>tx</dt>
                      <dd>
                        <a href={basescanTxUrl(observation.txHash)} target="_blank" rel="noreferrer">
                          <HashValue value={observation.txHash} trim="short" />
                          <ExternalLink size={13} aria-hidden="true" />
                        </a>
                      </dd>
                    </div>
                    <div>
                      <dt>pulse</dt>
                      <dd>
                        <HashValue value={observation.pulseId} trim="short" />
                      </dd>
                    </div>
                    <div>
                      <dt>commitment</dt>
                      <dd>
                        <HashValue value={observation.commitment} trim="short" />
                      </dd>
                    </div>
                    <div>
                      <dt>log</dt>
                      <dd>{observation.logIndex}</dd>
                    </div>
                  </dl>
                </article>
              ))}
            </div>
          ) : (
            <EmptyState title="No afterSwap signals" detail="Regenerate the Base canary fixture after the guarded reader observes hook activity." />
          )}
        </section>

        <section className="hooks-live-path" id="path" aria-label="Path to live Uniswap V4 hook">
          <div>
            <span className="eyebrow">path to live</span>
            <h2>What goes public first</h2>
            <p>
              The public hook surface starts with canary evidence and Base Sepolia planning, then graduates to the real
              afterSwap-only hook address once source verification and owner launch gates are complete.
            </p>
          </div>
          <ol>
            <li>
              <strong>Canary evidence</strong>
              <span>{hookSignals.length} swap memory signals are already represented in committed Base canary data.</span>
            </li>
            <li>
              <strong>Hook candidate</strong>
              <span>FlowMemoryAfterSwapHook and FlowMemoryHookPlanner define the PoolManager-gated path.</span>
            </li>
            <li>
              <strong>Public launch gate</strong>
              <span>Base Sepolia hook broadcast, source verification, and bounded reader evidence remain explicit gates.</span>
            </li>
            <li>
              <strong>First live route</strong>
              <span>After the gate clears, this route becomes the public status surface for hook signals.</span>
            </li>
          </ol>
        </section>

        <section className="hooks-panel hooks-panel-wide">
          <div className="hooks-panel-heading">
            <div>
              <Boxes size={18} aria-hidden="true" />
              <h2>Latest signal payload</h2>
            </div>
            <span>{latestHookObservation ? "available" : "empty"}</span>
          </div>
          {latestHookObservation ? (
            <pre className="hooks-json-preview">{JSON.stringify(latestHookObservation, null, 2)}</pre>
          ) : (
            <EmptyState title="No signal payload" detail="Hook observation payload will appear after a canary reader run." />
          )}
        </section>
      </main>
    </div>
  );
}
