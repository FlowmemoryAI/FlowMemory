# FlowChain Node Operator Guide

Status: local/private operator guide with public deployment boundaries.

## Local Service

```powershell
npm run flowchain:service:start -- -LiveProfile
npm run flowchain:service:status -- -AllowBlocked
npm run flowchain:service:monitor -- -AllowBlocked
npm run flowchain:service:restart -- -LiveProfile
npm run flowchain:service:stop
```

Healthy local service evidence includes a running node, running control plane,
fresh state file writes, and advancing height.

## Service Supervisor

Use the repo-native supervisor on the owner host to keep the local/private L1
service alive after process exits or stale state evidence:

```powershell
npm run flowchain:service:supervisor -- -IntervalSeconds 30 -MaxRestartAttempts 3
npm run flowchain:service:supervisor:validate
```

The supervisor checks `flowchain:service:status`, requires live profile by
default, restarts with `flowchain:service:restart -- -LiveProfile`, and writes
redacted reports under `docs/agent-runs/live-product-infra-rpc/`.

## Public RPC Boundary

FlowChain public RPC is repo-owned. There is no third-party FlowChain RPC
provider to sign up for. The owner must deploy an HTTPS edge in front of the
private origin and configure:

- `FLOWCHAIN_RPC_PUBLIC_URL`
- `FLOWCHAIN_RPC_ALLOWED_ORIGINS`
- `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`
- `FLOWCHAIN_RPC_TLS_TERMINATED`
- `FLOWCHAIN_RPC_STATE_BACKUP_PATH`

Use:

```powershell
npm run flowchain:public-rpc:deployment-bundle
npm run flowchain:public-rpc:validate
npm run flowchain:public-rpc:abuse-test
npm run flowchain:public-rpc:check -- -AllowBlocked
```

The generated bundle includes systemd, NGINX, verification, rollback, and
preflight artifacts under `docs/agent-runs/live-product-infra-rpc/`.

## Backup And Restore

```powershell
npm run flowchain:backup:create
npm run flowchain:backup:restore:verify
npm run flowchain:backup:restore:validate
npm run flowchain:backup:check -- -AllowBlocked
```

Backups must write readable snapshots, readable manifests, an atomically written
latest pointer, and matching manifest hashes. Restore validation must prove
missing artifact, tampered manifest, corrupt restore, wrong-chain restore, and
latest-pointer tamper failures.

## Observability And Incidents

```powershell
npm run flowchain:ops:snapshot -- -AllowBlocked
npm run flowchain:ops:alerts -- -AllowBlocked
npm run flowchain:ops:incident-drill -- -AllowBlocked
npm run flowchain:completion:audit -- -AllowBlocked
```

Alert rules map node down, control plane down, stalled height, stale state,
no-secret scan failures, public RPC, backup, bridge, tester sharing, and
deployment-contract blockers to concrete operator commands without committing
external alert credentials. Incident drills cover node down, control plane down,
height not advancing, stale state, no-secret scan critical, and
owner-blockers-only baseline.

## Public Exposure Rule

Never bind the private control plane directly to the public internet. Public
traffic must go through TLS, CORS, method allowlist, body and batch caps, rate
limits, backup proof, bridge readiness, no-secret scan, and tester packet gates.
