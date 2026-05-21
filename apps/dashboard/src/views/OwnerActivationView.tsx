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
  upstreamMissingEnvNames: string[];
  upstreamInvalidEnvNames: string[];
  blockingEnvNames: string[];
  blockedByReportNames: string[];
  externalAccountsOrResources: string[];
  ownerMustDo: string[];
  ownerMustNotSend: string[];
  validationCommands: string[];
}

interface ActivationLaunchStep {
  id: string;
  order: string;
  title: string;
  status: string;
  commands: string[];
  expectedReportPaths: string[];
  stopOnFailure: boolean;
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
    upstreamMissingEnvNames: stringList(value.upstreamMissingEnvNames),
    upstreamInvalidEnvNames: stringList(value.upstreamInvalidEnvNames),
    blockingEnvNames: stringList(value.blockingEnvNames),
    blockedByReportNames: stringList(value.blockedByReportNames),
    externalAccountsOrResources: stringList(value.externalAccountsOrResources),
    ownerMustDo: stringList(value.ownerMustDo),
    ownerMustNotSend: stringList(value.ownerMustNotSend),
    validationCommands: stringList(value.validationCommands),
  };
}

function parseLaunchStep(value: unknown, index: number): ActivationLaunchStep | null {
  if (!isRecord(value)) {
    return null;
  }

  return {
    id: text(value.id, `launch-step-${index + 1}`),
    order: text(value.order, String(index + 1)),
    title: text(value.title, "Launch step"),
    status: text(value.status, "not-run"),
    commands: stringList(value.commands),
    expectedReportPaths: stringList(value.expectedReportPaths),
    stopOnFailure: value.stopOnFailure === true,
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
  const handoff = isRecord(liveReadiness?.ownerGoLiveHandoff) ? liveReadiness.ownerGoLiveHandoff : null;
  const stageSource = handoff ?? activation;
  const stages = asArray(stageSource?.stages).map(parseStage).filter((stage): stage is ActivationStage => stage !== null);
  const missingEnvNames = stringList(handoff?.missingEnvNames ?? activation?.missingEnvNames);
  const invalidEnvNames = stringList(handoff?.invalidEnvNames ?? activation?.invalidEnvNames);
  const nextOwnerInputNames = stringList(handoff?.nextOwnerInputNames ?? activation?.nextOwnerInputNames);
  const requiredOwnerEnvNames = stringList(handoff?.requiredOwnerEnvNames ?? activation?.requiredOwnerEnvNames);
  const optionalOwnerEnvNames = stringList(handoff?.optionalOwnerEnvNames ?? activation?.optionalOwnerEnvNames);
  const nextCommands = stringList(handoff?.nextCommands ?? activation?.nextCommands);
  const forbiddenItems = stringList(handoff?.forbiddenItems ?? activation?.forbiddenItems);
  const activationReady = activation?.activationReady === true;
  const releaseReady = handoff?.releaseReady === true;
  const handoffChecks = isRecord(handoff?.checks) ? handoff.checks : {};
  const launchSequence = asArray(handoff?.launchSequence)
    .map(parseLaunchStep)
    .filter((step): step is ActivationLaunchStep => step !== null);
  const rollbackCommands = stringList(handoff?.rollbackCommands);
  const launchSequenceCommandCount = text(handoff?.launchSequenceCommandCount ?? metrics.ownerGoLiveLaunchSequenceCommandCount, "0");
  const rollbackCommandCount = text(handoff?.rollbackCommandCount ?? metrics.ownerGoLiveRollbackCommandCount, String(rollbackCommands.length));
  const ownerHostApplyPlanCovered =
    handoffChecks.launchSequenceCoversOwnerHostApplyPlan === true ||
    launchSequence.some((step) => step.commands.some((command) => command.includes("owner-host-apply.sh plan")));
  const ownerHostApplyExecutionCovered =
    handoffChecks.launchSequenceCoversOwnerHostApplyExecution === true ||
    launchSequence.some((step) => step.commands.some((command) => command.includes("owner-host-apply.sh apply")));
  const ownerHostApplyRollbackCovered =
    handoffChecks.rollbackCoversOwnerHostApplyRollback === true ||
    rollbackCommands.some((command) => command.includes("owner-host-apply.sh rollback"));
  const ownerHostApplyCovered = ownerHostApplyPlanCovered && ownerHostApplyExecutionCovered && ownerHostApplyRollbackCovered;
  const handoffStatus = text(handoff?.status ?? metrics.ownerGoLiveHandoffStatus, "not recorded");
  const activationStatus = text(activation?.status ?? metrics.ownerActivationStatus, "not recorded");
  const readyStageCount = text(handoff?.readyStageCount ?? activation?.readyStageCount ?? metrics.ownerActivationReadyStageCount, "0");
  const stageCount = text(handoff?.stageCount ?? activation?.stageCount ?? metrics.ownerGoLiveStageCount ?? metrics.ownerActivationStageCount, String(stages.length));
  const blockedStageCount = text(handoff?.blockedStageCount ?? activation?.blockedStageCount, "0");
  const needsInputCount = text(activation?.stagesNeedingOwnerInputCount, "0");
  const needsValidationCount = text(activation?.stagesNeedingValidationCount, "0");
  const noSecrets = (handoff ?? activation)?.noSecrets === true;
  const envValuesPrinted = (handoff ?? activation)?.envValuesPrinted === true;
  const broadcasts = (handoff ?? activation)?.broadcasts === true;

  return (
    <div className="view-stack activation-view">
      <SectionHeader
        eyebrow="go-live activation"
        title="L1 activation"
        detail="Owner go-live handoff, validation commands, public RPC, backup, tester gateway, and Base 8453 bridge inputs from the current launch evidence."
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
          <span>Release</span>
          <strong>{releaseReady ? "ready" : "blocked"}</strong>
          <small>handoff {handoffStatus}</small>
        </div>
        <div>
          <span>Activation</span>
          <strong>{activationReady ? "ready" : "blocked"}</strong>
          <small>report {activationStatus}</small>
        </div>
        <div>
          <span>Stages</span>
          <strong>{readyStageCount}/{stageCount}</strong>
          <small>blocked {blockedStageCount} / input stages {needsInputCount} / validation {needsValidationCount}</small>
        </div>
        <div>
          <span>Needed now</span>
          <strong>{nextOwnerInputNames.length}</strong>
          <small>missing {missingEnvNames.length} / invalid {invalidEnvNames.length}</small>
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
              <StatusBadge status={statusFromText(releaseReady || activationReady ? "ready" : "pending")} compact />
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
                            <span>blocking</span>
                            <strong>{stage.blockingEnvNames.length}</strong>
                          </div>
                          <div>
                            <span>direct</span>
                            <strong>{stage.missingEnvNames.length}</strong>
                          </div>
                          <div>
                            <span>reports</span>
                            <strong>{stage.blockedByReportNames.length}</strong>
                          </div>
                        </div>
                        {stage.blockingEnvNames.length > 0 ? (
                          <div className="activation-chip-list" aria-label={`${stage.title} blocking inputs`}>
                            {stage.blockingEnvNames.map((name) => (
                              <code key={`${stage.id}:blocking:${name}`}>{name}</code>
                            ))}
                          </div>
                        ) : null}
                        {stage.blockedByReportNames.length > 0 ? (
                          <div className="activation-report-list" aria-label={`${stage.title} blocked reports`}>
                            <span>blocked by</span>
                            {stage.blockedByReportNames.map((name) => (
                              <code key={`${stage.id}:report:${name}`}>{name}</code>
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
              <EmptyState title="Go-live handoff missing" detail="Run npm run flowchain:owner:go-live-handoff, then refresh dashboard fixtures." />
            )}
          </article>
          <article className="panel activation-launch-sequence">
            <div className="panel-heading">
              <div>
                <Terminal size={18} aria-hidden="true" />
                <h2>Host apply sequence</h2>
              </div>
              <StatusBadge status={ownerHostApplyCovered ? "verified" : "pending"} compact />
            </div>
            <div className="activation-host-apply-proof" aria-label="Owner host apply proof">
              <div>
                <span>Plan</span>
                <strong>{String(ownerHostApplyPlanCovered)}</strong>
                <code>owner-host-apply.sh plan</code>
              </div>
              <div>
                <span>Apply</span>
                <strong>{String(ownerHostApplyExecutionCovered)}</strong>
                <code>owner-host-apply.sh apply</code>
              </div>
              <div>
                <span>Rollback</span>
                <strong>{String(ownerHostApplyRollbackCovered)}</strong>
                <code>owner-host-apply.sh rollback</code>
              </div>
            </div>
            {launchSequence.length > 0 ? (
              <div className="activation-launch-step-list" aria-label="Go-live launch sequence">
                {launchSequence.map((step) => (
                  <article key={step.id} className="activation-launch-step">
                    <div>
                      <span>{step.order}</span>
                      <div>
                        <strong>{step.title}</strong>
                        <small>stop on failure {String(step.stopOnFailure)} / evidence {step.expectedReportPaths.length}</small>
                      </div>
                      <StatusBadge status={statusFromText(step.status, "observed")} compact />
                    </div>
                    <div>
                      {step.commands.slice(0, 5).map((command) => (
                        <code key={`${step.id}:launch-command:${command}`}>{command}</code>
                      ))}
                    </div>
                  </article>
                ))}
              </div>
            ) : (
              <EmptyState title="Launch sequence missing" detail="Run npm run flowchain:owner:go-live-handoff, then refresh dashboard fixtures." />
            )}
            <div className="activation-rollback-strip" aria-label="Owner host rollback commands">
              <strong>Rollback commands</strong>
              <span>{rollbackCommandCount} rollback / {launchSequenceCommandCount} launch commands</span>
              <div>
                {rollbackCommands.map((command) => (
                  <code key={`rollback:${command}`}>{command}</code>
                ))}
              </div>
            </div>
          </article>
        </div>

        <aside className="activation-side">
          <article className="panel activation-needed">
            <div className="panel-heading">
              <div>
                <ListChecks size={18} aria-hidden="true" />
                <h2>Needed now</h2>
              </div>
              <StatusBadge status={nextOwnerInputNames.length === 0 ? "verified" : "pending"} compact />
            </div>
            <div className="activation-input-grid" aria-label="Next owner inputs">
              {nextOwnerInputNames.map((name) => (
                <code key={`next-owner:${name}`}>{name}</code>
              ))}
            </div>
          </article>

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
