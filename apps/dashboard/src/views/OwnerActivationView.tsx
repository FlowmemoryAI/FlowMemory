import { Link } from "react-router-dom";
import {
  ArrowRightLeft,
  CheckCircle2,
  ClipboardCheck,
  HardDrive,
  KeyRound,
  ListChecks,
  Server,
  ShieldAlert,
  Terminal,
  UserPlus,
} from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import type { DashboardStatus } from "../data/types";
import type { WorkbenchSnapshot } from "../data/workbench";

type UnknownRecord = Record<string, unknown>;

interface ActivationStage {
  id: string;
  title: string;
  status: string;
  ready: boolean;
  requiredEnvNames: string[];
  optionalEnvNames: string[];
  missingEnvNames: string[];
  invalidEnvNames: string[];
  externalAccountsOrResources: string[];
  ownerMustDo: string[];
  ownerMustNotSend: string[];
  validationCommands: string[];
}

function isRecord(value: unknown): value is UnknownRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function text(value: unknown, fallback = "not recorded"): string {
  if (value === null || value === undefined || value === "") {
    return fallback;
  }
  return String(value);
}

function stringList(value: unknown): string[] {
  return asArray(value).map((item) => text(item)).filter((item) => item !== "not recorded");
}

function statusFromText(value: unknown, fallback: DashboardStatus = "pending"): DashboardStatus {
  const normalized = text(value, "").toLowerCase();
  if (normalized === "passed" || normalized === "ready" || normalized === "true" || normalized === "verified") {
    return "verified";
  }
  if (normalized === "failed" || normalized === "invalid-owner-input" || normalized === "false") {
    return "failed";
  }
  if (normalized === "needs-owner-input" || normalized === "needs-validation" || normalized === "blocked" || normalized === "pending") {
    return "pending";
  }
  return fallback;
}

function parseStage(value: unknown): ActivationStage | null {
  if (!isRecord(value)) {
    return null;
  }

  return {
    id: text(value.id, "activation-stage"),
    title: text(value.title, "Activation stage"),
    status: text(value.status, "pending"),
    ready: value.ready === true,
    requiredEnvNames: stringList(value.requiredEnvNames),
    optionalEnvNames: stringList(value.optionalEnvNames),
    missingEnvNames: stringList(value.missingEnvNames),
    invalidEnvNames: stringList(value.invalidEnvNames),
    externalAccountsOrResources: stringList(value.externalAccountsOrResources),
    ownerMustDo: stringList(value.ownerMustDo),
    ownerMustNotSend: stringList(value.ownerMustNotSend),
    validationCommands: stringList(value.validationCommands),
  };
}

function stageIcon(id: string) {
  if (id.includes("public-rpc")) return Server;
  if (id.includes("backup")) return HardDrive;
  if (id.includes("tester")) return UserPlus;
  if (id.includes("bridge")) return ArrowRightLeft;
  if (id.includes("audit")) return ShieldAlert;
  if (id.includes("env")) return KeyRound;
  return CheckCircle2;
}

