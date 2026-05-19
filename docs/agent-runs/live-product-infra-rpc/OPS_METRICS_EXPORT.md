# FlowChain Ops Metrics Export

Generated: 2026-05-19T21:51:14.8142686Z
Status: passed

This export converts existing no-secret ops evidence into owner-collector friendly JSON and Prometheus textfile metrics. It does not send network notifications or store external delivery credentials.

- Metrics JSON: `docs/agent-runs/live-product-infra-rpc/ops-metrics.json`
- Prometheus textfile: `docs/agent-runs/live-product-infra-rpc/ops-metrics.prom.txt`
- Metric count: 70

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
- flowchain_public_rpc_deployment_bundle_ready: present
- flowchain_public_rpc_deployment_automation_ready: present
- flowchain_public_rpc_disallowed_origin_preflight: present
- flowchain_public_rpc_broad_state_blocked_preflight: present
- flowchain_public_rpc_private_wallet_create_blocked_preflight: present
- flowchain_public_rpc_auth_forwarding_scoped: present
- flowchain_public_rpc_security_headers: present
- flowchain_public_rpc_security_header_preflight: present
- flowchain_public_rpc_rendered_security_headers: present
- flowchain_public_rpc_rendered_security_header_preflight: present
- flowchain_backup_ready: present
- flowchain_backup_retention_count: present
- flowchain_backup_retention_candidates: present
- flowchain_backup_retention_snapshot_protected: present
- flowchain_backup_retention_prune_errors: present
- flowchain_bridge_live_ready: present
- flowchain_bridge_relayer_guardrail_ready: present
- flowchain_bridge_direct_observe_guardrail_ready: present
- flowchain_bridge_direct_observe_staged_cursor_default: present
- flowchain_bridge_direct_observe_cursor_not_final: present
- flowchain_bridge_direct_observe_final_cursor_unchanged: present
- flowchain_bridge_direct_observe_staged_cursor_not_written: present
- flowchain_bridge_relayer_loop_healthy: present
- flowchain_supervisor_bridge_relayer_requested: present
- flowchain_supervisor_bridge_relayer_recovery_healthy: present
- flowchain_external_tester_evidence_ready: present
- flowchain_external_tester_evidence_failed_checks: present
- flowchain_external_tester_evidence_missing_files: present
- flowchain_external_tester_evidence_secret_findings: present
- flowchain_external_tester_evidence_height_advanced: present
- flowchain_external_tester_evidence_transfer_consistent: present
- flowchain_dashboard_ui_ready: present
- flowchain_dashboard_ui_browser_e2e_ready: present
- flowchain_dashboard_ui_build_ready: present
- flowchain_dashboard_ui_tester_flow_covered: present
- flowchain_owner_inputs_validation_ready: present
- flowchain_owner_inputs_validation_scenarios_total: present
- flowchain_owner_inputs_validation_scenarios_failed: present
- flowchain_owner_inputs_required_env_total: present
- flowchain_public_deployment_ready: present
- flowchain_live_cutover_ready: present
- flowchain_live_cutover_owner_blocked: present
- flowchain_live_cutover_missing_owner_inputs: present
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
| externalTesterEvidenceLoaded | True |
| dashboardUiLoaded | True |
| ownerInputsValidationLoaded | True |
| liveCutoverLoaded | True |
| truthTableLoaded | True |
| noSecretLoaded | True |
| metricsJsonWritten | True |
| prometheusTextWritten | True |
| markdownWritten | True |
| metricCountSufficient | True |
| requiredMetricsPresent | True |
| externalTesterEvidenceMetricsPresent | True |
| bridgeDirectObserveMetricsPresent | True |
| publicRpcEdgeMetricsPresent | True |
| dashboardUiMetricsPresent | True |
| ownerInputsValidationMetricsPresent | True |
| prometheusHasHelpAndType | True |
| prometheusContainsNoUrls | True |
| prometheusContainsNoEnvAssignments | True |
| metricsJsonNoSecrets | True |
| metricsJsonSecretMarkerFindingsEmpty | True |
| metricsJsonEnvValuesPrintedFalse | True |
| metricsJsonBroadcastsFalse | True |
| envValuesPrintedFalse | True |
| secretMarkerFindingsEmpty | True |
| noSecrets | True |
| broadcastsFalse | True |
