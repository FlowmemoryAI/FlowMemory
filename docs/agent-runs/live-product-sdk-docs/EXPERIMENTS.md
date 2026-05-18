# FlowChain SDK Experiments

Date: 2026-05-15

## Experiment Log

| Experiment | Status | Result |
| --- | --- | --- |
| Reuse control-plane direct runtime submit from SDK | passed | SDK e2e submits create/faucet/transfer envelopes with `runtimeSubmit: true` and reads the applied transaction. |
| Generate RPC reference from live discovery | passed | `tools/flowchain-rpc-reference.mjs --check` matched 79 discovered methods. |
| Browser-safe SDK calls | implemented | Browser/Vite sample uses fetch-only SDK methods and `GET /rpc/readiness`. |
| CLI loopback default | implemented | CLI defaults to `http://127.0.0.1:8787/rpc` and write commands require loopback unless explicitly overridden. |
| Fail-closed bridge readiness | passed | SDK e2e and bridge example reported blocker names only with `envValuesPrinted: false`. |

## Constraints

- Tests may create local runtime state and reports under ignored `devnet/local/`
  and under this agent-run directory.
- No examples may print secret-shaped material or raw env values.
- Public/live commands are read-only readiness checks unless explicit owner env
  is provided outside this task.

## Results

- `npm run flowchain:sdk:e2e` passed.
- `npm run flowchain:production-l1:e2e` failed outside the SDK scope because
  dependency installs are missing in this checkout and live Base 8453 inputs are
  absent.
