# FlowChain Private/Local Protocol Checklist

## Required Reading

- [x] `AGENTS.md`
- [x] `docs/START_HERE.md`
- [x] `docs/FLOWMEMORY_HQ_CONTEXT.md`
- [x] `docs/CURRENT_STATE.md`
- [x] `docs/FLOWCHAIN_FULL_PRIVATE_TESTNET.md`
- [x] `docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md`
- [x] `docs/FLOWCHAIN_AGENT_INTEGRATION_MAP.md`
- [x] `docs/ROOTFLOW_V0.md`
- [x] `docs/FLOW_MEMORY_V0.md`
- [x] `docs/V0_LAUNCH_ACCEPTANCE.md`
- [x] `docs/DECISIONS/`
- [x] `schemas/flowmemory/`
- [x] `fixtures/launch-core/`
- [x] `crypto/fixtures/`
- [x] `crates/flowmemory-devnet/src/model.rs`
- [x] `services/control-plane/src/types.ts`

## Build Checklist

- [x] Network profile schema and fixture coverage
- [x] Genesis schema and deterministic genesis builder/validator
- [x] Validator authority schema
- [x] Account public metadata schema
- [x] Transaction envelope schema
- [x] Transaction payload union schema
- [x] Block header and body schemas
- [x] Receipt and event schemas
- [x] State root manifest schema
- [x] Bridge evidence schema
- [x] Finality receipt schema
- [x] Export snapshot schema
- [x] Positive fixture set
- [x] Negative fixture set with stable error codes
- [x] `npm run validate:production-l1-protocol`
- [x] `npm run validate:production-l1-fixtures`
- [x] `git diff --check`

## Stop Condition

Stop only after schema and fixture validation commands pass and all 12 production-L1 layers have a protocol object or an explicit not-applicable reason.
