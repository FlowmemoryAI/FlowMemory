import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "../../..");
const destinationDir = resolve(repoRoot, "apps/dashboard/public/data");
const liveInfraReportDir = resolve(repoRoot, "docs/agent-runs/live-product-infra-rpc");
const fixtureCopies = [
  {
    label: "dashboard fixture",
    source: resolve(repoRoot, "fixtures/dashboard/flowmemory-dashboard-v0.json"),
    destination: resolve(destinationDir, "flowmemory-dashboard-v0.json"),
  },
  {
    label: "Base canary dashboard fixture",
    source: resolve(repoRoot, "fixtures/dashboard/flowmemory-dashboard-base-canary-v0.json"),
    destination: resolve(destinationDir, "flowmemory-dashboard-base-canary-v0.json"),
  },
  {
    label: "FlowChain local devnet state",
    source: resolve(repoRoot, "fixtures/launch-core/generated/devnet/state.json"),
    destination: resolve(destinationDir, "flowchain-local-devnet-state.json"),
  },
  {
    label: "FlowChain local devnet dashboard state",
    source: resolve(repoRoot, "fixtures/launch-core/generated/devnet/dashboard-state.json"),
    destination: resolve(destinationDir, "flowchain-local-devnet-dashboard-state.json"),
  },
  {
    label: "FlowChain bridge test deposit",
    source: resolve(repoRoot, "fixtures/bridge/base-sepolia-mock-deposit.json"),
    destination: resolve(destinationDir, "flowchain-bridge-test-deposit.json"),
  },
  {
    label: "FlowChain L1 explorer fallback",
    source: resolve(repoRoot, "fixtures/dashboard/flowchain-l1-explorer-fallback.json"),
    destination: resolve(destinationDir, "flowchain-l1-explorer-fallback.json"),
  },
];

const liveReadinessReportCopies = [
  "public-deployment-contract-report.json",
  "flowchain-live-infra-check-report.json",
  "service-status-report.json",
  "service-monitor-report.json",
  "service-supervisor-validation-report.json",
  "service-install-validation-report.json",
  "systemd-service-install-validation-report.json",
  "public-rpc-deployment-bundle-report.json",
  "public-rpc-deployment-automation-report.json",
  "public-rpc-readiness-report.json",
  "public-rpc-command-matrix-report.json",
  "public-rpc-canary-schedule-validation-report.json",
  "backup-readiness-report.json",
  "backup-owner-path-dry-run-report.json",
  "bridge-command-matrix-report.json",
  "bridge-no-secret-audit-report.json",
  "bridge-relayer-once-report.json",
  "bridge-relayer-guardrail-validation-report.json",
  "bridge-relayer-loop-validation-report.json",
  "bridge-runtime-credit-validation-report.json",
  "bridge-reconciliation-schedule-validation-report.json",
  "real-value-pilot-aggregate-report.json",
  "external-tester-packet-report.json",
  "external-tester-connect-pack.json",
  "external-tester-readiness-report.json",
  "public-tester-gateway-e2e-report.json",
  "ops-snapshot-report.json",
  "ops-alert-rules-report.json",
  "ops-metrics-export-report.json",
  "incident-drill-report.json",
  "alert-install-validation-report.json",
  "ops-escalation-dry-run-report.json",
  "owner-inputs-report.json",
  "owner-env-template-report.json",
  "owner-activation-plan-report.json",
  "owner-go-live-handoff-report.json",
  "owner-needs-now-report.json",
  "no-secret-scan-report.json",
];

const liveReadinessGateLabels = new Map([
  ["private-service-origin", "Private L1 origin"],
  ["pre-share-monitoring", "Block production monitor"],
  ["service-autorecovery", "Service autorecovery"],
  ["service-install-automation", "Windows service install"],
  ["public-rpc-edge", "Public RPC edge"],
  ["public-rpc-canary-schedule-automation", "RPC canary schedule"],
  ["state-backup", "State backup proof"],
  ["state-backup-owner-path-dry-run", "Backup dry run"],
  ["base8453-bridge-reconciliation-schedule-automation", "Bridge reconciliation schedule"],
  ["base8453-bridge-edge", "Base 8453 bridge edge"],
  ["base8453-bridge-relayer-queue", "Bridge relayer queue"],
  ["base8453-bridge-runtime-credit-proof", "Bridge runtime credit"],
  ["external-tester-sharing", "External tester packet"],
  ["public-tester-write-gateway", "Tester write gateway"],
  ["no-secret-no-broadcast", "No secrets or broadcasts"],
]);

