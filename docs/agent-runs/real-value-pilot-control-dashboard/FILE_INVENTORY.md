# Real-Value Pilot Control-Plane/Dashboard File Inventory

## Control-plane API and runtime projection

- `services/control-plane/src/pilot.ts` - builds the read-only real-value pilot lifecycle projection, including deposit observations, credits, withdrawal intents, release evidence, cap, pause, retry, emergency, and operator next-step state.
- `services/control-plane/src/types.ts` - adds pilot JSON-RPC method names and bridge runtime handoff state shape.
- `services/control-plane/src/fixture-state.ts` - loads optional bridge runtime handoff evidence from fixture state.
- `services/control-plane/src/methods.ts` - registers pilot JSON-RPC methods, capabilities, source status, and raw handoff reads.
- `services/control-plane/src/server.ts` - exposes `/pilot/*` HTTP endpoints for status and lifecycle evidence.
- `services/control-plane/src/smoke.ts` - includes pilot methods in the smoke probe.
- `services/control-plane/src/index.ts` - exports the pilot projection module.
- `services/control-plane/src/real-value-pilot-e2e.ts` - verifies pilot API and dashboard evidence without accepting secret-shaped material.
- `services/control-plane/test/control-plane.test.ts` - covers pilot lifecycle reads, live evidence projection, secret rejection, smoke count, and HTTP pilot routes.
- `services/control-plane/package.json` - adds the service-local real-value pilot E2E command.

## Dashboard surface

- `apps/dashboard/src/data/workbench.ts` - fetches `/pilot/status`, adds the `realValuePilot` section, and normalizes pilot lifecycle records for rendering.
- `apps/dashboard/src/views/WorkbenchView.tsx` - renders the capped owner testing pilot panel, state, evidence rows, and exact next operator command.
- `apps/dashboard/src/styles.css` - styles the pilot status panel and responsive evidence grid.
- `apps/dashboard/src/test/dashboardData.test.ts` - verifies dashboard data mapping and pilot labels.

## Schemas and docs

- `schemas/flowmemory/control-plane-real-value-pilot-status.schema.json` - defines the pilot status envelope emitted by the control-plane.
- `schemas/flowmemory/README.md` - documents the new schema.
- `docs/FLOWCHAIN_REAL_VALUE_PILOT.md` - updates the upstream pilot matrix for the control-plane/dashboard owner row added by this branch.
- `docs/FLOWCHAIN_CONTROL_PLANE_API.md` - documents pilot JSON-RPC methods and HTTP endpoints.
- `docs/DASHBOARD_MVP.md` - documents the dashboard pilot section and browser-secret boundary.
- `services/control-plane/README.md` - documents pilot methods, endpoints, smoke, and E2E usage.

## Agent run records

- `docs/agent-runs/real-value-pilot-control-dashboard/PLAN.md` - implementation plan and status.
- `docs/agent-runs/real-value-pilot-control-dashboard/CHECKLIST.md` - acceptance checklist and command status.
- `docs/agent-runs/real-value-pilot-control-dashboard/EXPERIMENTS.md` - verification log, including the upstream rebase, product E2E pass, and final HQ gate incompleteness.
- `docs/agent-runs/real-value-pilot-control-dashboard/NOTES.md` - handoff notes, source-shape findings, and assumptions.
- `docs/agent-runs/real-value-pilot-control-dashboard/PR_SUMMARY.md` - PR-ready summary.
- `docs/agent-runs/real-value-pilot-control-dashboard/COMPLETION_AUDIT.md` - acceptance and scope audit.
- `docs/agent-runs/real-value-pilot-control-dashboard/BLOCKERS.md` - exact remaining blocker for the upstream final real-value pilot HQ gate.
- `docs/agent-runs/real-value-pilot-control-dashboard/FILE_INVENTORY.md` - this inventory.
- `docs/agent-runs/real-value-pilot-control-dashboard/UPSTREAM_RECONCILIATION.md` - record of the upstream HQ pilot gate package-script reconciliation.
- `docs/agent-runs/real-value-pilot-control-dashboard/CONTROL_DASHBOARD_PROOF.json` - machine-readable proof summary for the upstream control-plane/dashboard owner row.
- `docs/agent-runs/real-value-pilot-control-dashboard/COMMAND_MATRIX.md` - command status matrix separating branch-owned checks from the upstream multi-owner HQ gate.

## Root command shims

- `package.json` - adds the upstream HQ proof-row script `flowchain:real-value-pilot:control-dashboard`. This is the only changed path outside the nominal allowed edit list and is recorded as a minimal command-surface exception.
