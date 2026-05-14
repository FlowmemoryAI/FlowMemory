# Private/Local Ops Wrapper Notes

## Initial Findings

- Existing docs mark the private/local FlowChain package as the current milestone.
- Existing root scripts cover prereq, init, bounded start/stop, demo, smoke, full smoke, product E2E, export/import, workbench, and real-value pilot ops.
- The requested final wrapper must be more explicit than `flowchain:full-smoke`: it must produce a `flowchain:production-l1:e2e` JSON report with subsystem status, URLs, logs, evidence paths, emergency commands, and live-pilot missing env names.
- The wrapper must not claim production readiness when a subsystem is missing or blocked on external live env.
