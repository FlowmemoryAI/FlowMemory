# FlowChain Monitoring Bundle

Generated: 2026-05-21T17:05:58.4769952Z
Status: passed

This bundle renders owner-operated Grafana and Prometheus files from existing no-secret FlowChain metrics and alert-rule evidence. It does not send network notifications or store external delivery credentials.

- Dashboard panels: 20
- Prometheus alert rules: 12
- Source metrics: 334
- Source alert rules: 44

## Artifacts

| Artifact | SHA256 | Bytes |
| --- | --- | --- |
| `docs/agent-runs/live-product-infra-rpc/monitoring-bundle/flowchain-grafana-dashboard.json` | `34a066020715a97aeee657d6320113b531e4633209d57d94cced0f018906bee0` | 77464 |
| `docs/agent-runs/live-product-infra-rpc/monitoring-bundle/flowchain-prometheus-alerts.yml` | `4c83bd377bbd421f87c679243dafe458e70501bd50c07aff7d357983cf7a43e9` | 5734 |
| `docs/agent-runs/live-product-infra-rpc/monitoring-bundle/README.md` | `8735165c40a91065a4d2c3adcb3befd32385c678750f330e938a9192e477f26b` | 975 |
| `docs/agent-runs/live-product-infra-rpc/monitoring-bundle/flowchain-monitoring-bundle-manifest.json` | `ff06131cd6a4cda63a270f16290ecdc6922f73fedfcd9af17494352df080729c` | 1986 |

## Checks

| Check | Result |
| --- | --- |
| packageScriptPresent | True |
| metricsJsonLoaded | True |
| metricsExportReportLoaded | True |
| alertRulesLoaded | True |
| sourceMetricsSufficient | True |
| sourceAlertRulesSufficient | True |
| dashboardWritten | True |
| dashboardJsonValid | True |
| dashboardPanelCountSufficient | True |
| dashboardTargetsHaveKnownMetrics | True |
| dashboardIncludesCorePanels | True |
| prometheusRulesWritten | True |
| prometheusYamlHasRules | True |
| prometheusRuleCountSufficient | True |
| prometheusRulesReferenceKnownMetrics | True |
| prometheusRulesReferenceKnownAlertRuleIds | True |
| prometheusRulesHaveRunbookCommands | True |
| prometheusCommandsAvoidInlineEnvAssignment | True |
| prometheusCommandsAvoidUrls | True |
| readmeWritten | True |
| manifestWritten | True |
| artifactHashesPresent | True |
| filesNoSecretMarkers | True |
| noNetworkDelivery | True |
| envValuesPrintedFalse | True |
| noSecrets | True |
| broadcastsFalse | True |
