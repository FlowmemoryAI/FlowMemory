# FlowChain Monitoring Bundle

Generated: 2026-05-21T15:34:10.7303144Z
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
| `docs/agent-runs/live-product-infra-rpc/monitoring-bundle/README.md` | `da9f8a85fbb548deee55284c4ebd82c22f79b17f49acd63ddc3ac6cef186143a` | 895 |
| `docs/agent-runs/live-product-infra-rpc/monitoring-bundle/flowchain-monitoring-bundle-manifest.json` | `97240e223ed19e0d64f578d34b47eab03adb801736f6931ebc2363725f717d15` | 1848 |

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
