# Real-Value Pilot Control-Plane/Dashboard PR Summary

## What Changed

- Added a real-value pilot control-plane projection for the capped owner-testing bridge lifecycle.
- Added JSON-RPC and HTTP read endpoints for pilot status, deposit observations, local credits, withdrawal intents, release evidence, cap status, pause status, retry status, and emergency status.
- HTTP pilot list endpoints accept `?limit=` and return the same capped list contract as the JSON-RPC methods.
- Added dashboard `Real-value pilot` records and a visible status panel that renders the exact `live`, `degraded`, or `error` state plus the next operator command.
- Added the control-plane/dashboard real-value pilot proof command and schema documentation.
- Updated the upstream real-value pilot matrix for the control-plane/dashboard rows this branch satisfies.
- Updated control-plane/dashboard docs and the run tracking files for this workstream.

## Why It Changed

The real-value pilot needs one operator-facing surface that makes the bridge lifecycle auditable without exposing secrets or implying public readiness. This change keeps the browser and API local-only, labels the surface as capped owner testing, and shows the next safe operator command instead of requiring operators to infer what to run.

## API Methods

- `pilot_status`
- `pilot_deposit_observation_list`
- `pilot_credit_list`
- `pilot_withdrawal_intent_list`
- `pilot_release_evidence_list`
- `pilot_cap_status`
- `pilot_pause_status`
- `pilot_retry_status`
- `pilot_emergency_status`

## HTTP Endpoints

- `GET /pilot/status`
- `GET /pilot/deposits?limit=50`
- `GET /pilot/credits?limit=50`
- `GET /pilot/withdrawal-intents?limit=50`
- `GET /pilot/release-evidence?limit=50`
- `GET /pilot/cap-status`
- `GET /pilot/pause-status`
- `GET /pilot/retry-status`
- `GET /pilot/emergency-status`

## Dashboard Sections

- `Real-value pilot` product surface card.
- Real-value pilot status panel with:
  - `capped owner testing` label
  - exact pilot state
  - API-provided next command
  - public readiness `false`
  - browser secrets `not stored`
  - evidence row count
- Workbench records under `realValuePilot` for lifecycle and guardrail rows.

## Commands Run

- `npm test --prefix services/control-plane` - passed.
- `npm run control-plane:smoke` - passed, 66 methods.
- `npm test --prefix apps/dashboard` - passed.
- `npm run build --prefix apps/dashboard` - passed.
- `npm run flowchain:real-value-pilot:control-dashboard` - passed.
- `npm run flowchain:real-value-pilot:e2e` - failed incomplete in the upstream final HQ gate because contracts, bridge, runtime, wallet, and ops proof commands are missing outside this branch's scope.
- `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` - completed and wrote the upstream coordination report with the control-dashboard row passed and non-control-dashboard rows missing.
- `node -e "JSON.parse(require('fs').readFileSync('schemas/flowmemory/control-plane-real-value-pilot-status.schema.json','utf8')); console.log('pilot schema ok')"` - passed.
- `git diff --check` - passed with line-ending warnings only.
- `npm run flowchain:product-e2e` - passed after rebasing onto `origin/main` commit `f384236`.
- `npm run flowchain:l1-e2e` - passed on the current rebased tree.
- `node infra/scripts/check-unsafe-claims.mjs` - passed.

## Browser Verification Notes

- In-app browser screenshot verification could not run because the Browser plugin Node REPL `js` tool was not exposed in this session.
- Fallback local server verification passed:
  - control-plane health returned `flowmemory-control-plane-v0`
  - `GET /pilot/status` returned `flowmemory.control_plane.real_value_pilot_status.v0`
  - pilot state was `degraded`
  - dashboard dev server returned HTTP 200 and the Vite root element

## Risks And Follow-Ups

- The branch is rebased onto `origin/main` commit `f384236`; product E2E now passes under the upstream default optional Slither policy.
- `origin/main` contains the HQ real-value pilot gate and expects `npm run flowchain:real-value-pilot:control-dashboard` for this owner row; this branch provides and verifies that command.
- Issue #137 now has this branch's evidence comment: https://github.com/FlowmemoryAI/FlowMemory/issues/137#issuecomment-4446943001
- Bare `npm run flowchain:real-value-pilot:e2e` remains incomplete until contracts, bridge, runtime, wallet, and ops proof commands land from their owning branches.
- Current fixture-backed pilot state is `degraded` because mock/local/Base Sepolia evidence is visible but no Base mainnet chain ID `8453` pilot deposit is loaded.
- No PR exists yet for branch `agent/real-value-pilot-control-dashboard`; this file is the PR-ready summary content. Publishing is intentionally left for an explicit operator action because the repo PR process requires intentional staging, commit, push, and draft PR creation.
