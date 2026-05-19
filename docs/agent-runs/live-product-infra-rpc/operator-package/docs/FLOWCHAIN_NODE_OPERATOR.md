# FlowChain Node Operator Guide

Status: local/private operator guide with public deployment boundaries.

## Local Service

```powershell
npm run flowchain:operator:package
npm run flowchain:operator:package:verify
npm run flowchain:service:start -- -LiveProfile
npm run flowchain:service:status -- -AllowBlocked
npm run flowchain:service:monitor -- -AllowBlocked
npm run flowchain:service:restart -- -LiveProfile
npm run flowchain:service:stop
```

Healthy local service evidence includes a running node, running control plane,
fresh state file writes, and advancing height.

`flowchain:operator:package` generates a no-secret operator package under
`docs/agent-runs/live-product-infra-rpc/operator-package/` with copied runbooks,
the command matrix, owner-input names, and current readiness evidence.
`flowchain:operator:package:verify` independently validates that package after
it exists.

## Service Supervisor

Use the repo-native supervisor on the owner host to keep the local/private L1
service alive after process exits or stale state evidence:

```powershell
npm run flowchain:service:supervisor -- -IntervalSeconds 30 -MaxRestartAttempts 3
npm run flowchain:service:supervisor:validate
npm run flowchain:service:install:windows -- -Action Plan
npm run flowchain:service:install:validate
npm run flowchain:service:install:systemd:validate
```

The supervisor checks `flowchain:service:status`, requires live profile by
default, restarts with `flowchain:service:restart -- -LiveProfile`, and writes
redacted reports under `docs/agent-runs/live-product-infra-rpc/`. With
`-StartBridgeRelayerLoop`, it also treats a stopped, mismatched, or unhealthy
bridge relayer loop as an autorecovery restart reason.

On a Windows owner host, `flowchain:service:install:windows` can register,
inspect, and remove a Scheduled Task that starts the live supervisor at logon:

```powershell
npm run flowchain:service:install:windows -- -Action Install
npm run flowchain:service:install:windows -- -Action Status
npm run flowchain:service:install:windows -- -Action Uninstall
```

On a Linux VPS, `flowchain:service:install:systemd:validate` checks the rendered
systemd live-service and supervisor templates, install/status/uninstall command
plans, owner env-file wiring, scoped write paths, autorecovery defaults, and the
explicit bridge-relayer opt-in supervisor plan without mutating the host.

```powershell
npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>
npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -StartBridgeRelayerLoop
```

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
It intentionally does not expose the local `/state` mirror or `devnet_state`
method on the public edge; public clients must use narrower read methods and
the authenticated tester gateway.

## Backup And Restore

```powershell
npm run flowchain:backup:create
npm run flowchain:backup:restore:verify
npm run flowchain:backup:restore:validate
npm run flowchain:backup:check -- -AllowBlocked
npm run flowchain:backup:install:windows -- -Action Plan
npm run flowchain:backup:install:systemd -- -Action Plan
npm run flowchain:backup:install:systemd:validate
npm run flowchain:backup:install:validate
```

Backups must write readable snapshots, readable manifests, an atomically written
latest pointer, matching manifest hashes, and a retention policy that protects
the newest snapshot while pruning older eligible snapshots. Restore validation
must prove missing artifact, tampered manifest, corrupt restore, wrong-chain
restore, latest-pointer tamper failures, retention rotation, and restore of the
newest retained snapshot.

On a Windows owner host, the backup install command can register, inspect, and
remove daily Scheduled Tasks for manifest-backed state snapshots and recurring
restore drills:

```powershell
npm run flowchain:backup:install:windows -- -Action Install
npm run flowchain:backup:install:windows -- -Action Status
npm run flowchain:backup:install:windows -- -Action Uninstall
npm run flowchain:backup:install:systemd -- -Action Install
npm run flowchain:backup:install:systemd -- -Action Status
npm run flowchain:backup:install:systemd -- -Action Uninstall
```

## Bridge Relayer

```powershell
npm run flowchain:bridge:live:check -- -AllowBlocked
npm run flowchain:bridge:infra:check -- -AllowBlocked
npm run flowchain:bridge:deploy:control:validate
npm run flowchain:bridge:relayer:once -- -AllowBlocked
npm run flowchain:service:restart -- -LiveProfile -StartBridgeRelayerLoop
```

The deploy/control validation is no-broadcast and proves the Base 8453 deploy,
pause, resume, and emergency-stop paths fail closed without owner env. The
relayer once gate is also no-broadcast. When owner Base 8453 inputs are missing
it stays blocked. When they pass, it observes confirmed lockbox deposits, builds
a runtime handoff, filters replayed credits, queues new credits into the running
L1, and waits for main-state credit evidence.

## Observability And Incidents

```powershell
npm run flowchain:ops:snapshot -- -AllowBlocked
npm run flowchain:ops:alerts -- -AllowBlocked
npm run flowchain:ops:metrics:export
npm run flowchain:ops:alerts:install:windows -- -Action Plan
npm run flowchain:ops:alerts:install:validate
npm run flowchain:ops:incident-drill -- -AllowBlocked
npm run flowchain:completion:audit -- -AllowBlocked
```

Alert rules map node down, control plane down, stalled height, stale state,
no-secret scan failures, public RPC, backup, bridge, tester sharing, and
deployment-contract blockers to concrete operator commands without committing
external alert credentials. Incident drills cover node down, control plane down,
height not advancing, stale state, no-secret scan critical, and
owner-blockers-only baseline.

On a Windows owner host, the alert install command can register, inspect, and
remove an interval Scheduled Task that refreshes local ops snapshot and alert
reports:

```powershell
npm run flowchain:ops:alerts:install:windows -- -Action Install
npm run flowchain:ops:alerts:install:windows -- -Action Status
npm run flowchain:ops:alerts:install:windows -- -Action Uninstall
```

## Public Exposure Rule

Never bind the private control plane directly to the public internet. Public
traffic must go through TLS, CORS, method allowlist, body and batch caps, rate
limits, backup proof, bridge readiness, no-secret scan, and tester packet gates.
