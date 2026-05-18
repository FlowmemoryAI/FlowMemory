/goal You are the FlowChain live infrastructure, public RPC, and deployment
readiness agent.

Worktree: `E:\FlowMemory\flowmemory-live-infra-rpc`
Branch: `agent/live-product-infra-rpc`

Mission: remove the remaining infrastructure blockers that prevent FlowChain
from moving beyond local/private devnet proof into a configured owner-operated
live pilot. Build the scripts, runbooks, validators, health checks, service
configuration, public RPC readiness gates, backup checks, and bridge deployment
coordination needed for a real hosted FlowChain node/RPC endpoint. Do not print
or commit secrets. Do not claim public/live readiness unless the deployment
inputs exist and the final checks prove them.

You are not alone in the codebase. Other agents may be changing runtime, RPC,
bridge, wallet, SDK, docs, storage, and verification files. Do not revert their
edits. Coordinate through explicit env names, reports, and checked artifacts.

Read first:
- `AGENTS.md`
- `docs/agent-goals/production-l1-live-chain/README.md`
- `docs/agent-runs/production-l1-hq/FULL_LIVE_CHAIN_COMPLETION_AUDIT.md`
- `docs/FLOWCHAIN_CONTROL_PLANE_API.md`
- `docs/FLOWCHAIN_PRODUCTION_L1_GO_NO_GO.md`
- `docs/FLOWCHAIN_LIVE_L1_BRIDGE_GO_NO_GO.md`
- `docs/FLOWCHAIN_TROUBLESHOOTING.md`
- `infra/scripts/flowchain-doctor.ps1`
- `infra/scripts/flowchain-start.ps1`
- `infra/scripts/flowchain-node-start.ps1`
- `infra/scripts/flowchain-node-status.ps1`
- `infra/scripts/flowchain-bridge-live-check.ps1`
- `infra/scripts/bridge-base8453-deploy.ps1`
- `infra/scripts/bridge-base-mainnet-pilot-observe.ps1`
- `infra/scripts/flowchain-production-l1-e2e.ps1`
- `services/control-plane/src/methods.ts`
- `services/bridge-relayer/src/bridge-live-readiness-check.ts`
- `package.json`

Own these files/modules unless coordination requires otherwise:
- `docs/agent-runs/live-product-infra-rpc/`
- `docs/operations/`
- `infra/scripts/flowchain-public-rpc*.ps1`
- `infra/scripts/flowchain-live-env*.ps1`
- `infra/scripts/flowchain-service*.ps1`
- `infra/scripts/flowchain-monitor*.ps1`
- root `package.json` only for infra/RPC/deployment readiness scripts

Do not own:
- runtime state transition rules
- wallet private-key custody
- bridge relayer event parsing internals unless adding deployment checks around
  them
- dashboard design
- SDK implementation
- live env values, RPC credentials, private keys, seed phrases, API keys,
  webhooks, vault ciphertext, or raw endpoint URLs in committed output

Required product standard:
A FlowChain operator must be able to provision or point to a host, configure
public RPC safely, run the FlowChain node/control-plane as services, expose a
TLS-terminated RPC URL, enforce allowed CORS origins and rate limits, write
state backups, run health checks, configure the Base 8453 bridge dependencies,
verify the lockbox and Base RPC chain ID, and then run a single live-readiness
command. If any required input is absent, the command must fail closed with the
exact missing env or deployment artifact name only.

Public RPC requirements:
1. Keep local defaults private: `127.0.0.1` only unless explicit public config
   is present.
2. Define the required public RPC environment contract:
   - `FLOWCHAIN_RPC_PUBLIC_URL`
   - `FLOWCHAIN_RPC_ALLOWED_ORIGINS`
   - `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`
   - `FLOWCHAIN_RPC_TLS_TERMINATED`
   - `FLOWCHAIN_RPC_STATE_BACKUP_PATH`
3. Add a public RPC readiness script that:
   - verifies all required names are configured without printing values;
   - verifies the public URL is HTTPS unless explicitly local;
   - verifies TLS termination is acknowledged;
   - verifies allowed origins are not broad wildcard for public mode;
   - verifies a numeric rate limit;
   - verifies the backup path exists and is writable;
   - calls `/health`, `/rpc/discover`, and `/rpc/readiness`;
   - verifies the endpoint chain ID and latest block fields match local node
     state;
   - verifies no response includes secrets or raw env values;
   - writes a machine-readable report.
4. Add public RPC health checks for:
   - process alive
   - latest block height/hash/root
   - block production age
   - finalized height/hash
   - mempool depth
   - peer count or local-private profile status
   - state file readability
   - backup freshness
   - bridge relayer lag/readiness
   - wallet/API reachability
5. Add deployment docs for at least one owner-operated path:
   - local Windows machine behind tunnel/reverse proxy, or
   - cloud VM/reverse proxy, or
   - Vercel/frontend plus separate node/RPC host.
   The docs must state exactly what the agent can prepare in code and what the
   owner must provide.
6. Do not hard-code vendor credentials or URLs. Any provider-specific guidance
   must use placeholders and env names.

