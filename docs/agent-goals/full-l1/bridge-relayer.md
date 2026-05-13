/goal You are the FlowChain bridge agent.

You are working in `E:\FlowMemory\flowmemory-bridge-full`.

Mission: build a working test bridge path so a tester can move value-like test
events from Base Sepolia or a mock Base event into the local FlowChain runtime
and see the credited result in the API/workbench. The default path must use
mock or Base Sepolia test assets. Do not silently operate on real funds.

Read first:
- AGENTS.md
- docs/bridge/FLOWCHAIN_BASE_BRIDGE_POC.md
- services/bridge-relayer/
- contracts/bridge/
- schemas/flowmemory/bridge-*.schema.json
- docs/FLOWCHAIN_FULL_PRIVATE_TESTNET.md

Allowed folders:
- services/bridge-relayer/
- contracts/bridge/
- tests/bridge/
- schemas/flowmemory/bridge-*.schema.json
- fixtures/bridge/
- infra/scripts/bridge-*.ps1
- package.json when adding bridge commands
- docs/bridge/

Do not edit:
- apps/dashboard/
- crates/flowmemory-devnet/ except documented bridge handoff examples
- crypto/ except shared bridge schema references
- hardware/

Build requirements:
1. Observe BaseBridgeLockbox deposit events from:
   - committed mock fixture
   - local Anvil
   - Base Sepolia RPC when env vars are provided
2. Convert deposits into canonical BridgeObservation and BridgeCredit objects
   with replay protection and deterministic IDs.
3. Submit bridge credits into the local FlowChain runtime through the
   control-plane/runtime intake path once available; until then, write the
   exact handoff file the runtime agent will consume.
4. Add withdrawal/burn intent objects for local-to-Base testing. For now this
   can be a test-mode withdrawal record with no real mainnet release.
5. Add bridge smoke commands:
   - mock bridge smoke
   - Base Sepolia observation smoke
   - full local credit smoke
6. Make the workbench/API able to display deposit observed -> credit pending ->
   credit applied -> withdrawal requested.

Expected commands:
- `npm run bridge:mock`
- `npm run bridge:test`
- `npm run bridge:sepolia:observe`
- `npm run bridge:local-credit:smoke`
- contribute to `npm run flowchain:full-smoke`

Acceptance:
- Bridge relayer tests pass.
- Foundry bridge tests pass if contracts changed.
- Mock deposit credits local state or writes a validated handoff.
- Base Sepolia observation can run without private keys.
- Any real-funds command requires an explicit flag and prints what chain, token,
  amount, contract, and account will be used before it broadcasts.
- `git diff --check` passes.
- Open a PR and push your branch.
