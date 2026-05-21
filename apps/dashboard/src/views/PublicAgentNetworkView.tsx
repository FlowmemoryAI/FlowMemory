import { Network, Coins, ShieldCheck, Sparkles } from "lucide-react";

import { SectionHeader } from "../components/SectionHeader";
import {
  PUBLIC_AGENT_CLASSES,
  PUBLIC_AGENT_TOOLS,
  type PublicAgentClassConfig,
  type PublicToolConfig,
} from "../data/publicAgentNetwork";

export function PublicAgentNetworkView() {
  const classes = PUBLIC_AGENT_CLASSES;
  const tools = PUBLIC_AGENT_TOOLS;

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="public launch architecture"
        title="Public Agent Network"
        detail="Current launch-class, token, and swarm-first architecture for the public Base-native FlowMemory agent network."
      />

      <section className="flowmemory-hero" aria-label="Public agent network vision">
        <div className="flowmemory-hero-main">
          <span className="eyebrow">shared runtime first</span>
          <h2>Launch agents into a public Base-native cognitive economy</h2>
          <p>
            Users should launch configured agents from supported classes into the shared FlowMemory runtime first, with token-backed launch seriousness,
            replayable memory roots, and later swarm-capable coordination.
          </p>
        </div>
        <div className="flowmemory-hero-side">
          <div>
            <small>Classes</small>
            <strong>{classes.length}</strong>
          </div>
          <div>
            <small>Tools</small>
            <strong>{tools.length}</strong>
          </div>
          <div>
            <small>Mode</small>
            <strong>local/test planning</strong>
          </div>
        </div>
      </section>

      <section className="overview-grid">
        <div className="panel panel-wide">
          <div className="panel-heading">
            <div>
              <Sparkles size={18} aria-hidden="true" />
              <h2>Public launch classes</h2>
            </div>
            <span>{classes.length} classes</span>
          </div>
          <div className="record-list">
            {classes.map((entry: PublicAgentClassConfig) => (
              <article className="record-row" key={entry.classId}>
                <div>
                  <div className="record-title">
                    <strong>{entry.className}</strong>
                  </div>
                  <p>
                    kernel {entry.kernelClass} · autonomy {entry.minAutonomyLevel}-{entry.maxAutonomyLevel} · max tool risk {entry.maxToolRiskTier}
                  </p>
                </div>
                <dl className="record-facts">
                  <div>
                    <dt>launch bond</dt>
                    <dd>{entry.minLaunchBond}</dd>
                  </div>
                  <div>
                    <dt>memory fuel</dt>
                    <dd>{entry.minMemoryFuel}</dd>
                  </div>
                  <div>
                    <dt>shell graduation</dt>
                    <dd>{entry.allowShellGraduation ? "yes" : "no"}</dd>
                  </div>
                </dl>
              </article>
            ))}
          </div>
        </div>

        <div className="panel panel-wide">
          <div className="panel-heading">
            <div>
              <ShieldCheck size={18} aria-hidden="true" />
              <h2>Tool universe</h2>
            </div>
            <span>{tools.length} tools</span>
          </div>
          <div className="record-list">
            {tools.map((tool: PublicToolConfig) => (
              <article className="record-row" key={tool.toolId}>
                <div>
                  <div className="record-title">
                    <strong>{tool.toolName}</strong>
                  </div>
                  <p>
                    tool set {tool.toolSetRoot} · risk tier {tool.riskTier}
                  </p>
                </div>
                <dl className="record-facts">
                  <div>
                    <dt>mutating</dt>
                    <dd>{tool.mutating ? "yes" : "no"}</dd>
                  </div>
                  <div>
                    <dt>dry run</dt>
                    <dd>{tool.requiresDryRun ? "yes" : "no"}</dd>
                  </div>
                  <div>
                    <dt>human confirm</dt>
                    <dd>{tool.requiresHumanConfirm ? "yes" : "no"}</dd>
                  </div>
                </dl>
              </article>
            ))}
          </div>
        </div>

        <div className="panel">
          <div className="panel-heading">
            <div>
              <Coins size={18} aria-hidden="true" />
              <h2>Token role</h2>
            </div>
          </div>
          <ul className="bullet-list">
            <li>Launch bond / seriousness filter</li>
            <li>Persistent memory fuel</li>
            <li>Swarm budget fuel</li>
            <li>Reputation-backed risk and stake</li>
          </ul>
        </div>

        <div className="panel">
          <div className="panel-heading">
            <div>
              <Network size={18} aria-hidden="true" />
              <h2>Long-term shape</h2>
            </div>
          </div>
          <ul className="bullet-list">
            <li>Shared runtime first for network effects</li>
            <li>Swarm-native machine organizations next</li>
            <li>Dedicated shells later for premium/high-risk agents</li>
          </ul>
        </div>
      </section>
    </div>
  );
}
