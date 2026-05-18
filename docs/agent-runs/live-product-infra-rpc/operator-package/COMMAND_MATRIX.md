# FlowChain Operator Command Matrix

Generated: 2026-05-18T05:25:02.4121390Z

| Phase | Command | Purpose |
| --- | --- | --- |
| preflight | `npm run flowchain:prereq` | Check required local tooling. |
| preflight | `npm run flowchain:doctor` | Summarize repo and runtime health. |
| service | `npm run flowchain:service:start -- -LiveProfile` | Start the private live-profile node and RPC service. |
| service | `npm run flowchain:service:status -- -AllowBlocked` | Verify node, control-plane, height, and state freshness. |
| service | `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30` | Observe block production over a sampling window. |
| service | `npm run flowchain:service:restart -- -LiveProfile` | Restart without deleting runtime state. |
| service | `npm run flowchain:service:stop` | Stop local services without deleting state. |
| autorecovery | `npm run flowchain:service:supervisor:validate` | Prove the supervisor can recover a failed local control plane. |
| autorecovery | `npm run flowchain:service:install:windows -- -Action Plan` | Render the no-secret Windows Scheduled Task install plan. |
| autorecovery | `npm run flowchain:service:install:validate` | Validate install/status/uninstall paths without mutating the owner host. |
| autorecovery | `npm run flowchain:service:install:systemd:validate` | Validate Linux systemd live-service and supervisor install plans without mutating the owner host. |
| handoff | `npm run flowchain:second-computer:readiness` | Create and verify the no-secret offline second-computer source bundle. |
| owner-setup | `npm run flowchain:owner:onboarding` | Regenerate the owner setup map and clarify that FlowChain public RPC is repo-owned. |
| owner-setup | `npm run flowchain:owner:signup-checklist` | List exactly what the owner must sign up for or create before public launch. |
| owner-setup | `npm run flowchain:owner-env:template` | Create or preserve the ignored local owner env scaffold with empty values only. |
| owner-setup | `npm run flowchain:owner-env:readiness:validate` | Prove unsafe owner env file paths fail before live gates run. |
| owner-setup | `npm run flowchain:owner-env:readiness -- -AllowBlocked` | Run live gates through the ignored owner env file and report only names and statuses. |
| public-rpc | `npm run flowchain:public-rpc:deployment-bundle` | Generate owner-host public RPC edge artifacts. |
| public-rpc | `npm run flowchain:public-rpc:deployment:automation` | Validate render, preflight, verify, and rollback phases. |
| public-rpc | `npm run flowchain:public-rpc:validate` | Run local public-profile RPC readiness validation. |
| public-rpc | `npm run flowchain:public-rpc:abuse-test` | Run CORS, media-type, batch/body cap, rate-limit, and response hygiene probes. |
| backup | `npm run flowchain:backup:restore:validate` | Prove restore safety and tamper rejection locally. |
| backup | `npm run flowchain:backup:owner-path:dry-run` | Exercise backup readiness with an ignored local owner-path stand-in. |
| backup | `npm run flowchain:backup:install:windows -- -Action Plan` | Render the daily snapshot Scheduled Task plan. |
| backup | `npm run flowchain:backup:install:validate` | Validate backup task plan/status/uninstall behavior. |
| ops | `npm run flowchain:ops:snapshot -- -AllowBlocked` | Classify critical incidents separately from owner-input blockers. |
| ops | `npm run flowchain:ops:alerts -- -AllowBlocked` | Refresh local alert rules and finding coverage. |
| ops | `npm run flowchain:ops:metrics:export` | Export no-secret JSON and Prometheus textfile metrics for owner collectors. |
| ops | `npm run flowchain:ops:alerts:install:windows -- -Action Plan` | Render recurring alert refresh Scheduled Task plan. |
| ops | `npm run flowchain:ops:incident-drill` | Rehearse node, RPC, stale-state, stalled-height, and no-secret incidents. |
| bridge | `npm run flowchain:bridge:relayer:once -- -AllowBlocked` | Run the no-broadcast relayer gate; remains blocked until owner Base inputs exist. |
| bridge | `npm run flowchain:bridge:deploy:control:validate` | Validate Base 8453 deploy, pause, resume, and emergency-stop gates fail closed without owner env and require broadcast acknowledgements. |
| bridge | `npm run flowchain:bridge:relayer:guardrail:validate` | Prove missing owner inputs cannot mutate cursor state or queue credits. |
| bridge | `npm run flowchain:bridge:relayer:loop:validate` | Validate relayer loop start, fresh health reporting, clean stop, PID cleanup, and no leftover validation relayer process. |
| testers | `npm run flowchain:external-tester:packet -- -AllowBlocked` | Regenerate the friends-and-family packet and fail closed until public gates pass. |
| testers | `npm run flowchain:external-tester:packet:validate` | Validate the packet and connect pack are no-secret, locally executable, and not externally shareable before owner inputs. |
| testers | `npm run flowchain:dashboard:ui:readiness` | Run desktop and mobile browser verification for tester wallet create, faucet, send, and Explorer inspection. |
| release | `npm run flowchain:operator:package:verify` | Verify the generated operator package contents and no-secret boundary. |
| release | `npm run flowchain:completion:audit -- -AllowBlocked` | Run the production readiness gate without false public-ready claims. |
| release | `npm run flowchain:truth-table -- -AllowBlocked` | Classify every tracked gate as passed, owner-blocked, repo-blocked, failed, or stale. |
| release | `npm run flowchain:no-secret:scan` | Verify generated reports and packets contain no secret markers. |
