# FlowChain Ops Metrics Export

Generated: 2026-05-18T02:25:33.6970191Z
Status: passed

This export converts existing no-secret ops evidence into owner-collector friendly JSON and Prometheus textfile metrics. It does not send network notifications or store external delivery credentials.

- Metrics JSON: `docs/agent-runs/live-product-infra-rpc/ops-metrics.json`
- Prometheus textfile: `docs/agent-runs/live-product-infra-rpc/ops-metrics.prom.txt`
- Metric count: 28

## Required Metrics

- flowchain_latest_height: present
- flowchain_finalized_height: present
- flowchain_state_file_age_seconds: present
- flowchain_height_advanced: present
- flowchain_ops_critical_findings: present
- flowchain_ops_blocked_findings: present
- flowchain_ops_alert_rules_total: present
- flowchain_ops_active_alert_rules: present
- flowchain_service_status_ready: present
- flowchain_public_rpc_ready: present
- flowchain_backup_ready: present
- flowchain_bridge_live_ready: present
- flowchain_bridge_relayer_guardrail_ready: present
- flowchain_public_deployment_ready: present
- flowchain_no_secret_ready: present
- flowchain_truth_gates_total: present
- flowchain_truth_gates_failed: present
- flowchain_truth_gates_stale: present

## Checks

| Check | Result |
| --- | --- |
| packageScriptPresent | True |
| opsSnapshotLoaded | True |
| opsAlertRulesLoaded | True |
| serviceStatusLoaded | True |
| serviceMonitorLoaded | True |
| truthTableLoaded | True |
| noSecretLoaded | True |
| metricsJsonWritten | True |
| prometheusTextWritten | True |
| markdownWritten | True |
| metricCountSufficient | True |
| requiredMetricsPresent | True |
| prometheusHasHelpAndType | True |
| prometheusContainsNoUrls | True |
| prometheusContainsNoEnvAssignments | True |
| metricsJsonNoSecrets | True |
| metricsJsonEnvValuesPrintedFalse | True |
| metricsJsonBroadcastsFalse | True |
| envValuesPrintedFalse | True |
| noSecrets | True |
| broadcastsFalse | True |