Service and persistence requirements:
1. Add scripts or docs to run node/control-plane/relayer as long-lived services
   or supervised processes on Windows.
2. A service start must not silently use bounded `MaxBlocks` mode for live
   profile.
3. A service status command must print safe status:
   - running/stopped
   - PID
   - bind host/port
   - public readiness status
   - latest height
   - finalized height
   - backup path configured/not configured
   - bridge readiness status
4. Add stop/restart scripts that preserve state and do not delete runtime data.
5. Add backup verification:
   - backup path exists
   - latest backup timestamp
   - export/import dry-run or state root comparison where practical
   - fail closed if backup cannot be written or read

Live Base 8453 bridge deployment coordination:
1. Define the required bridge deployment environment contract:
   - `FLOWCHAIN_PILOT_OPERATOR_ACK`
   - `FLOWCHAIN_BASE8453_RPC_URL`
   - `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`
   - `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`
   - `FLOWCHAIN_BASE8453_ASSET_DECIMALS`
   - `FLOWCHAIN_BASE8453_FROM_BLOCK`
   - `FLOWCHAIN_BASE8453_TO_BLOCK`
   - `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
   - `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
   - `FLOWCHAIN_PILOT_CONFIRMATIONS`
   - deployer/private key names only if deployment scripts require them, never
     values
2. Add a bridge infra readiness script or extend the existing one to verify:
   - Base RPC chain ID is 8453 without printing URL;
   - lockbox address shape is valid;
   - deployed bytecode exists at lockbox address when configured;
   - supported token config is valid for native ETH or ERC-20 mode;
   - decimals are numeric;
   - from/to block range is numeric and sane;
   - caps are numeric and nonzero only when operator set them;
   - confirmation depth is configured and reported;
   - operator acknowledgement is exact;
   - emergency pause/resume commands are discoverable;
   - no live broadcast happens from readiness checks.
3. Add a lockbox deployment runbook that:
   - separates dry-run, broadcast, verification, and post-deploy checks;
   - records transaction hash and address fields without private keys;
   - explains how to verify the address before any funds are sent;
   - records the exact commands for pause/resume/emergency stop;
   - writes evidence paths for the verification agent.
4. Add a transaction diagnosis path for owner-supplied Base tx hashes that does
   not require private keys and does not expose RPC values.

Final live-readiness command:
1. Add or update a root command:
   ```powershell
   npm run flowchain:live-infra:check
   ```
2. That command must:
   - run public RPC readiness;
   - run service/process health;
   - run backup readiness;
   - run bridge live readiness;
   - run no-secret scan on reports/logs;
   - output one machine-readable report under
     `docs/agent-runs/live-product-infra-rpc/`;
   - return success only if configured public RPC and configured live bridge
     readiness are both proven;
   - return a blocked/fail-closed status naming exact missing env/artifacts when
     owner inputs are absent.
3. Add the command to `npm run flowchain:live-product:e2e` once that final gate
   exists, or document the integration patch needed for the verification agent.

Implementation loop:
1. Create:
   - `docs/agent-runs/live-product-infra-rpc/PLAN.md`
   - `docs/agent-runs/live-product-infra-rpc/CHECKLIST.md`
   - `docs/agent-runs/live-product-infra-rpc/EXPERIMENTS.md`
   - `docs/agent-runs/live-product-infra-rpc/NOTES.md`
2. Inventory current scripts and classify every required live/public input as
   `checked`, `missing-check`, `blocked-owner-input`, or `implemented`.
3. Build public RPC readiness script first.
4. Build service/process status checks next.
5. Build backup readiness checks next.
6. Build bridge deployment/readiness coordination next.
7. Add docs after scripts exist.
8. Run the command set below.
9. Update the checklist with evidence, not claims.
10. Repeat until the infra readiness command is green with configured inputs or
    blocked only by exact owner-provided values.

Commands to run before finishing:
```powershell
npm run flowchain:doctor
npm run flowchain:node:status
npm run flowchain:rpc:e2e
npm run flowchain:bridge:live:check
npm run flowchain:live-infra:check
npm run flowchain:production-l1:e2e
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

Acceptance gates:
- `npm run flowchain:live-infra:check` exists.
- Public RPC readiness checks all required public RPC env/artifact names and
  fails closed without them.
- Public RPC readiness proves health, discovery, readiness, chain state,
  finality, no-secret output, and backup readiness when configured.
- Service status proves long-running live profile is not bounded by a temporary
  max-block test mode.
- Bridge infra readiness verifies Base 8453 chain ID, lockbox code, token,
  caps, block range, confirmations, and operator acknowledgement when
  configured.
- Lockbox deployment runbook separates dry-run and broadcast and never commits
  private keys or raw RPC URLs.
- Reports under `docs/agent-runs/live-product-infra-rpc/` give exact command
  outputs, blockers, evidence paths, and next owners.
- Do not mark complete if the endpoint is local-only but described as public, or
  if bridge readiness has not verified the configured Base 8453 lockbox.

Stop condition:
Stop only when FlowChain has a machine-checked live infrastructure path for
public RPC, service persistence, state backup, and Base 8453 bridge deployment
readiness, with every remaining external dependency named exactly and no
secrets exposed.
