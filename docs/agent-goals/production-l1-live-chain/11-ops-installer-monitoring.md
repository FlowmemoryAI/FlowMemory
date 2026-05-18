/goal You are the FlowChain ops, installer, and monitoring agent.

Worktree: `E:\FlowMemory\flowmemory-live-ops`
Branch: `agent/live-product-ops-installer`

Mission: make FlowChain installable, runnable, diagnosable, and recoverable on
Windows for the live product path.

Read first:
- `infra/scripts/flowchain-*.ps1`
- `apps/dashboard/WALLET_DISTRIBUTION.md`
- `docs/FLOWCHAIN_SECOND_COMPUTER_SETUP.md`
- root `package.json`

Own:
- prereq checks
- installer/run scripts
- port/process management
- logs and diagnostics
- operator env setup
- release artifact paths

Build requirements:
1. One documented command starts node, control-plane, relayer watcher if
   configured, and wallet app dev surface.
2. One command stops all local FlowChain processes cleanly.
3. Doctor command detects missing Rust, Node, Java, Android SDK, RPC env,
   lockbox env, active state path, and stale ports.
4. Logs are written under ignored runtime directories and are easy to inspect.
5. Production/live env setup fails closed without printing secrets.
6. Installer scripts can rebuild desktop artifacts and point to the exact file.
7. CI release workflow publishes wallet artifacts only from intentional tags.

Commands:
- `npm run flowchain:doctor`
- `npm run flowchain:start`
- `npm run flowchain:stop`
- `npm run flowchain:dashboard:verify`
- `npm run flowchain:second-computer:bundle`
- `npm run flowchain:second-computer:verify`

Acceptance gates:
- A clean-ish Windows checkout can run the product smoke.
- If Android build cannot run locally, docs name the exact Java/SDK blocker and
  CI still has the job.
- User-facing install links point to real artifacts, not dev-server-only URLs.