export function OwnerActivationView({ workbench }: { workbench: WorkbenchSnapshot }) {
  const liveReadiness = isRecord(workbench.raw.liveReadinessReport) ? workbench.raw.liveReadinessReport : null;
  const metrics = isRecord(liveReadiness?.metrics) ? liveReadiness.metrics : {};
  const activation = isRecord(liveReadiness?.ownerActivation) ? liveReadiness.ownerActivation : null;
  const stages = asArray(activation?.stages).map(parseStage).filter((stage): stage is ActivationStage => stage !== null);
  const missingEnvNames = stringList(activation?.missingEnvNames);
  const invalidEnvNames = stringList(activation?.invalidEnvNames);
  const requiredOwnerEnvNames = stringList(activation?.requiredOwnerEnvNames);
  const optionalOwnerEnvNames = stringList(activation?.optionalOwnerEnvNames);
  const nextCommands = stringList(activation?.nextCommands);
  const forbiddenItems = stringList(activation?.forbiddenItems);
  const activationReady = activation?.activationReady === true;
  const activationStatus = text(activation?.status ?? metrics.ownerActivationStatus, "not recorded");
  const readyStageCount = text(activation?.readyStageCount ?? metrics.ownerActivationReadyStageCount, "0");
  const stageCount = text(activation?.stageCount ?? metrics.ownerActivationStageCount, String(stages.length));
  const needsInputCount = text(activation?.stagesNeedingOwnerInputCount, "0");
  const noSecrets = activation?.noSecrets === true;
  const envValuesPrinted = activation?.envValuesPrinted === true;
  const broadcasts = activation?.broadcasts === true;

  return (
    <div className="view-stack activation-view">
      <SectionHeader
        eyebrow="go-live activation"
        title="L1 activation"
        detail="Ordered owner setup, validation commands, public RPC, backup, tester gateway, and Base 8453 bridge inputs from the current activation evidence."
        action={
          <div className="workbench-header-actions">
            <Link className="button" to="/tester">
              <UserPlus size={15} aria-hidden="true" />
              Tester launch
            </Link>
            <Link className="button" to="/ops">
              <ShieldAlert size={15} aria-hidden="true" />
              Ops
            </Link>
            <Link className="button" to="/raw">
              <ListChecks size={15} aria-hidden="true" />
              Raw reports
            </Link>
          </div>
        }
      />

      <section className="activation-command-panel" aria-label="L1 activation status">
        <div>
          <span>Activation</span>
          <strong>{activationReady ? "ready" : "blocked"}</strong>
          <small>report {activationStatus}</small>
        </div>
        <div>
          <span>Stages</span>
          <strong>{readyStageCount}/{stageCount}</strong>
          <small>needs input {needsInputCount}</small>
        </div>
        <div>
          <span>Missing inputs</span>
          <strong>{missingEnvNames.length}</strong>
          <small>invalid {invalidEnvNames.length}</small>
        </div>
        <div>
          <span>Chain head</span>
          <strong>{text(metrics.latestHeight)}</strong>
          <small>finalized {text(metrics.finalizedHeight)}</small>
        </div>
        <div>
          <span>Evidence boundary</span>
          <strong>{noSecrets ? "clean" : "review"}</strong>
          <small>values printed {String(envValuesPrinted)} / broadcasts {String(broadcasts)}</small>
        </div>
      </section>

      <section className="activation-layout">
        <div className="activation-main">
          <article className="panel activation-stage-panel">
            <div className="panel-heading">
              <div>
                <ClipboardCheck size={18} aria-hidden="true" />
                <h2>Activation stages</h2>
              </div>
              <StatusBadge status={statusFromText(activationReady ? "ready" : "pending")} compact />
            </div>

            {stages.length > 0 ? (
              <div className="activation-stage-list">
                {stages.map((stage) => {
                  const Icon = stageIcon(stage.id);
                  return (
                    <article key={stage.id} className={`activation-stage activation-stage-${stage.status}`}>
                      <div className="activation-stage-icon">
                        <Icon size={18} aria-hidden="true" />
                      </div>
                      <div className="activation-stage-body">
                        <div className="activation-stage-title">
                          <h3>{stage.title}</h3>
                          <StatusBadge status={statusFromText(stage.status)} compact />
                        </div>
                        <div className="activation-stage-facts">
                          <div>
                            <span>missing</span>
                            <strong>{stage.missingEnvNames.length}</strong>
                          </div>
                          <div>
                            <span>required</span>
                            <strong>{stage.requiredEnvNames.length}</strong>
                          </div>
                          <div>
                            <span>resources</span>
                            <strong>{stage.externalAccountsOrResources.length}</strong>
                          </div>
                        </div>
                        {stage.missingEnvNames.length > 0 ? (
                          <div className="activation-chip-list" aria-label={`${stage.title} missing inputs`}>
                            {stage.missingEnvNames.map((name) => (
                              <code key={`${stage.id}:missing:${name}`}>{name}</code>
                            ))}
                          </div>
                        ) : null}
                        <div className="activation-command-list">
                          {stage.validationCommands.slice(0, 3).map((command) => (
                            <code key={`${stage.id}:command:${command}`}>{command}</code>
                          ))}
                        </div>
                      </div>
                    </article>
                  );
                })}
              </div>
            ) : (
              <EmptyState title="Activation plan missing" detail="Run npm run flowchain:owner:activation-plan, then refresh dashboard fixtures." />
            )}
          </article>
        </div>

        <aside className="activation-side">
          <article className="panel activation-inputs">
            <div className="panel-heading">
              <div>
                <KeyRound size={18} aria-hidden="true" />
                <h2>Owner inputs</h2>
              </div>
              <StatusBadge status={missingEnvNames.length === 0 ? "verified" : "pending"} compact />
            </div>
            <div className="activation-input-grid" aria-label="Missing owner inputs">
              {missingEnvNames.map((name) => (
                <code key={`missing:${name}`}>{name}</code>
              ))}
            </div>
            {optionalOwnerEnvNames.length > 0 ? (
              <details>
                <summary>Optional scan controls</summary>
                <div>
                  {optionalOwnerEnvNames.map((name) => (
                    <code key={`optional:${name}`}>{name}</code>
                  ))}
                </div>
              </details>
            ) : null}
            <small>{requiredOwnerEnvNames.length} required owner env names covered by the plan.</small>
          </article>

          <article className="panel activation-commands">
            <div className="panel-heading">
              <div>
                <Terminal size={18} aria-hidden="true" />
                <h2>Next commands</h2>
              </div>
            </div>
            <div>
              {nextCommands.map((command) => (
                <code key={`next:${command}`}>{command}</code>
              ))}
            </div>
          </article>

          <article className="panel activation-boundary">
            <div className="panel-heading">
              <div>
                <ShieldAlert size={18} aria-hidden="true" />
                <h2>Do not send</h2>
              </div>
            </div>
            <div>
              {forbiddenItems.map((item) => (
                <span key={`forbidden:${item}`}>{item}</span>
              ))}
            </div>
          </article>
        </aside>
      </section>
    </div>
  );
}
