/goal You are the FlowChain Real-Value Pilot Control-Plane/Dashboard agent.

Worktree: E:\FlowMemory\flowmemory-live-control-dashboard
Branch: agent/real-value-pilot-control-dashboard

Goal: expose and render the real-value pilot bridge lifecycle end to end: Base deposit observed, local credit applied, replay/retry status, withdrawal intent/release evidence, emergency state, and exact operator next steps.

Inspect first:
- current services/control-plane and apps/dashboard;
- E:\FlowMemory\flowmemory-indexer active long-loop work;
- E:\FlowMemory\flowmemory-dashboard active long-loop work;
- bridge relayer/runtimes handoff shapes.

Allowed folders:
- services/control-plane/
- services/shared/
- apps/dashboard/
- schemas/flowmemory/
- docs/agent-runs/real-value-pilot-control-dashboard/
- control-plane/dashboard docs under docs/

Forbidden folders:
- contracts/
- crates/
- crypto/ secret internals
- hardware/ implementation

Create and maintain:
- docs/agent-runs/real-value-pilot-control-dashboard/PLAN.md
- docs/agent-runs/real-value-pilot-control-dashboard/CHECKLIST.md
- docs/agent-runs/real-value-pilot-control-dashboard/EXPERIMENTS.md
- docs/agent-runs/real-value-pilot-control-dashboard/NOTES.md

Quantitative acceptance:
1. `npm test --prefix services/control-plane` passes.
2. `npm run control-plane:smoke` passes.
3. `npm test --prefix apps/dashboard` passes.
4. `npm run build --prefix apps/dashboard` passes.
5. API exposes pilot status, deposit observations, credits, withdrawal intents, release evidence, cap status, pause status, retry status, and emergency status.
6. API rejects or redacts private key, seed phrase, mnemonic, RPC credential, API key, and webhook-shaped material.
7. Dashboard shows exact live/degraded/error state and next operator command.
8. Dashboard labels the pilot as capped owner testing, not broad public readiness.
9. Browser stores no private keys or RPC secrets.
10. `npm run flowchain:real-value-pilot:e2e` verifies API and dashboard evidence.
11. `npm run flowchain:product-e2e` still passes.

Feedback loop:
- Run control-plane tests/smoke.
- Run dashboard tests/build.
- Run browser verification if available.
- Run pilot E2E and product E2E.

PR output:
- List API methods/endpoints and dashboard sections.
- Include exact commands run.
- Include screenshots or browser verification notes if possible.
