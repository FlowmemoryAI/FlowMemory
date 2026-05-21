# FlowChain Monitoring Bundle

This bundle turns existing no-secret FlowChain ops evidence into owner-operated monitoring files.

- Grafana dashboard: `flowchain-grafana-dashboard.json`
- Prometheus alert rules: `flowchain-prometheus-alerts.yml`
- Source metrics: `docs/agent-runs/live-product-infra-rpc/ops-metrics.json`
- Source alert rules: `docs/agent-runs/live-product-infra-rpc/ops-alert-rules-report.json`

Import the dashboard into the owner Grafana workspace with a Prometheus datasource named `DS_PROMETHEUS`. Load the alert rules into the owner Prometheus-compatible rules path. These files contain metric names, thresholds, and commands only.

Do not put owner credentials, raw tester tokens, private keys, seed words, provider credentials, or rendered owner env files in this bundle.

Regenerate with:

```powershell
npm run flowchain:ops:monitoring:bundle
```