function readJsonIfExists(fileName) {
  const fullPath = resolve(liveInfraReportDir, fileName);
  if (!existsSync(fullPath)) {
    return null;
  }

  return JSON.parse(readFileSync(fullPath, "utf8"));
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function asText(value, fallback = "not recorded") {
  if (value === null || value === undefined || value === "") {
    return fallback;
  }

  return String(value);
}

function sanitizeText(value) {
  return asText(value)
    .replaceAll(repoRoot, "<repo>")
    .replace(/[A-Za-z]:\\[^\s"',)]+/g, "<local-path>");
}

function sourceReportSummary(fileName, payload) {
  return {
    fileName,
    schema: asText(payload?.schema),
    status: asText(payload?.status, payload ? "observed" : "missing"),
    generatedAt: asText(payload?.generatedAt),
  };
}

function contractItemById(contract, id) {
  return asArray(contract?.items).find((item) => item && item.id === id) ?? null;
}

function commandList(value, limit = 4) {
  return asArray(value).map((command) => sanitizeText(command)).slice(0, limit);
}

function blockerList(value) {
  return asArray(value).map((blocker) => sanitizeText(blocker));
}

function recordEntries(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? Object.entries(value) : [];
}

function uniqueTexts(values) {
  return [...new Set(asArray(values).map((value) => sanitizeText(value)).filter((value) => value !== "not recorded"))];
}

function gateFromContractItem(contract, id) {
  const item = contractItemById(contract, id);
  const label = liveReadinessGateLabels.get(id) ?? id;

  if (!item) {
    return {
      id,
      label,
      status: "unresolved",
      summary: "The deployment contract did not include this gate in the current report.",
      evidence: "missing from public deployment contract report",
      commands: [],
      blockers: [],
    };
  }

  return {
    id,
    label,
    status: asText(item.status, "unresolved"),
    summary: sanitizeText(item.requirement ?? item.summary ?? label),
    evidence: sanitizeText(item.evidence ?? "not recorded"),
    commands: commandList(item.commands),
    blockers: blockerList(item.blockers),
  };
}

function ownerInputGroup(name) {
  if (name.startsWith("FLOWCHAIN_TESTER_")) {
    return "tester write gateway";
  }
  if (name === "FLOWCHAIN_RPC_STATE_BACKUP_PATH") {
    return "backup storage";
  }
  if (name.startsWith("FLOWCHAIN_RPC_")) {
    return "public RPC edge";
  }
  if (name.startsWith("FLOWCHAIN_BASE8453_") || name.startsWith("FLOWCHAIN_PILOT_")) {
    return "Base 8453 bridge";
  }

  return "operator input";
}

function statusCounts(gates) {
  return gates.reduce((counts, gate) => {
    const status = asText(gate.status, "unresolved");
    counts[status] = (counts[status] ?? 0) + 1;
    return counts;
  }, {});
}

function timedOutSteps(steps) {
  return asArray(steps).filter((step) => step?.timedOut === true);
}

function writeLiveReadinessSummary() {
  const reports = Object.fromEntries(liveReadinessReportCopies.map((fileName) => [fileName, readJsonIfExists(fileName)]));
  const contract = reports["public-deployment-contract-report.json"];
  const serviceStatus = reports["service-status-report.json"];
  const monitor = reports["service-monitor-report.json"];
  const serviceSupervisorValidation = reports["service-supervisor-validation-report.json"];
  const serviceInstallValidation = reports["service-install-validation-report.json"];
  const systemdServiceInstallValidation = reports["systemd-service-install-validation-report.json"];
  const bridgeRelayer = reports["bridge-relayer-once-report.json"];
  const bridgeRelayerGuardrail = reports["bridge-relayer-guardrail-validation-report.json"];
  const bridgeRelayerLoopValidation = reports["bridge-relayer-loop-validation-report.json"];
  const bridgeRuntimeCreditValidation = reports["bridge-runtime-credit-validation-report.json"];
  const bridgeReconciliationScheduleValidation = reports["bridge-reconciliation-schedule-validation-report.json"];
  const realValuePilotAggregate = reports["real-value-pilot-aggregate-report.json"];
  const bridgeCommandMatrix = reports["bridge-command-matrix-report.json"];
  const bridgeNoSecretAudit = reports["bridge-no-secret-audit-report.json"];
  const backupOwnerPathDryRun = reports["backup-owner-path-dry-run-report.json"];
  const publicRpcDeploymentBundle = reports["public-rpc-deployment-bundle-report.json"];
  const publicRpcDeploymentAutomation = reports["public-rpc-deployment-automation-report.json"];
  const publicRpcCommandMatrix = reports["public-rpc-command-matrix-report.json"];
  const externalTesterPacket = reports["external-tester-packet-report.json"];
  const externalTesterConnectPack = reports["external-tester-connect-pack.json"];
  const externalTesterReadiness = reports["external-tester-readiness-report.json"];
  const publicTesterGateway = reports["public-tester-gateway-e2e-report.json"];
  const opsSnapshot = reports["ops-snapshot-report.json"];
  const opsAlertRules = reports["ops-alert-rules-report.json"];
  const opsMetricsExport = reports["ops-metrics-export-report.json"];
  const incidentDrill = reports["incident-drill-report.json"];
  const alertInstallValidation = reports["alert-install-validation-report.json"];
  const opsEscalationDryRun = reports["ops-escalation-dry-run-report.json"];
  const ownerInputs = reports["owner-inputs-report.json"];
  const ownerEnvTemplate = reports["owner-env-template-report.json"];
  const ownerActivationPlan = reports["owner-activation-plan-report.json"];
  const ownerGoLiveHandoff = reports["owner-go-live-handoff-report.json"];
  const ownerNeedsNow = reports["owner-needs-now-report.json"];
  const noSecretScan = reports["no-secret-scan-report.json"];
  const gates = [...liveReadinessGateLabels.keys()].map((id) => gateFromContractItem(contract, id));
  const activeRuleIds = asArray(opsAlertRules?.activeRuleIds).map((id) => sanitizeText(id));
  const opsRequiredMetricNames = asArray(opsMetricsExport?.requiredMetricNames).map((name) => sanitizeText(name));
  const publicRpcSecurityHeaderMetricNames = [
    "flowchain_public_rpc_security_headers",
    "flowchain_public_rpc_security_header_preflight",
    "flowchain_public_rpc_rendered_security_headers",
    "flowchain_public_rpc_rendered_security_header_preflight",
  ];
  const publicRpcSecurityHeaderMetricsPresent = publicRpcSecurityHeaderMetricNames.every((name) => opsRequiredMetricNames.includes(name));
  const alertRules = asArray(opsAlertRules?.rules).map((rule) => ({
    id: sanitizeText(rule?.id),
    severity: sanitizeText(rule?.severity),
    signal: sanitizeText(rule?.signal),
    threshold: sanitizeText(rule?.threshold),
    commands: commandList(rule?.commands, 6),
  }));
  const knownOwnerInputs = asArray(contract?.knownOwnerInputs).map((name) => sanitizeText(name));
  const requiredOwnerInputs = knownOwnerInputs.length > 0
    ? knownOwnerInputs
    : gates.flatMap((gate) => gate.blockers);
  const ownerInputSummaries = [...new Set(requiredOwnerInputs)].map((name) => ({
    name,
    group: ownerInputGroup(name),
  }));
  const connectPackCheckValues = Object.values(externalTesterPacket?.connectPackChecks ?? {});
  const bridgeRelayerSteps = asArray(bridgeRelayer?.steps);
  const bridgeRelayerTimedOutSteps = timedOutSteps(bridgeRelayerSteps);
  const toActivationStage = (stage) => ({
    id: sanitizeText(stage?.id),
    title: sanitizeText(stage?.title),
    status: sanitizeText(stage?.status),
    ready: stage?.ready === true,
    requiredEnvNames: uniqueTexts(stage?.requiredEnvNames),
    optionalEnvNames: uniqueTexts(stage?.optionalEnvNames),
    missingEnvNames: uniqueTexts(stage?.missingEnvNames),
    invalidEnvNames: uniqueTexts(stage?.invalidEnvNames),
    upstreamMissingEnvNames: uniqueTexts(stage?.upstreamMissingEnvNames),
    upstreamInvalidEnvNames: uniqueTexts(stage?.upstreamInvalidEnvNames),
    blockingEnvNames: uniqueTexts(stage?.blockingEnvNames),
    blockedByReportNames: uniqueTexts(stage?.blockedByReportNames),
    externalAccountsOrResources: uniqueTexts(stage?.externalAccountsOrResources),
    ownerMustDo: uniqueTexts(stage?.ownerMustDo),
    ownerMustNotSend: uniqueTexts(stage?.ownerMustNotSend),
    validationCommands: commandList(stage?.validationCommands, 8),
    sourceReports: asArray(stage?.sourceReports).map((sourceReport) => ({
      name: sanitizeText(sourceReport?.name),
      status: sanitizeText(sourceReport?.status),
      path: sanitizeText(sourceReport?.path),
    })),
  });
  const toLaunchStep = (step, index) => ({
    id: sanitizeText(step?.id, `launch-step-${index + 1}`),
    order: Number.isFinite(Number(step?.order)) ? Number(step.order) : index + 1,
    title: sanitizeText(step?.title),
    status: sanitizeText(step?.status, "not-run"),
    commands: commandList(step?.commands, 10),
    expectedReportPaths: uniqueTexts(step?.expectedReportPaths).slice(0, 14),
    stopOnFailure: step?.stopOnFailure === true,
  });
  const toOwnerNeedGroup = (group) => ({
    id: sanitizeText(group?.id),
    title: sanitizeText(group?.title),
    status: sanitizeText(group?.status),
    ready: group?.ready === true,
    whyNeeded: sanitizeText(group?.whyNeeded),
    ownerAction: sanitizeText(group?.ownerAction),
    envNames: uniqueTexts(group?.envNames),
    missingEnvNames: uniqueTexts(group?.missingEnvNames),
    invalidEnvNames: uniqueTexts(group?.invalidEnvNames),
    unknownEnvNames: uniqueTexts(group?.unknownEnvNames),
    validationCommands: commandList(group?.validationCommands, 6),
    doNotSend: uniqueTexts(group?.doNotSend),
  });
  const toOwnerEnvFieldGuide = (item) => ({
    name: sanitizeText(item?.name),
    group: sanitizeText(item?.group),
    required: item?.required === true,
    purpose: sanitizeText(item?.purpose),
    validation: sanitizeText(item?.validation),
    source: sanitizeText(item?.source),
    doNotSend: sanitizeText(item?.doNotSend),
  });
  const activationStages = asArray(ownerActivationPlan?.stages).map(toActivationStage);
  const goLiveStages = asArray(ownerGoLiveHandoff?.stages).map(toActivationStage);
  const goLiveLaunchSequence = asArray(ownerGoLiveHandoff?.launchSequence).map(toLaunchStep);
  const goLiveRollbackCommands = commandList(ownerGoLiveHandoff?.rollbackCommands, 12);
  const ownerNeedGroups = asArray(ownerNeedsNow?.groups).map(toOwnerNeedGroup);
  const ownerNeededNowGroups = asArray(ownerNeedsNow?.neededNowGroups).map(toOwnerNeedGroup);
  const ownerReadyGroups = asArray(ownerNeedsNow?.readyGroups).map(toOwnerNeedGroup);
  const ownerEnvFieldGuide = asArray(ownerEnvTemplate?.fieldGuide).map(toOwnerEnvFieldGuide);
  const activationForbiddenItems = uniqueTexts(activationStages.flatMap((stage) => stage.ownerMustNotSend));
  const goLiveForbiddenItems = uniqueTexts(ownerGoLiveHandoff?.mustNotSend ?? goLiveStages.flatMap((stage) => stage.ownerMustNotSend));
  const latestHeight = asText(serviceStatus?.chain?.latestHeight, "not recorded");
  const finalizedHeight = asText(serviceStatus?.chain?.finalizedHeight, "not recorded");
  const privateRpcUrl = serviceStatus?.bind
    ? `http://${asText(serviceStatus.bind.host, "127.0.0.1")}:${asText(serviceStatus.bind.port, "8787")}`
    : "http://127.0.0.1:8787";
  const summary = contract?.deploymentReady === true
    ? "Public launch gates are passing; run the pre-exposure commands before sharing the tester packet."
    : "Public launch is still blocked by owner-provided RPC edge, backup, Base 8453 bridge, or tester packet inputs.";
  const generatedAt = asText(
    contract?.generatedAt ??
      reports["flowchain-live-infra-check-report.json"]?.generatedAt ??
      serviceStatus?.generatedAt,
    "not recorded",
  );
  const liveReadiness = {
    schema: "flowchain.live_readiness_dashboard_report.v0",
    generatedAt,
    status: asText(contract?.status ?? reports["flowchain-live-infra-check-report.json"]?.status, "unresolved"),
    deploymentReady: contract?.deploymentReady === true,
    packetShareable: contract?.packetShareable === true || externalTesterPacket?.packetShareable === true,
    blockedOnlyOnKnownExternalOwnerInputs: contract?.blockedOnlyOnKnownExternalOwnerInputs === true,
    summary,
    privateRpcUrl,
    metrics: {
      latestHeight,
      finalizedHeight,
      monitorHeightAdvanced: monitor?.heightAdvanced === true,
      serviceSupervisorValidationStatus: asText(serviceSupervisorValidation?.status, "not recorded"),
      serviceSupervisorRestartAttempts: asText(serviceSupervisorValidation?.restartAttempts, "0"),
      serviceSupervisorNodeRestartAttempts: asText(serviceSupervisorValidation?.nodeRecovery?.restartAttempts, "0"),
      serviceSupervisorRelayerRestartAttempts: asText(serviceSupervisorValidation?.relayerLoopRecovery?.restartAttempts, "0"),
      serviceInstallValidationStatus: asText(serviceInstallValidation?.status, "not recorded"),
      serviceInstallPlanDidNotMutate: serviceInstallValidation?.checks?.planDidNotMutate === true,
      serviceInstallStatusDidNotMutate: serviceInstallValidation?.checks?.statusDidNotMutate === true,
      serviceInstallRelayerOptInStartsLoop: serviceInstallValidation?.checks?.bridgeRelayerOptInStartsLoop === true,
      systemdServiceInstallValidationStatus: asText(systemdServiceInstallValidation?.status, "not recorded"),
      systemdInstallPlanUsesRenderedUnits: systemdServiceInstallValidation?.checks?.installPlanUsesRenderedUnits === true,
      systemdBridgeRelayerDefaultOff: systemdServiceInstallValidation?.checks?.bridgeRelayerDefaultOff === true,
      systemdBridgeRelayerOptInStartsLoop: systemdServiceInstallValidation?.checks?.bridgeRelayerOptInStartsLoop === true,
      bridgeRelayerStatus: asText(bridgeRelayer?.status, "not recorded"),
      bridgeQueuedTransactions: asText(bridgeRelayer?.counts?.queuedTransactions, "0"),
      bridgeRelayerChildTimeoutSeconds: asText(bridgeRelayer?.childTimeoutSeconds, "not recorded"),
      bridgeRelayerStepCount: bridgeRelayerSteps.length,
      bridgeRelayerTimedOutStepCount: bridgeRelayerTimedOutSteps.length,
      bridgeRelayerNoChildTimeouts: bridgeRelayerSteps.length > 0 && bridgeRelayerTimedOutSteps.length === 0,
      bridgeRelayerCheckContractReady: opsSnapshot?.reportStatuses?.bridgeRelayerCheckContractReady === true,
      bridgeRelayerFailedChecks: asText(opsSnapshot?.reportStatuses?.bridgeRelayerFailedChecks, "0"),
      bridgeRelayerMissingChecks: asText(opsSnapshot?.reportStatuses?.bridgeRelayerMissingChecks, "0"),
      bridgeCommandMatrixStatus: asText(opsSnapshot?.reportStatuses?.bridgeCommandMatrix ?? bridgeCommandMatrix?.status, "not recorded"),
      bridgeCommandMatrixReady: opsSnapshot?.reportStatuses?.bridgeCommandMatrixReady === true || bridgeCommandMatrix?.status === "passed",
      bridgeCommandMatrixCommands: asText(opsSnapshot?.reportStatuses?.bridgeCommandMatrixCommands ?? bridgeCommandMatrix?.commandCount, "0"),
      bridgeCommandMatrixPhases: asText(opsSnapshot?.reportStatuses?.bridgeCommandMatrixPhases ?? bridgeCommandMatrix?.phaseCount, "0"),
      bridgeCommandMatrixLiveBroadcastCommands: asText(opsSnapshot?.reportStatuses?.bridgeCommandMatrixLiveBroadcastCommands ?? bridgeCommandMatrix?.liveBroadcastCapableCommandCount, "0"),
      bridgeCommandMatrixCommittedEvidencePaths: asText(opsSnapshot?.reportStatuses?.bridgeCommandMatrixCommittedEvidencePaths ?? bridgeCommandMatrix?.committedEvidencePathCount, "0"),
      bridgeCommandMatrixFailedChecks: asText(opsSnapshot?.reportStatuses?.bridgeCommandMatrixFailedChecks ?? asArray(bridgeCommandMatrix?.failedChecks).length, "0"),
      bridgeCommandMatrixBroadcastAckGaps: asText(opsSnapshot?.reportStatuses?.bridgeCommandMatrixBroadcastAckGaps ?? asArray(bridgeCommandMatrix?.liveBroadcastRowsWithoutAck).length, "0"),
      bridgeCommandMatrixNoSecrets: opsSnapshot?.reportStatuses?.bridgeCommandMatrixNoSecrets === true || bridgeCommandMatrix?.noSecrets === true,
      bridgeCommandMatrixNoBroadcasts: opsSnapshot?.reportStatuses?.bridgeCommandMatrixNoBroadcasts === true || bridgeCommandMatrix?.broadcasts === false,
      bridgeNoSecretAuditStatus: asText(opsSnapshot?.reportStatuses?.bridgeNoSecretAudit ?? bridgeNoSecretAudit?.status, "not recorded"),
      bridgeNoSecretAuditReady: opsSnapshot?.reportStatuses?.bridgeNoSecretAuditReady === true || bridgeNoSecretAudit?.status === "passed",
      bridgeNoSecretAuditScannedFiles: asText(opsSnapshot?.reportStatuses?.bridgeNoSecretAuditScannedFiles ?? bridgeNoSecretAudit?.scannedFileCount, "0"),
      bridgeNoSecretAuditFindings: asText(opsSnapshot?.reportStatuses?.bridgeNoSecretAuditFindings ?? asArray(bridgeNoSecretAudit?.findings).length, "0"),
      bridgeNoSecretAuditSecretFindings: asText(opsSnapshot?.reportStatuses?.bridgeNoSecretAuditSecretFindings ?? asArray(bridgeNoSecretAudit?.secretMarkerFindings).length, "0"),
      bridgeNoSecretAuditFailedChecks: asText(opsSnapshot?.reportStatuses?.bridgeNoSecretAuditFailedChecks ?? asArray(bridgeNoSecretAudit?.failedChecks).length, "0"),
      bridgeNoSecretAuditNoSecrets: opsSnapshot?.reportStatuses?.bridgeNoSecretAuditReady === true || bridgeNoSecretAudit?.noSecrets === true,
      bridgeNoSecretAuditNoBroadcasts: bridgeNoSecretAudit?.broadcasts === false,
      bridgeRelayerGuardrailStatus: asText(bridgeRelayerGuardrail?.status, "not recorded"),
      bridgeRelayerLoopValidationStatus: asText(bridgeRelayerLoopValidation?.status, "not recorded"),
      bridgeReconciliationScheduleStatus: asText(bridgeReconciliationScheduleValidation?.status, "not recorded"),
      bridgeReconciliationScheduleReady: bridgeReconciliationScheduleValidation?.status === "passed",
      bridgeReconciliationScheduleIntervalMinutes: asText(bridgeReconciliationScheduleValidation?.intervalMinutes, "not recorded"),
      bridgeReconciliationScheduleNoMutation: bridgeReconciliationScheduleValidation?.hostMutationPerformed === false,
      bridgeReconciliationScheduleNoExternalDelivery: bridgeReconciliationScheduleValidation?.checks?.noExternalDelivery === true,
      bridgeRuntimeCreditValidationStatus: asText(bridgeRuntimeCreditValidation?.status, "not recorded"),
      bridgeRuntimeCreditReady: bridgeRuntimeCreditValidation?.status === "passed",
      bridgeRuntimeCreditLatencySeconds: asText(bridgeRuntimeCreditValidation?.timing?.queueToSpendableSeconds, "not recorded"),
      bridgeRuntimeCreditTransferSeconds: asText(bridgeRuntimeCreditValidation?.timing?.transferSettlementSeconds, "not recorded"),
      bridgeRuntimeCreditFailedChecks: asText(asArray(bridgeRuntimeCreditValidation?.failedChecks).length, "0"),
      realValuePilotAggregateStatus: asText(opsSnapshot?.reportStatuses?.realValuePilotAggregate ?? realValuePilotAggregate?.status, "not recorded"),
      realValuePilotAggregateReady: opsSnapshot?.reportStatuses?.realValuePilotAggregateReady === true || (realValuePilotAggregate?.status === "passed" && realValuePilotAggregate?.ownerGoNoGo?.go === true),
      realValuePilotAggregateCommandsRun: asText(opsSnapshot?.reportStatuses?.realValuePilotAggregateCommandsRun ?? asArray(realValuePilotAggregate?.commandsRun).length, "0"),
      realValuePilotAggregateTimedOutCommands: asText(opsSnapshot?.reportStatuses?.realValuePilotAggregateTimedOutCommands ?? asArray(realValuePilotAggregate?.timedOutCommands).length, "0"),
      realValuePilotAggregateFailedCommands: asText(opsSnapshot?.reportStatuses?.realValuePilotAggregateFailedCommands ?? asArray(realValuePilotAggregate?.failedCommands).length, "0"),
      realValuePilotAggregateMissingProofs: asText(opsSnapshot?.reportStatuses?.realValuePilotAggregateMissingProofs ?? asArray(realValuePilotAggregate?.missingProofs).length, "0"),
      realValuePilotAggregateOwnerGoNoGo: opsSnapshot?.reportStatuses?.realValuePilotAggregateOwnerGoNoGo === true || realValuePilotAggregate?.ownerGoNoGo?.go === true,
      backupOwnerPathDryRunStatus: asText(backupOwnerPathDryRun?.status, "not recorded"),
      publicRpcDeploymentBundleStatus: asText(publicRpcDeploymentBundle?.status, "not recorded"),
      publicRpcOwnerRenderValidationStatus: asText(publicRpcDeploymentBundle?.renderValidation?.status, "not recorded"),
      publicRpcDeploymentAutomationStatus: asText(publicRpcDeploymentAutomation?.status, "not recorded"),
      publicRpcDeploymentAutomationAction: asText(publicRpcDeploymentAutomation?.action, "not recorded"),
      publicRpcSecurityHeaders: publicRpcDeploymentBundle?.checks?.includesSecurityHeaders === true,
      publicRpcSecurityHeaderPreflight: publicRpcDeploymentBundle?.checks?.preflightsCheckSecurityHeaders === true,
      publicRpcRenderedSecurityHeaders: publicRpcDeploymentAutomation?.checks?.renderedNginxHasSecurityHeaders === true,
      publicRpcRenderedSecurityHeaderPreflight: publicRpcDeploymentAutomation?.checks?.renderedPreflightChecksSecurityHeaders === true,
      publicRpcCommandMatrixStatus: asText(opsSnapshot?.reportStatuses?.publicRpcCommandMatrix ?? publicRpcCommandMatrix?.status, "not recorded"),
      publicRpcCommandMatrixReady: opsSnapshot?.reportStatuses?.publicRpcCommandMatrixReady === true || publicRpcCommandMatrix?.status === "passed",
      publicRpcCommandMatrixCommands: asText(opsSnapshot?.reportStatuses?.publicRpcCommandMatrixCommands ?? publicRpcCommandMatrix?.commandCount, "0"),
      publicRpcCommandMatrixOwnerHostCommands: asText(opsSnapshot?.reportStatuses?.publicRpcCommandMatrixOwnerHostCommands ?? publicRpcCommandMatrix?.ownerHostCommandCount, "0"),
      publicRpcCommandMatrixMutatingOwnerHostCommands: asText(opsSnapshot?.reportStatuses?.publicRpcCommandMatrixMutatingOwnerHostCommands ?? publicRpcCommandMatrix?.mutatingOwnerHostCommandCount, "0"),
      publicRpcCommandMatrixCommittedEvidencePaths: asText(opsSnapshot?.reportStatuses?.publicRpcCommandMatrixCommittedEvidencePaths ?? publicRpcCommandMatrix?.committedEvidencePathCount, "0"),
      publicRpcCommandMatrixFailedChecks: asText(opsSnapshot?.reportStatuses?.publicRpcCommandMatrixFailedChecks ?? asArray(publicRpcCommandMatrix?.failedChecks).length, "0"),
      publicRpcCommandMatrixMissingScripts: asText(opsSnapshot?.reportStatuses?.publicRpcCommandMatrixMissingScripts ?? asArray(publicRpcCommandMatrix?.missingPackageScripts).length, "0"),
      publicRpcCommandMatrixNoSecrets: opsSnapshot?.reportStatuses?.publicRpcCommandMatrixNoSecrets === true || publicRpcCommandMatrix?.noSecrets === true,
      publicRpcCommandMatrixNoBroadcasts: opsSnapshot?.reportStatuses?.publicRpcCommandMatrixNoBroadcasts === true || publicRpcCommandMatrix?.broadcasts === false,
      externalTesterPacketStatus: asText(externalTesterPacket?.status, "not recorded"),
      externalTesterConnectPackStatus: asText(externalTesterConnectPack?.status, "not recorded"),
      publicTesterGatewayStatus: asText(publicTesterGateway?.status, "not recorded"),
      publicTesterGatewayAccountCount: asText(opsSnapshot?.reportStatuses?.publicTesterGatewayAccountCount ?? publicTesterGateway?.accountCount, "0"),
      publicTesterGatewayFailedChecks: asText(opsSnapshot?.reportStatuses?.publicTesterGatewayFailedChecks ?? asArray(publicTesterGateway?.failedChecks).length, "0"),
      publicTesterGatewayNoSecrets: opsSnapshot?.reportStatuses?.publicTesterGatewayNoSecrets === true || publicTesterGateway?.noSecrets === true,
      publicTesterGatewayNoBroadcasts: opsSnapshot?.reportStatuses?.publicTesterGatewayNoBroadcasts === true || publicTesterGateway?.broadcasts === false,
      ownerInputReady: ownerInputs?.ownerInputReady === true,
      ownerEnvTemplateStatus: asText(ownerEnvTemplate?.status, "not recorded"),
      ownerEnvTemplateFieldGuideCount: asText(ownerEnvTemplate?.fieldGuideCount, String(ownerEnvFieldGuide.length)),
      ownerEnvTemplateRequiredEnvNameCount: asText(ownerEnvTemplate?.requiredEnvNameCount, "0"),
      ownerEnvTemplateNoSecrets: ownerEnvTemplate?.noSecrets === true,
      ownerEnvTemplateEnvValuesPrinted: ownerEnvTemplate?.envValuesPrinted === true,
      ownerActivationStatus: asText(ownerActivationPlan?.status, "not recorded"),
      ownerActivationReady: ownerActivationPlan?.activationReady === true,
      ownerActivationStageCount: asText(ownerActivationPlan?.stageCount, String(activationStages.length)),
      ownerActivationReadyStageCount: asText(ownerActivationPlan?.readyStageCount, "0"),
      ownerActivationMissingCount: asArray(ownerActivationPlan?.missingEnvNames).length,
      ownerGoLiveHandoffStatus: asText(ownerGoLiveHandoff?.status, "not recorded"),
      ownerGoLiveHandoffReady: ownerGoLiveHandoff?.status === "passed" && asArray(ownerGoLiveHandoff?.failedChecks).length === 0,
      ownerGoLiveReleaseReady: ownerGoLiveHandoff?.releaseReady === true,
      ownerGoLiveNextInputCount: asArray(ownerGoLiveHandoff?.nextOwnerInputNames).length,
      ownerGoLiveStageCount: asText(ownerGoLiveHandoff?.stageCount, String(goLiveStages.length)),
      ownerGoLiveLaunchSequenceCount: asText(ownerGoLiveHandoff?.launchSequenceCount, String(goLiveLaunchSequence.length)),
      ownerGoLiveLaunchSequenceCommandCount: asText(ownerGoLiveHandoff?.launchSequenceCommandCount, "0"),
      ownerGoLiveExpectedReportPathCount: asText(ownerGoLiveHandoff?.launchSequenceExpectedReportPathCount, "0"),
      ownerGoLiveRollbackCommandCount: asText(ownerGoLiveHandoff?.rollbackCommandCount, String(goLiveRollbackCommands.length)),
      ownerNeedsNowStatus: asText(ownerNeedsNow?.status, "not recorded"),
      ownerNeedsNowGroupCount: asText(ownerNeedsNow?.groupCount, String(ownerNeedGroups.length)),
      ownerNeedsNowNeededGroupCount: asText(ownerNeedsNow?.neededNowGroupCount, String(ownerNeededNowGroups.length)),
      ownerNeedsNowReadyGroupCount: asText(ownerNeedsNow?.readyGroupCount, String(ownerReadyGroups.length)),
      ownerHostApplyPlanCovered: ownerGoLiveHandoff?.checks?.launchSequenceCoversOwnerHostApplyPlan === true,
      ownerHostApplyExecutionCovered: ownerGoLiveHandoff?.checks?.launchSequenceCoversOwnerHostApplyExecution === true,
      ownerHostApplyRollbackCovered: ownerGoLiveHandoff?.checks?.rollbackCoversOwnerHostApplyRollback === true,
      windowsOwnerHostApplyPlanCovered: ownerGoLiveHandoff?.checks?.launchSequenceCoversWindowsOwnerHostApplyPlan === true,
      windowsOwnerHostApplyExecutionCovered: ownerGoLiveHandoff?.checks?.launchSequenceCoversWindowsOwnerHostApplyExecution === true,
      windowsOwnerHostApplyRollbackCovered: ownerGoLiveHandoff?.checks?.rollbackCoversWindowsOwnerHostApplyRollback === true,
      noSecretStatus: asText(noSecretScan?.status, "not recorded"),
      opsSnapshotStatus: asText(opsSnapshot?.status, "not recorded"),
      opsAlertState: asText(opsAlertRules?.currentAlertState, "not recorded"),
      opsCriticalCount: asText(opsSnapshot?.criticalCount, "0"),
      opsBlockedCount: asText(opsSnapshot?.blockedCount, "0"),
      opsActiveRuleCount: activeRuleIds.length,
      opsRuleCount: asText(opsAlertRules?.ruleCount, String(alertRules.length)),
      opsCriticalRuleCount: asText(opsAlertRules?.criticalRuleCount, "0"),
      opsBlockedRuleCount: asText(opsAlertRules?.blockedRuleCount, "0"),
      opsUnmappedCurrentFindingCount: asArray(opsAlertRules?.unmappedCurrentFindingCodes).length,
      opsMetricCount: asText(opsMetricsExport?.metricCount, "0"),
      opsRequiredMetricsPresent: opsMetricsExport?.checks?.requiredMetricsPresent === true,
      opsPublicRpcSecurityHeaderMetricsPresent: publicRpcSecurityHeaderMetricsPresent,
      incidentDrillStatus: asText(incidentDrill?.status, "not recorded"),
      alertInstallValidationStatus: asText(alertInstallValidation?.status, "not recorded"),
      opsEscalationDryRunStatus: asText(opsEscalationDryRun?.status, "not recorded"),
      opsEscalationDryRunEvents: asText(opsEscalationDryRun?.dryRunEventCount, "0"),
      statusCounts: statusCounts(gates),
    },
    ops: {
      snapshotStatus: asText(opsSnapshot?.status, "not recorded"),
      alertRulesStatus: asText(opsAlertRules?.status, "not recorded"),
      alertState: asText(opsAlertRules?.currentAlertState, "not recorded"),
      incidentDrillStatus: asText(incidentDrill?.status, "not recorded"),
      alertInstallValidationStatus: asText(alertInstallValidation?.status, "not recorded"),
      escalationDryRunStatus: asText(opsEscalationDryRun?.status, "not recorded"),
      escalationDryRunEvents: asText(opsEscalationDryRun?.dryRunEventCount, "0"),
      serviceSupervisorValidationStatus: asText(serviceSupervisorValidation?.status, "not recorded"),
      serviceSupervisorRestartAttempts: asText(serviceSupervisorValidation?.restartAttempts, "0"),
      serviceSupervisorNodeRestartAttempts: asText(serviceSupervisorValidation?.nodeRecovery?.restartAttempts, "0"),
      serviceSupervisorRelayerRestartAttempts: asText(serviceSupervisorValidation?.relayerLoopRecovery?.restartAttempts, "0"),
      serviceInstallValidationStatus: asText(serviceInstallValidation?.status, "not recorded"),
      serviceInstallPlanDidNotMutate: serviceInstallValidation?.checks?.planDidNotMutate === true,
      serviceInstallStatusDidNotMutate: serviceInstallValidation?.checks?.statusDidNotMutate === true,
      serviceInstallRelayerOptInStartsLoop: serviceInstallValidation?.checks?.bridgeRelayerOptInStartsLoop === true,
      systemdServiceInstallValidationStatus: asText(systemdServiceInstallValidation?.status, "not recorded"),
      systemdInstallPlanUsesRenderedUnits: systemdServiceInstallValidation?.checks?.installPlanUsesRenderedUnits === true,
      systemdBridgeRelayerDefaultOff: systemdServiceInstallValidation?.checks?.bridgeRelayerDefaultOff === true,
      systemdBridgeRelayerOptInStartsLoop: systemdServiceInstallValidation?.checks?.bridgeRelayerOptInStartsLoop === true,
      publicRpcDeploymentBundleStatus: asText(publicRpcDeploymentBundle?.status, "not recorded"),
      publicRpcDeploymentAutomationStatus: asText(publicRpcDeploymentAutomation?.status, "not recorded"),
      publicRpcDeploymentAutomationAction: asText(publicRpcDeploymentAutomation?.action, "not recorded"),
      publicRpcSecurityHeaders: publicRpcDeploymentBundle?.checks?.includesSecurityHeaders === true,
      publicRpcRenderedSecurityHeaders: publicRpcDeploymentAutomation?.checks?.renderedNginxHasSecurityHeaders === true,
      publicRpcCommandMatrixStatus: asText(opsSnapshot?.reportStatuses?.publicRpcCommandMatrix ?? publicRpcCommandMatrix?.status, "not recorded"),
      publicRpcCommandMatrixReady: opsSnapshot?.reportStatuses?.publicRpcCommandMatrixReady === true || publicRpcCommandMatrix?.status === "passed",
      publicRpcCommandMatrixCommands: asText(opsSnapshot?.reportStatuses?.publicRpcCommandMatrixCommands ?? publicRpcCommandMatrix?.commandCount, "0"),
      publicRpcCommandMatrixOwnerHostCommands: asText(opsSnapshot?.reportStatuses?.publicRpcCommandMatrixOwnerHostCommands ?? publicRpcCommandMatrix?.ownerHostCommandCount, "0"),
      publicRpcCommandMatrixMutatingOwnerHostCommands: asText(opsSnapshot?.reportStatuses?.publicRpcCommandMatrixMutatingOwnerHostCommands ?? publicRpcCommandMatrix?.mutatingOwnerHostCommandCount, "0"),
      publicRpcCommandMatrixCommittedEvidencePaths: asText(opsSnapshot?.reportStatuses?.publicRpcCommandMatrixCommittedEvidencePaths ?? publicRpcCommandMatrix?.committedEvidencePathCount, "0"),
      publicRpcCommandMatrixFailedChecks: asText(opsSnapshot?.reportStatuses?.publicRpcCommandMatrixFailedChecks ?? asArray(publicRpcCommandMatrix?.failedChecks).length, "0"),
      publicRpcCommandMatrixNoSecrets: opsSnapshot?.reportStatuses?.publicRpcCommandMatrixNoSecrets === true || publicRpcCommandMatrix?.noSecrets === true,
      publicRpcCommandMatrixNoBroadcasts: opsSnapshot?.reportStatuses?.publicRpcCommandMatrixNoBroadcasts === true || publicRpcCommandMatrix?.broadcasts === false,
      opsMetricCount: asText(opsMetricsExport?.metricCount, "0"),
      opsRequiredMetricsPresent: opsMetricsExport?.checks?.requiredMetricsPresent === true,
      publicTesterGatewayStatus: asText(publicTesterGateway?.status, "not recorded"),
      publicTesterGatewayAccountCount: asText(opsSnapshot?.reportStatuses?.publicTesterGatewayAccountCount ?? publicTesterGateway?.accountCount, "0"),
      publicTesterGatewayFailedChecks: asText(opsSnapshot?.reportStatuses?.publicTesterGatewayFailedChecks ?? asArray(publicTesterGateway?.failedChecks).length, "0"),
      publicTesterGatewayTransferApplied: opsSnapshot?.reportStatuses?.publicTesterGatewayTransferApplied === true || publicTesterGateway?.checks?.transferAppliedLocalRuntime === true,
      publicTesterGatewayCapRejected: opsSnapshot?.reportStatuses?.publicTesterGatewayCapRejected === true || publicTesterGateway?.capRejected === true,
      publicTesterGatewayNoSecrets: opsSnapshot?.reportStatuses?.publicTesterGatewayNoSecrets === true || publicTesterGateway?.noSecrets === true,
      publicTesterGatewayNoBroadcasts: opsSnapshot?.reportStatuses?.publicTesterGatewayNoBroadcasts === true || publicTesterGateway?.broadcasts === false,
      bridgeRelayerCheckContractReady: opsSnapshot?.reportStatuses?.bridgeRelayerCheckContractReady === true,
      bridgeRelayerFailedChecks: asText(opsSnapshot?.reportStatuses?.bridgeRelayerFailedChecks, "0"),
      bridgeRelayerMissingChecks: asText(opsSnapshot?.reportStatuses?.bridgeRelayerMissingChecks, "0"),
      bridgeCommandMatrixStatus: asText(opsSnapshot?.reportStatuses?.bridgeCommandMatrix ?? bridgeCommandMatrix?.status, "not recorded"),
      bridgeCommandMatrixReady: opsSnapshot?.reportStatuses?.bridgeCommandMatrixReady === true || bridgeCommandMatrix?.status === "passed",
      bridgeCommandMatrixCommands: asText(opsSnapshot?.reportStatuses?.bridgeCommandMatrixCommands ?? bridgeCommandMatrix?.commandCount, "0"),
      bridgeCommandMatrixLiveBroadcastCommands: asText(opsSnapshot?.reportStatuses?.bridgeCommandMatrixLiveBroadcastCommands ?? bridgeCommandMatrix?.liveBroadcastCapableCommandCount, "0"),
      bridgeCommandMatrixFailedChecks: asText(opsSnapshot?.reportStatuses?.bridgeCommandMatrixFailedChecks ?? asArray(bridgeCommandMatrix?.failedChecks).length, "0"),
      bridgeCommandMatrixBroadcastAckGaps: asText(opsSnapshot?.reportStatuses?.bridgeCommandMatrixBroadcastAckGaps ?? asArray(bridgeCommandMatrix?.liveBroadcastRowsWithoutAck).length, "0"),
      bridgeCommandMatrixNoSecrets: opsSnapshot?.reportStatuses?.bridgeCommandMatrixNoSecrets === true || bridgeCommandMatrix?.noSecrets === true,
      bridgeCommandMatrixNoBroadcasts: opsSnapshot?.reportStatuses?.bridgeCommandMatrixNoBroadcasts === true || bridgeCommandMatrix?.broadcasts === false,
      bridgeNoSecretAuditStatus: asText(opsSnapshot?.reportStatuses?.bridgeNoSecretAudit ?? bridgeNoSecretAudit?.status, "not recorded"),
      bridgeNoSecretAuditReady: opsSnapshot?.reportStatuses?.bridgeNoSecretAuditReady === true || bridgeNoSecretAudit?.status === "passed",
      bridgeNoSecretAuditScannedFiles: asText(opsSnapshot?.reportStatuses?.bridgeNoSecretAuditScannedFiles ?? bridgeNoSecretAudit?.scannedFileCount, "0"),
      bridgeNoSecretAuditFindings: asText(opsSnapshot?.reportStatuses?.bridgeNoSecretAuditFindings ?? asArray(bridgeNoSecretAudit?.findings).length, "0"),
      bridgeNoSecretAuditSecretFindings: asText(opsSnapshot?.reportStatuses?.bridgeNoSecretAuditSecretFindings ?? asArray(bridgeNoSecretAudit?.secretMarkerFindings).length, "0"),
      bridgeNoSecretAuditFailedChecks: asText(opsSnapshot?.reportStatuses?.bridgeNoSecretAuditFailedChecks ?? asArray(bridgeNoSecretAudit?.failedChecks).length, "0"),
      bridgeNoSecretAuditNoSecrets: opsSnapshot?.reportStatuses?.bridgeNoSecretAuditReady === true || bridgeNoSecretAudit?.noSecrets === true,
      bridgeNoSecretAuditNoBroadcasts: bridgeNoSecretAudit?.broadcasts === false,
      bridgeRelayerGuardrailStatus: asText(opsSnapshot?.reportStatuses?.bridgeRelayerGuardrail ?? bridgeRelayerGuardrail?.status, "not recorded"),
      bridgeRelayerGuardrailReady: opsSnapshot?.reportStatuses?.bridgeRelayerGuardrailReady === true,
      bridgeReconciliationScheduleStatus: asText(bridgeReconciliationScheduleValidation?.status, "not recorded"),
      bridgeReconciliationScheduleReady: bridgeReconciliationScheduleValidation?.status === "passed",
      bridgeReconciliationScheduleIntervalMinutes: asText(bridgeReconciliationScheduleValidation?.intervalMinutes, "not recorded"),
      bridgeReconciliationScheduleNoMutation: bridgeReconciliationScheduleValidation?.hostMutationPerformed === false,
      bridgeReconciliationScheduleNoExternalDelivery: bridgeReconciliationScheduleValidation?.checks?.noExternalDelivery === true,
      bridgeRuntimeCreditStatus: asText(opsSnapshot?.reportStatuses?.bridgeRuntimeCredit ?? bridgeRuntimeCreditValidation?.status, "not recorded"),
      bridgeRuntimeCreditReady: opsSnapshot?.reportStatuses?.bridgeRuntimeCreditReady === true || bridgeRuntimeCreditValidation?.status === "passed",
      bridgeRuntimeCreditLatencySeconds: asText(opsSnapshot?.reportStatuses?.bridgeRuntimeCreditLatencySeconds ?? bridgeRuntimeCreditValidation?.timing?.queueToSpendableSeconds, "not recorded"),
      bridgeRuntimeTransferLatencySeconds: asText(opsSnapshot?.reportStatuses?.bridgeRuntimeTransferLatencySeconds ?? bridgeRuntimeCreditValidation?.timing?.transferSettlementSeconds, "not recorded"),
      realValuePilotAggregateStatus: asText(opsSnapshot?.reportStatuses?.realValuePilotAggregate ?? realValuePilotAggregate?.status, "not recorded"),
      realValuePilotAggregateReady: opsSnapshot?.reportStatuses?.realValuePilotAggregateReady === true || (realValuePilotAggregate?.status === "passed" && realValuePilotAggregate?.ownerGoNoGo?.go === true),
      realValuePilotAggregateCommandsRun: asText(opsSnapshot?.reportStatuses?.realValuePilotAggregateCommandsRun ?? asArray(realValuePilotAggregate?.commandsRun).length, "0"),
      realValuePilotAggregateTimedOutCommands: asText(opsSnapshot?.reportStatuses?.realValuePilotAggregateTimedOutCommands ?? asArray(realValuePilotAggregate?.timedOutCommands).length, "0"),
      realValuePilotAggregateFailedCommands: asText(opsSnapshot?.reportStatuses?.realValuePilotAggregateFailedCommands ?? asArray(realValuePilotAggregate?.failedCommands).length, "0"),
      realValuePilotAggregateMissingProofs: asText(opsSnapshot?.reportStatuses?.realValuePilotAggregateMissingProofs ?? asArray(realValuePilotAggregate?.missingProofs).length, "0"),
      realValuePilotAggregateOwnerGoNoGo: opsSnapshot?.reportStatuses?.realValuePilotAggregateOwnerGoNoGo === true || realValuePilotAggregate?.ownerGoNoGo?.go === true,
      criticalCount: asText(opsSnapshot?.criticalCount, "0"),
      blockedCount: asText(opsSnapshot?.blockedCount, "0"),
      latestHeight: asText(opsSnapshot?.chain?.latestHeight, latestHeight),
      finalizedHeight: asText(opsSnapshot?.chain?.finalizedHeight, finalizedHeight),
      monitorStatus: asText(opsSnapshot?.chain?.monitorStatus, "not recorded"),
      monitorHeightAdvanced: opsSnapshot?.chain?.monitorHeightAdvanced === true,
      findings: asArray(opsSnapshot?.findings).map((finding) => ({
        severity: sanitizeText(finding?.severity),
        code: sanitizeText(finding?.code),
        message: sanitizeText(finding?.message),
        commands: commandList(finding?.commands, 6),
      })),
      activeRuleIds,
      coveredFindingCodes: asArray(opsAlertRules?.coveredFindingCodes).map((code) => sanitizeText(code)),
      activeRules: alertRules.filter((rule) => activeRuleIds.includes(rule.id)),
      ruleCount: asText(opsAlertRules?.ruleCount, String(alertRules.length)),
      criticalRuleCount: asText(opsAlertRules?.criticalRuleCount, "0"),
      blockedRuleCount: asText(opsAlertRules?.blockedRuleCount, "0"),
      unmappedCurrentFindingCodes: asArray(opsAlertRules?.unmappedCurrentFindingCodes).map((code) => sanitizeText(code)),
      incidentCommands: Object.fromEntries(
        recordEntries(opsSnapshot?.incidentCommands).map(([group, commands]) => [sanitizeText(group), commandList(commands, 10)]),
      ),
      dryRunEvents: asArray(opsEscalationDryRun?.dryRunEvents).map((event) => ({
        findingCode: sanitizeText(event?.findingCode),
        severity: sanitizeText(event?.severity),
        ruleId: sanitizeText(event?.ruleId),
        signal: sanitizeText(event?.signal),
        commands: commandList(event?.commands, 6),
      })),
      sendsNetworkNotifications: opsAlertRules?.notificationPlan?.sendsNetworkNotifications === true,
      storesSecrets: opsAlertRules?.notificationPlan?.storesSecrets === true,
    },
    ownerActivation: {
      status: asText(ownerActivationPlan?.status, "not recorded"),
      activationReady: ownerActivationPlan?.activationReady === true,
      stageCount: asText(ownerActivationPlan?.stageCount, String(activationStages.length)),
      readyStageCount: asText(ownerActivationPlan?.readyStageCount, "0"),
      blockedStageCount: asText(ownerActivationPlan?.blockedStageCount, "0"),
      stagesNeedingOwnerInputCount: asText(ownerActivationPlan?.stagesNeedingOwnerInputCount, "0"),
      stagesNeedingValidationCount: asText(ownerActivationPlan?.stagesNeedingValidationCount, "0"),
      missingEnvNames: uniqueTexts(ownerActivationPlan?.missingEnvNames),
      invalidEnvNames: uniqueTexts(ownerActivationPlan?.invalidEnvNames),
      nextOwnerInputNames: uniqueTexts(ownerActivationPlan?.nextOwnerInputNames),
      requiredOwnerEnvNames: uniqueTexts(ownerActivationPlan?.requiredOwnerEnvNames),
      optionalOwnerEnvNames: uniqueTexts(ownerActivationPlan?.optionalOwnerEnvNames),
      nextCommands: commandList(ownerActivationPlan?.nextCommands, 10),
      forbiddenItems: activationForbiddenItems,
      stages: activationStages,
      checks: ownerActivationPlan?.checks ?? {},
      failedChecks: uniqueTexts(ownerActivationPlan?.failedChecks),
      noSecrets: ownerActivationPlan?.noSecrets === true,
      broadcasts: ownerActivationPlan?.broadcasts === true,
      envValuesPrinted: ownerActivationPlan?.envValuesPrinted === true,
    },
    ownerEnvTemplate: {
      status: asText(ownerEnvTemplate?.status, "not recorded"),
      requiredEnvNameCount: asText(ownerEnvTemplate?.requiredEnvNameCount, "0"),
      optionalEnvNameCount: asText(asArray(ownerEnvTemplate?.optionalEnvNames).length, "0"),
      fieldGuideCount: asText(ownerEnvTemplate?.fieldGuideCount, String(ownerEnvFieldGuide.length)),
      fieldGuide: ownerEnvFieldGuide,
      checks: ownerEnvTemplate?.checks ?? {},
      failedChecks: uniqueTexts(ownerEnvTemplate?.failedChecks),
      noSecrets: ownerEnvTemplate?.noSecrets === true,
      broadcasts: ownerEnvTemplate?.broadcasts === true,
      envValuesPrinted: ownerEnvTemplate?.envValuesPrinted === true,
    },
    ownerGoLiveHandoff: {
      status: asText(ownerGoLiveHandoff?.status, "not recorded"),
      releaseReady: ownerGoLiveHandoff?.releaseReady === true,
      activationReady: ownerGoLiveHandoff?.activationReady === true,
      deploymentReady: ownerGoLiveHandoff?.deploymentReady === true,
      packetShareable: ownerGoLiveHandoff?.packetShareable === true,
      completionReady: ownerGoLiveHandoff?.completionReady === true,
      truthTableClear: ownerGoLiveHandoff?.truthTableClear === true,
      blockedOnlyOnKnownOwnerInputs: ownerGoLiveHandoff?.blockedOnlyOnKnownOwnerInputs === true,
      stageCount: asText(ownerGoLiveHandoff?.stageCount, String(goLiveStages.length)),
      readyStageCount: asText(ownerGoLiveHandoff?.readyStageCount, "0"),
      blockedStageCount: asText(ownerGoLiveHandoff?.blockedStageCount, "0"),
      nextCommandCount: asText(ownerGoLiveHandoff?.nextCommandCount, "0"),
      launchSequenceCount: asText(ownerGoLiveHandoff?.launchSequenceCount, String(goLiveLaunchSequence.length)),
      launchSequenceCommandCount: asText(ownerGoLiveHandoff?.launchSequenceCommandCount, "0"),
      launchSequenceExpectedReportPathCount: asText(ownerGoLiveHandoff?.launchSequenceExpectedReportPathCount, "0"),
      rollbackCommandCount: asText(ownerGoLiveHandoff?.rollbackCommandCount, String(goLiveRollbackCommands.length)),
      mustNotSendCount: asText(ownerGoLiveHandoff?.mustNotSendCount, "0"),
      missingEnvNames: uniqueTexts(ownerGoLiveHandoff?.missingEnvNames),
      invalidEnvNames: uniqueTexts(ownerGoLiveHandoff?.invalidEnvNames),
      nextOwnerInputNames: uniqueTexts(ownerGoLiveHandoff?.nextOwnerInputNames),
      requiredOwnerEnvNames: uniqueTexts(ownerGoLiveHandoff?.requiredOwnerEnvNames),
      optionalOwnerEnvNames: uniqueTexts(ownerGoLiveHandoff?.optionalOwnerEnvNames),
      nextCommands: commandList(ownerGoLiveHandoff?.nextCommands, 10),
      forbiddenItems: goLiveForbiddenItems,
      externalResources: uniqueTexts(ownerGoLiveHandoff?.externalResources),
      stages: goLiveStages,
      launchSequence: goLiveLaunchSequence,
      rollbackCommands: goLiveRollbackCommands,
      checks: ownerGoLiveHandoff?.checks ?? {},
      failedChecks: uniqueTexts(ownerGoLiveHandoff?.failedChecks),
      noSecrets: ownerGoLiveHandoff?.noSecrets === true,
      broadcasts: ownerGoLiveHandoff?.broadcasts === true,
      envValuesPrinted: ownerGoLiveHandoff?.envValuesPrinted === true,
    },
    ownerNeedsNow: {
      status: asText(ownerNeedsNow?.status, "not recorded"),
      launchReadinessStatus: asText(ownerNeedsNow?.launchReadinessStatus, "not recorded"),
      releaseReady: ownerNeedsNow?.releaseReady === true,
      deploymentReady: ownerNeedsNow?.deploymentReady === true,
      packetShareable: ownerNeedsNow?.packetShareable === true,
      completionReady: ownerNeedsNow?.completionReady === true,
      latestHeight: asText(ownerNeedsNow?.latestHeight, latestHeight),
      finalizedHeight: asText(ownerNeedsNow?.finalizedHeight, finalizedHeight),
      groupCount: asText(ownerNeedsNow?.groupCount, String(ownerNeedGroups.length)),
      neededNowGroupCount: asText(ownerNeedsNow?.neededNowGroupCount, String(ownerNeededNowGroups.length)),
      readyGroupCount: asText(ownerNeedsNow?.readyGroupCount, String(ownerReadyGroups.length)),
      nextOwnerInputNames: uniqueTexts(ownerNeedsNow?.nextOwnerInputNames),
      missingRequiredEnvNames: uniqueTexts(ownerNeedsNow?.missingRequiredEnvNames),
      missingOptionalEnvNames: uniqueTexts(ownerNeedsNow?.missingOptionalEnvNames),
      invalidEnvNames: uniqueTexts(ownerNeedsNow?.invalidEnvNames),
      groups: ownerNeedGroups,
      neededNowGroups: ownerNeededNowGroups,
      readyGroups: ownerReadyGroups,
      checks: ownerNeedsNow?.checks ?? {},
      failedChecks: uniqueTexts(ownerNeedsNow?.failedChecks),
      noSecrets: ownerNeedsNow?.noSecrets === true,
      broadcasts: ownerNeedsNow?.broadcasts === true,
      envValuesPrinted: ownerNeedsNow?.envValuesPrinted === true,
    },
    testerLaunch: {
      status: asText(externalTesterPacket?.status ?? externalTesterReadiness?.status, "not recorded"),
      readinessStatus: asText(externalTesterReadiness?.status, "not recorded"),
      packetStatus: asText(externalTesterPacket?.status, "not recorded"),
      connectPackStatus: asText(externalTesterConnectPack?.status, "not recorded"),
      gatewayStatus: asText(publicTesterGateway?.status, "not recorded"),
      shareable: externalTesterPacket?.packetShareable === true,
      connectPackShareable: externalTesterPacket?.connectPackShareable === true || externalTesterConnectPack?.shareable === true,
      connectPackReady: connectPackCheckValues.length > 0 && connectPackCheckValues.every((value) => value === true),
      connectPackNetwork: {
        name: sanitizeText(externalTesterConnectPack?.network?.name),
        chainId: sanitizeText(externalTesterConnectPack?.network?.chainId),
        rpcEndpointPlaceholder: sanitizeText(externalTesterConnectPack?.network?.rpcEndpointPlaceholder),
        explorerSummaryUrlPlaceholder: sanitizeText(externalTesterConnectPack?.network?.explorerSummaryUrlPlaceholder),
      },
      externalSharingReady: externalTesterReadiness?.externalSharingReady === true || externalTesterPacket?.externalSharingReady === true,
      localTesterRehearsalReady: externalTesterReadiness?.localTesterRehearsalReady === true,
      liveInfraReady: externalTesterReadiness?.checks?.liveInfraReady === true || opsSnapshot?.reportStatuses?.externalTesterLiveInfraReady === true,
      serviceReady: externalTesterReadiness?.checks?.serviceReady === true || opsSnapshot?.reportStatuses?.externalTesterServiceReady === true,
      chainProducing: externalTesterReadiness?.checks?.chainProducing === true || opsSnapshot?.reportStatuses?.externalTesterChainProducing === true,
      missingOwnerInputCount: asText(opsSnapshot?.reportStatuses?.externalTesterMissingEnvCount ?? asArray(externalTesterReadiness?.missingEnvNames).length, "0"),
      testerCount: asText(opsSnapshot?.reportStatuses?.externalTesterTesterCount ?? externalTesterReadiness?.testerNetwork?.testerCount, "0"),
      publicTesterGatewayReady: externalTesterReadiness?.checks?.publicTesterGatewayReady === true,
      publicTesterGatewayFresh: externalTesterReadiness?.checks?.publicTesterGatewayFresh === true,
      gatewayConfigured: publicTesterGateway?.testerGatewayConfigured === true,
      testerWalletNetworkReady: externalTesterReadiness?.checks?.testerWalletNetworkReady === true,
      testerNetworkFresh: externalTesterReadiness?.checks?.testerWalletNetworkFresh === true,
      faucetRouteValidated: externalTesterReadiness?.checks?.publicTesterGatewayFaucetRouteValidated === true,
      packetExecutableSmokeValidated: externalTesterPacket?.packetExecutableSmokeValidated === true || externalTesterReadiness?.checks?.packetExecutableSmokeValidated === true,
      packetSmokeRoutes: asArray(externalTesterPacket?.packetSmokeRoutes).map((route) => sanitizeText(route)),
      connectPackReadOnlyRoutes: asArray(externalTesterConnectPack?.endpoints?.readOnlyRoutes).map((route) => sanitizeText(route)),
      connectPackTesterWriteRoutes: asArray(externalTesterConnectPack?.endpoints?.testerWriteRoutes).map((route) => sanitizeText(route)),
      gatewayRoutes: asArray(publicTesterGateway?.routes).map((route) => sanitizeText(route)),
      ownerInputGroups: Object.fromEntries(
        recordEntries(
          ownerInputSummaries.reduce((groups, input) => {
            groups[input.group] = [...(groups[input.group] ?? []), input.name];
            return groups;
          }, {}),
        ),
      ),
      commands: {
        readiness: [
          "npm run flowchain:tester:readiness -- -AllowBlocked",
          "npm run flowchain:external-tester:packet -- -AllowBlocked",
        ],
        gateway: ["npm run flowchain:tester:gateway:e2e"],
        wallet: ["npm run flowchain:wallet:live-tester:e2e"],
        explorer: ["npm run flowchain:public-deployment:contract -- -AllowBlocked"],
        publicRpc: ["npm run flowchain:public-rpc:command-matrix"],
      },
      envValuesPrinted: false,
      noSecrets: publicTesterGateway?.noSecrets === true,
    },
    ownerInputs: ownerInputSummaries,
    gates,
    commands: {
      preExposure: commandList(contract?.operatorCommands?.preExposure, 12),
      rollback: commandList(contract?.operatorCommands?.rollback, 10),
    },
    sourceReports: liveReadinessReportCopies.map((fileName) => sourceReportSummary(fileName, reports[fileName])),
    envValuesPrinted: false,
    noSecrets: true,
  };

  writeFileSync(resolve(destinationDir, "flowchain-live-readiness-report.json"), `${JSON.stringify(liveReadiness, null, 2)}\n`);
  console.log(`Synced FlowChain live readiness dashboard report: ${resolve(destinationDir, "flowchain-live-readiness-report.json")}`);
}

mkdirSync(destinationDir, { recursive: true });

for (const fixture of fixtureCopies) {
  if (!existsSync(fixture.source)) {
    throw new Error(`Missing ${fixture.label}: ${fixture.source}`);
  }
  copyFileSync(fixture.source, fixture.destination);
  console.log(`Synced ${fixture.label}: ${fixture.destination}`);
}

writeLiveReadinessSummary();
