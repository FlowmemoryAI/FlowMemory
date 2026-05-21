# FlowChain Ops Metrics Export

Generated: 2026-05-21T13:24:18.7364249Z
Status: passed

This export converts existing no-secret ops evidence into owner-collector friendly JSON and Prometheus textfile metrics. It does not send network notifications or store external delivery credentials.

- Metrics JSON: `docs/agent-runs/live-product-infra-rpc/ops-metrics.json`
- Prometheus textfile: `docs/agent-runs/live-product-infra-rpc/ops-metrics.prom.txt`
- Metric count: 334

## Required Metrics

- flowchain_latest_height: present
- flowchain_finalized_height: present
- flowchain_state_file_age_seconds: present
- flowchain_height_advanced: present
- flowchain_mempool_depth: present
- flowchain_transaction_intake_rows_total: present
- flowchain_transaction_intake_accepted_rows_total: present
- flowchain_transaction_intake_invalid_rows: present
- flowchain_transaction_intake_file_age_seconds: present
- flowchain_runtime_submit_fixtures_total: present
- flowchain_runtime_inbox_files_total: present
- flowchain_ops_critical_findings: present
- flowchain_ops_blocked_findings: present
- flowchain_ops_alert_rules_total: present
- flowchain_ops_active_alert_rules: present
- flowchain_service_status_ready: present
- flowchain_service_install_validation_ready: present
- flowchain_service_install_failed_checks: present
- flowchain_service_install_missing_scripts: present
- flowchain_service_install_plan_did_not_mutate: present
- flowchain_service_install_live_profile_default: present
- flowchain_service_install_bridge_relayer_opt_in: present
- flowchain_service_install_status_read_only: present
- flowchain_service_install_no_secrets: present
- flowchain_service_install_no_broadcasts: present
- flowchain_systemd_service_install_validation_ready: present
- flowchain_systemd_service_install_failed_checks: present
- flowchain_systemd_service_install_rendered_units: present
- flowchain_systemd_service_install_autorecovery_loop: present
- flowchain_systemd_service_install_restart_always: present
- flowchain_systemd_service_install_hardening: present
- flowchain_systemd_service_install_no_secrets: present
- flowchain_systemd_service_install_no_broadcasts: present
- flowchain_public_rpc_ready: present
- flowchain_public_rpc_synthetic_canary_ready: present
- flowchain_public_rpc_synthetic_canary_probe_count: present
- flowchain_public_rpc_synthetic_canary_failed_probes: present
- flowchain_public_rpc_synthetic_canary_missing_owner_inputs: present
- flowchain_public_rpc_synthetic_canary_no_write_methods: present
- flowchain_public_rpc_live_security_header_probe: present
- flowchain_public_rpc_live_security_headers: present
- flowchain_public_rpc_security_header_policy_ready: present
- flowchain_public_rpc_deployment_bundle_ready: present
- flowchain_public_rpc_deployment_automation_ready: present
- flowchain_public_rpc_command_matrix_ready: present
- flowchain_public_rpc_command_matrix_commands_total: present
- flowchain_public_rpc_command_matrix_owner_host_commands: present
- flowchain_public_rpc_command_matrix_mutating_owner_host_commands: present
- flowchain_public_rpc_command_matrix_missing_scripts: present
- flowchain_public_rpc_command_matrix_phase_gaps: present
- flowchain_public_rpc_command_matrix_rollback_coverage: present
- flowchain_public_rpc_command_matrix_no_secrets: present
- flowchain_public_rpc_disallowed_origin_preflight: present
- flowchain_public_rpc_broad_state_blocked_preflight: present
- flowchain_public_rpc_private_wallet_create_blocked_preflight: present
- flowchain_public_rpc_auth_forwarding_scoped: present
- flowchain_public_rpc_security_headers: present
- flowchain_public_rpc_security_header_preflight: present
- flowchain_public_rpc_timeout_guardrails: present
- flowchain_public_rpc_timeout_guardrail_preflight: present
- flowchain_public_rpc_wallet_cutover_commands: present
- flowchain_public_rpc_rendered_security_headers: present
- flowchain_public_rpc_rendered_security_header_preflight: present
- flowchain_public_rpc_rendered_timeout_guardrails: present
- flowchain_public_rpc_rendered_timeout_guardrail_preflight: present
- flowchain_public_rpc_command_plan_wallet_cutover_proof: present
- flowchain_public_rpc_command_plan_tester_gateway_e2e: present
- flowchain_public_rpc_command_plan_wallet_tester_e2e: present
- flowchain_public_rpc_command_plan_synthetic_canary: present
- flowchain_public_rpc_command_plan_cutover_rehearsal: present
- flowchain_public_rpc_command_plan_truth_table: present
- flowchain_public_rpc_command_plan_no_secret_scan: present
- flowchain_public_rpc_owner_host_apply_plan_ready: present
- flowchain_public_rpc_owner_host_apply_script_rendered: present
- flowchain_public_rpc_owner_host_apply_script_modes: present
- flowchain_public_rpc_owner_host_apply_script_hashes: present
- flowchain_public_rpc_owner_host_apply_script_post_deploy: present
- flowchain_public_rpc_owner_host_apply_script_in_plan: present
- flowchain_public_rpc_windows_owner_host_apply_script_rendered: present
- flowchain_public_rpc_windows_owner_host_apply_script_modes: present
- flowchain_public_rpc_windows_owner_host_apply_script_parses: present
- flowchain_public_rpc_windows_owner_host_apply_script_hashes: present
- flowchain_public_rpc_windows_owner_host_apply_script_post_deploy: present
- flowchain_public_rpc_windows_owner_host_apply_script_in_plan: present
- flowchain_public_rpc_owner_host_artifacts_hashed: present
- flowchain_public_rpc_owner_host_install_targets_mapped: present
- flowchain_public_rpc_owner_host_systemd_install_command: present
- flowchain_public_rpc_owner_host_nginx_reload_command: present
- flowchain_public_rpc_owner_host_post_deploy_evidence: present
- flowchain_public_rpc_rollback_drill_ready: present
- flowchain_public_rpc_rollback_drill_performed: present
- flowchain_public_rpc_rollback_restored_previous: present
- flowchain_public_rpc_rollback_restored_original: present
- flowchain_public_rpc_rollback_artifacts_scoped: present
- flowchain_public_rpc_rollback_no_secrets: present
- flowchain_public_rpc_rollback_no_broadcasts: present
- flowchain_backup_ready: present
- flowchain_backup_retention_count: present
- flowchain_backup_retention_candidates: present
- flowchain_backup_retention_snapshot_protected: present
- flowchain_backup_retention_prune_errors: present
- flowchain_backup_restore_validation_ready: present
- flowchain_backup_restore_validation_failed_checks: present
- flowchain_backup_restore_validation_missing_checks: present
- flowchain_backup_restore_validation_secret_findings: present
- flowchain_backup_restore_hash_round_trip: present
- flowchain_backup_restore_live_state_protected: present
- flowchain_backup_restore_retention_protected: present
- flowchain_backup_owner_path_dry_run_ready: present
- flowchain_backup_owner_path_dry_run_failed_checks: present
- flowchain_backup_owner_path_dry_run_missing_checks: present
- flowchain_backup_owner_path_dry_run_secret_findings: present
- flowchain_backup_owner_path_dry_run_snapshot_proof: present
- flowchain_backup_owner_path_dry_run_restore_proof: present
- flowchain_backup_owner_path_dry_run_live_state_protected: present
- flowchain_backup_owner_path_dry_run_no_mutation: present
- flowchain_backup_owner_path_dry_run_no_secrets: present
- flowchain_bridge_live_ready: present
- flowchain_bridge_infra_ready: present
- flowchain_bridge_command_matrix_ready: present
- flowchain_bridge_command_matrix_commands_total: present
- flowchain_bridge_command_matrix_live_broadcast_commands: present
- flowchain_bridge_command_matrix_missing_scripts: present
- flowchain_bridge_command_matrix_broadcast_ack_gaps: present
- flowchain_bridge_command_matrix_no_secrets: present
- flowchain_bridge_no_secret_audit_ready: present
- flowchain_bridge_no_secret_audit_scanned_files: present
- flowchain_bridge_no_secret_audit_findings: present
- flowchain_bridge_no_secret_audit_secret_findings: present
- flowchain_bridge_no_secret_audit_failed_checks: present
- flowchain_bridge_no_secret_audit_no_broadcasts: present
- flowchain_bridge_deploy_control_validation_ready: present
- flowchain_bridge_deploy_control_failed_checks: present
- flowchain_bridge_deploy_control_missing_checks: present
- flowchain_bridge_deploy_control_missing_env_fail_closed: present
- flowchain_bridge_deploy_control_requires_broadcast_ack: present
- flowchain_bridge_deploy_control_pause_resume_emergency: present
- flowchain_bridge_deploy_control_runbook_rollback: present
- flowchain_bridge_deploy_control_no_secrets: present
- flowchain_bridge_deploy_control_no_broadcasts: present
- flowchain_bridge_relayer_guardrail_ready: present
- flowchain_bridge_direct_observe_guardrail_ready: present
- flowchain_bridge_direct_observe_staged_cursor_default: present
- flowchain_bridge_direct_observe_cursor_not_final: present
- flowchain_bridge_direct_observe_final_cursor_unchanged: present
- flowchain_bridge_direct_observe_staged_cursor_not_written: present
- flowchain_bridge_runtime_credit_ready: present
- flowchain_bridge_runtime_credit_latency_seconds: present
- flowchain_bridge_runtime_transfer_latency_seconds: present
- flowchain_bridge_runtime_credit_failed_checks: present
- flowchain_bridge_runtime_credit_missing_checks: present
- flowchain_bridge_runtime_credit_false_checks: present
- flowchain_bridge_reconciliation_ready: present
- flowchain_bridge_reconciliation_rows_total: present
- flowchain_bridge_reconciliation_failed_checks: present
- flowchain_bridge_reconciliation_observed_credits: present
- flowchain_bridge_reconciliation_new_credits: present
- flowchain_bridge_reconciliation_queued_transactions: present
- flowchain_bridge_reconciliation_applied_credits: present
- flowchain_bridge_reconciliation_pending_credits: present
- flowchain_bridge_reconciliation_cursor_staged: present
- flowchain_bridge_reconciliation_cursor_committed: present
- flowchain_bridge_reconciliation_cursor_not_committed_when_blocked: present
- flowchain_bridge_reconciliation_runtime_credit_applied: present
- flowchain_bridge_reconciliation_replay_rejected: present
- flowchain_bridge_reconciliation_release_evidence_validated: present
- flowchain_bridge_reconciliation_no_secrets: present
- flowchain_bridge_reconciliation_no_broadcasts: present
- flowchain_bridge_release_evidence_validation_ready: present
- flowchain_bridge_release_evidence_cases_total: present
- flowchain_bridge_release_evidence_failed_cases: present
- flowchain_bridge_release_evidence_missing_cases: present
- flowchain_bridge_release_evidence_failed_checks: present
- flowchain_bridge_release_evidence_secret_findings: present
- flowchain_bridge_release_evidence_release_broadcast_rejected: present
- flowchain_bridge_release_evidence_withdrawal_broadcast_rejected: present
- flowchain_bridge_release_evidence_no_broadcasts: present
- flowchain_bridge_release_evidence_no_secrets: present
- flowchain_real_value_pilot_aggregate_ready: present
- flowchain_real_value_pilot_aggregate_commands_total: present
- flowchain_real_value_pilot_aggregate_timed_out_commands: present
- flowchain_real_value_pilot_aggregate_failed_commands: present
- flowchain_real_value_pilot_aggregate_missing_proofs: present
- flowchain_real_value_pilot_aggregate_owner_go_no_go: present
- flowchain_bridge_relayer_loop_healthy: present
- flowchain_bridge_relayer_loop_validation_ready: present
- flowchain_bridge_relayer_loop_failed_checks: present
- flowchain_bridge_relayer_loop_secret_findings: present
- flowchain_bridge_relayer_loop_poll_seconds: present
- flowchain_bridge_relayer_loop_settle_seconds: present
- flowchain_bridge_relayer_loop_report_fresh: present
- flowchain_bridge_relayer_loop_blocked_only_owner_inputs: present
- flowchain_bridge_relayer_loop_pid_cleanup_verified: present
- flowchain_bridge_relayer_loop_no_secrets: present
- flowchain_bridge_relayer_loop_no_broadcasts: present
- flowchain_supervisor_bridge_relayer_requested: present
- flowchain_supervisor_bridge_relayer_recovery_healthy: present
- flowchain_supervisor_node_recovery_validated: present
- flowchain_supervisor_node_restart_attempts: present
- flowchain_supervisor_node_crash_detected: present
- flowchain_supervisor_node_recovery_live_profile: present
- flowchain_supervisor_node_recovery_unbounded: present
- flowchain_external_tester_ready: present
- flowchain_external_tester_local_rehearsal_ready: present
- flowchain_external_tester_external_sharing_ready: present
- flowchain_external_tester_public_gateway_ready: present
- flowchain_external_tester_faucet_route_validated: present
- flowchain_external_tester_live_infra_ready: present
- flowchain_external_tester_missing_owner_inputs: present
- flowchain_public_tester_gateway_e2e_ready: present
- flowchain_public_tester_gateway_accounts_total: present
- flowchain_public_tester_gateway_failed_checks: present
- flowchain_public_tester_gateway_routes_total: present
- flowchain_public_tester_gateway_transfer_applied: present
- flowchain_public_tester_gateway_cap_rejected: present
- flowchain_public_tester_gateway_routes_covered: present
- flowchain_public_tester_gateway_no_secrets: present
- flowchain_public_tester_gateway_no_broadcasts: present
- flowchain_external_tester_client_validation_ready: present
- flowchain_external_tester_client_failed_checks: present
- flowchain_external_tester_client_secret_findings: present
- flowchain_external_tester_client_dry_run_no_network: present
- flowchain_external_tester_client_routes_cover_reads: present
- flowchain_external_tester_client_routes_cover_writes: present
- flowchain_external_tester_client_no_token_configured: present
- flowchain_external_tester_client_no_broadcasts: present
- flowchain_external_tester_client_no_secrets: present
- flowchain_external_tester_client_env_values_hidden: present
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
- flowchain_dashboard_ui_tester_launch_covered: present
- flowchain_dashboard_ui_activation_covered: present
- flowchain_second_computer_ready: present
- flowchain_second_computer_bundle_created: present
- flowchain_second_computer_bundle_sha256_present: present
- flowchain_second_computer_stage_no_secret_ready: present
- flowchain_second_computer_verify_checks_passed: present
- flowchain_second_computer_failed_checks: present
- flowchain_second_computer_missing_next_commands: present
- flowchain_second_computer_failed_verify_checks: present
- flowchain_second_computer_secret_findings: present
- flowchain_second_computer_no_secrets: present
- flowchain_second_computer_no_broadcasts: present
- flowchain_dev_pack_ready: present
- flowchain_dev_pack_failed_checks: present
- flowchain_dev_pack_methods_total: present
- flowchain_dev_pack_public_ready_methods: present
- flowchain_dev_pack_language_sdks_total: present
- flowchain_dev_pack_python_sdk_ready: present
- flowchain_dev_pack_browser_starter_packaged: present
- flowchain_dev_pack_browser_starter_build_ready: present
- flowchain_dev_pack_browser_starter_smoke_ready: present
- flowchain_dev_pack_public_readiness_fail_closed: present
- flowchain_dev_pack_no_secrets: present
- flowchain_owner_inputs_validation_ready: present
- flowchain_owner_inputs_validation_scenarios_total: present
- flowchain_owner_inputs_validation_scenarios_failed: present
- flowchain_owner_inputs_required_env_total: present
- flowchain_owner_activation_plan_ready: present
- flowchain_owner_activation_ready: present
- flowchain_owner_activation_stages_total: present
- flowchain_owner_activation_ready_stages: present
- flowchain_owner_activation_missing_env_total: present
- flowchain_owner_activation_invalid_env_total: present
- flowchain_owner_go_live_handoff_ready: present
- flowchain_owner_go_live_release_ready: present
- flowchain_owner_go_live_stages_total: present
- flowchain_owner_go_live_next_inputs_total: present
- flowchain_owner_go_live_missing_required_inputs: present
- flowchain_owner_go_live_missing_optional_inputs: present
- flowchain_owner_go_live_next_optional_inputs: present
- flowchain_owner_go_live_input_separation_ready: present
- flowchain_owner_go_live_failed_checks: present
- flowchain_owner_go_live_launch_sequence_ready: present
- flowchain_owner_go_live_launch_sequence_steps: present
- flowchain_owner_go_live_launch_sequence_commands: present
- flowchain_owner_go_live_launch_evidence_reports: present
- flowchain_owner_go_live_launch_invalid_evidence_reports: present
- flowchain_owner_go_live_launch_missing_package_scripts: present
- flowchain_owner_go_live_owner_host_apply_plan: present
- flowchain_owner_go_live_owner_host_apply_execution: present
- flowchain_owner_go_live_owner_host_apply_rollback: present
- flowchain_owner_go_live_windows_owner_host_apply_plan: present
- flowchain_owner_go_live_windows_owner_host_apply_execution: present
- flowchain_owner_go_live_windows_owner_host_apply_rollback: present
- flowchain_owner_go_live_rollback_ready: present
- flowchain_owner_go_live_rollback_commands: present
- flowchain_owner_go_live_rollback_missing_package_scripts: present
- flowchain_owner_needs_now_ready: present
- flowchain_owner_needs_now_launch_ready: present
- flowchain_owner_needs_now_groups_total: present
- flowchain_owner_needs_now_blocked_groups: present
- flowchain_owner_needs_now_ready_groups: present
- flowchain_owner_needs_now_next_inputs_total: present
- flowchain_owner_needs_now_missing_required_inputs: present
- flowchain_owner_needs_now_failed_checks: present
- flowchain_owner_needs_now_public_sharing_blocked_until_ready: present
- flowchain_public_deployment_ready: present
- flowchain_live_cutover_ready: present
- flowchain_live_cutover_tester_network_e2e_passed: present
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
| serviceInstallValidationLoaded | True |
| systemdServiceInstallValidationLoaded | True |
| publicRpcSyntheticCanaryLoaded | True |
| backupRestoreValidationLoaded | True |
| backupOwnerPathDryRunLoaded | True |
| externalTesterLoaded | True |
| publicTesterGatewayLoaded | True |
| externalTesterClientValidationLoaded | True |
| externalTesterEvidenceLoaded | True |
| bridgeCommandMatrixLoaded | True |
| bridgeNoSecretAuditLoaded | True |
| bridgeDeployControlLoaded | True |
| bridgeRelayerLoopValidationLoaded | True |
| bridgeReconciliationLoaded | True |
| bridgeReleaseEvidenceValidationLoaded | True |
| dashboardUiLoaded | True |
| secondComputerLoaded | True |
| devPackLoaded | True |
| ownerInputsValidationLoaded | True |
| ownerActivationPlanLoaded | True |
| ownerGoLiveHandoffLoaded | True |
| ownerNeedsNowLoaded | True |
| publicRpcCommandMatrixLoaded | True |
| liveCutoverLoaded | True |
| truthTableLoaded | True |
| noSecretLoaded | True |
| metricsJsonWritten | True |
| prometheusTextWritten | True |
| markdownWritten | True |
| metricCountSufficient | True |
| requiredMetricsPresent | True |
| backupRestoreValidationMetricsPresent | True |
| backupOwnerPathDryRunMetricsPresent | True |
| serviceInstallValidationMetricsPresent | True |
| externalTesterEvidenceMetricsPresent | True |
| bridgeDirectObserveMetricsPresent | True |
| bridgeCommandMatrixMetricsPresent | True |
| bridgeNoSecretAuditMetricsPresent | True |
| bridgeRuntimeCreditMetricsPresent | True |
| bridgeReconciliationMetricsPresent | True |
| bridgeDeployControlMetricsPresent | True |
| bridgeReleaseEvidenceMetricsPresent | True |
| realValuePilotAggregateMetricsPresent | True |
| bridgeRelayerLoopValidationMetricsPresent | True |
| publicRpcEdgeMetricsPresent | True |
| publicRpcCommandMatrixMetricsPresent | True |
| publicRpcRollbackDrillMetricsPresent | True |
| publicRpcOwnerHostApplyPlanMetricsPresent | True |
| publicTesterGatewayMetricsPresent | True |
| externalTesterClientMetricsPresent | True |
| transactionIntakeMetricsPresent | True |
| dashboardUiMetricsPresent | True |
| secondComputerMetricsPresent | True |
| devPackMetricsPresent | True |
| ownerInputsValidationMetricsPresent | True |
| ownerActivationPlanMetricsPresent | True |
| ownerGoLiveHandoffMetricsPresent | True |
| ownerNeedsNowMetricsPresent | True |
| liveCutoverMetricsPresent | True |
| supervisorNodeRecoveryMetricsPresent | True |
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
