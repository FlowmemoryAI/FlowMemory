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
  "public-rpc-deployment-bundle-report.json",
  "public-rpc-deployment-automation-report.json",
  "public-rpc-readiness-report.json",
  "backup-readiness-report.json",
  "backup-owner-path-dry-run-report.json",
  "bridge-relayer-once-report.json",
  "bridge-relayer-guardrail-validation-report.json",
  "bridge-relayer-loop-validation-report.json",
  "bridge-runtime-credit-validation-report.json",
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
  "owner-activation-plan-report.json",
  "no-secret-scan-report.json",
];

const liveReadinessGateLabels = new Map([
  ["private-service-origin", "Private L1 origin"],
  ["pre-share-monitoring", "Block production monitor"],
  ["service-autorecovery", "Service autorecovery"],
  ["service-install-automation", "Windows service install"],
  ["public-rpc-edge", "Public RPC edge"],
  ["state-backup", "State backup proof"],
  ["state-backup-owner-path-dry-run", "Backup dry run"],
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
  const bridgeRelayer = reports["bridge-relayer-once-report.json"];
  const bridgeRelayerGuardrail = reports["bridge-relayer-guardrail-validation-report.json"];
  const bridgeRelayerLoopValidation = reports["bridge-relayer-loop-validation-report.json"];
  const bridgeRuntimeCreditValidation = reports["bridge-runtime-credit-validation-report.json"];
  const backupOwnerPathDryRun = reports["backup-owner-path-dry-run-report.json"];
  const publicRpcDeploymentBundle = reports["public-rpc-deployment-bundle-report.json"];
  const publicRpcDeploymentAutomation = reports["public-rpc-deployment-automation-report.json"];
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
  const ownerActivationPlan = reports["owner-activation-plan-report.json"];
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
  const activationStages = asArray(ownerActivationPlan?.stages).map((stage) => ({
    id: sanitizeText(stage?.id),
    title: sanitizeText(stage?.title),
    status: sanitizeText(stage?.status),
    ready: stage?.ready === true,
    requiredEnvNames: uniqueTexts(stage?.requiredEnvNames),
    optionalEnvNames: uniqueTexts(stage?.optionalEnvNames),
    missingEnvNames: uniqueTexts(stage?.missingEnvNames),
    invalidEnvNames: uniqueTexts(stage?.invalidEnvNames),
    externalAccountsOrResources: uniqueTexts(stage?.externalAccountsOrResources),
    ownerMustDo: uniqueTexts(stage?.ownerMustDo),
    ownerMustNotSend: uniqueTexts(stage?.ownerMustNotSend),
    validationCommands: commandList(stage?.validationCommands, 8),
    sourceReports: asArray(stage?.sourceReports).map((sourceReport) => ({
      name: sanitizeText(sourceReport?.name),
      status: sanitizeText(sourceReport?.status),
      path: sanitizeText(sourceReport?.path),
    })),
  }));
  const activationForbiddenItems = uniqueTexts(activationStages.flatMap((stage) => stage.ownerMustNotSend));
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
      bridgeRelayerStatus: asText(bridgeRelayer?.status, "not recorded"),
      bridgeQueuedTransactions: asText(bridgeRelayer?.counts?.queuedTransactions, "0"),
      bridgeRelayerChildTimeoutSeconds: asText(bridgeRelayer?.childTimeoutSeconds, "not recorded"),
      bridgeRelayerStepCount: bridgeRelayerSteps.length,
      bridgeRelayerTimedOutStepCount: bridgeRelayerTimedOutSteps.length,
      bridgeRelayerNoChildTimeouts: bridgeRelayerSteps.length > 0 && bridgeRelayerTimedOutSteps.length === 0,
      bridgeRelayerCheckContractReady: opsSnapshot?.reportStatuses?.bridgeRelayerCheckContractReady === true,
      bridgeRelayerFailedChecks: asText(opsSnapshot?.reportStatuses?.bridgeRelayerFailedChecks, "0"),
      bridgeRelayerMissingChecks: asText(opsSnapshot?.reportStatuses?.bridgeRelayerMissingChecks, "0"),
      bridgeRelayerGuardrailStatus: asText(bridgeRelayerGuardrail?.status, "not recorded"),
      bridgeRelayerLoopValidationStatus: asText(bridgeRelayerLoopValidation?.status, "not recorded"),
      bridgeRuntimeCreditValidationStatus: asText(bridgeRuntimeCreditValidation?.status, "not recorded"),
      bridgeRuntimeCreditReady: bridgeRuntimeCreditValidation?.status === "passed",
      bridgeRuntimeCreditLatencySeconds: asText(bridgeRuntimeCreditValidation?.timing?.queueToSpendableSeconds, "not recorded"),
      bridgeRuntimeCreditTransferSeconds: asText(bridgeRuntimeCreditValidation?.timing?.transferSettlementSeconds, "not recorded"),
      bridgeRuntimeCreditFailedChecks: asText(asArray(bridgeRuntimeCreditValidation?.failedChecks).length, "0"),
      backupOwnerPathDryRunStatus: asText(backupOwnerPathDryRun?.status, "not recorded"),
      publicRpcDeploymentBundleStatus: asText(publicRpcDeploymentBundle?.status, "not recorded"),
      publicRpcOwnerRenderValidationStatus: asText(publicRpcDeploymentBundle?.renderValidation?.status, "not recorded"),
      publicRpcDeploymentAutomationStatus: asText(publicRpcDeploymentAutomation?.status, "not recorded"),
      publicRpcDeploymentAutomationAction: asText(publicRpcDeploymentAutomation?.action, "not recorded"),
      publicRpcSecurityHeaders: publicRpcDeploymentBundle?.checks?.includesSecurityHeaders === true,
      publicRpcSecurityHeaderPreflight: publicRpcDeploymentBundle?.checks?.preflightsCheckSecurityHeaders === true,
      publicRpcRenderedSecurityHeaders: publicRpcDeploymentAutomation?.checks?.renderedNginxHasSecurityHeaders === true,
      publicRpcRenderedSecurityHeaderPreflight: publicRpcDeploymentAutomation?.checks?.renderedPreflightChecksSecurityHeaders === true,
      externalTesterPacketStatus: asText(externalTesterPacket?.status, "not recorded"),
      externalTesterConnectPackStatus: asText(externalTesterConnectPack?.status, "not recorded"),
      ownerInputReady: ownerInputs?.ownerInputReady === true,
      ownerActivationStatus: asText(ownerActivationPlan?.status, "not recorded"),
      ownerActivationReady: ownerActivationPlan?.activationReady === true,
      ownerActivationStageCount: asText(ownerActivationPlan?.stageCount, String(activationStages.length)),
      ownerActivationReadyStageCount: asText(ownerActivationPlan?.readyStageCount, "0"),
      ownerActivationMissingCount: asArray(ownerActivationPlan?.missingEnvNames).length,
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
      bridgeRelayerCheckContractReady: opsSnapshot?.reportStatuses?.bridgeRelayerCheckContractReady === true,
      bridgeRelayerFailedChecks: asText(opsSnapshot?.reportStatuses?.bridgeRelayerFailedChecks, "0"),
      bridgeRelayerMissingChecks: asText(opsSnapshot?.reportStatuses?.bridgeRelayerMissingChecks, "0"),
      bridgeRelayerGuardrailStatus: asText(opsSnapshot?.reportStatuses?.bridgeRelayerGuardrail ?? bridgeRelayerGuardrail?.status, "not recorded"),
      bridgeRelayerGuardrailReady: opsSnapshot?.reportStatuses?.bridgeRelayerGuardrailReady === true,
      bridgeRuntimeCreditStatus: asText(opsSnapshot?.reportStatuses?.bridgeRuntimeCredit ?? bridgeRuntimeCreditValidation?.status, "not recorded"),
      bridgeRuntimeCreditReady: opsSnapshot?.reportStatuses?.bridgeRuntimeCreditReady === true || bridgeRuntimeCreditValidation?.status === "passed",
      bridgeRuntimeCreditLatencySeconds: asText(opsSnapshot?.reportStatuses?.bridgeRuntimeCreditLatencySeconds ?? bridgeRuntimeCreditValidation?.timing?.queueToSpendableSeconds, "not recorded"),
      bridgeRuntimeTransferLatencySeconds: asText(opsSnapshot?.reportStatuses?.bridgeRuntimeTransferLatencySeconds ?? bridgeRuntimeCreditValidation?.timing?.transferSettlementSeconds, "not recorded"),
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
      stagesNeedingOwnerInputCount: asText(ownerActivationPlan?.stagesNeedingOwnerInputCount, "0"),
      missingEnvNames: uniqueTexts(ownerActivationPlan?.missingEnvNames),
      invalidEnvNames: uniqueTexts(ownerActivationPlan?.invalidEnvNames),
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
