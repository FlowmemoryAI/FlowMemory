# FlowMemory V0 JSON Schemas

These schemas are the canonical local/test V0 shapes for generated Flow Memory and Rootflow objects:

- `memory-signal.schema.json`
- `memory-receipt.schema.json`
- `rootflow-transition.schema.json`
- `rootfield-bundle.schema.json`
- `agent-memory-view.schema.json`

`memory-signal.schema.json` also embeds the `flowmemory.flowpulse_contract_event.v0`
shape, which records the `IFlowPulse.FlowPulse` event signature, indexed fields,
payload fields, and receipt-derived locator fields that the indexer added after
reading logs and receipts.

They describe local fixture objects only. They do not claim production L1 readiness, trustless verification, free storage, AI running on-chain, or production Uniswap v4 deployment.
