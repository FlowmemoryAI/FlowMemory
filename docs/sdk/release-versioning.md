# SDK Release And Versioning

FlowChain SDK versioning is tied to the FlowChain-native RPC method contract,
not EVM JSON-RPC compatibility.

## Version Policy

- Patch: docs, examples, redaction, or helper changes that do not alter method
  calls or exported types.
- Minor: additive methods, additive response helpers, or new examples.
- Major: removed methods, renamed fields, changed transaction envelope shape,
  or changed error tags.

## Compatibility

The SDK must check `rpc_discover` before claiming support for a method. A
runtime that omits a method should produce `FlowChainRpcMethodUnavailableError`.

The generated reference is the compatibility artifact:

```powershell
node tools/flowchain-rpc-reference.mjs --rpc-url http://127.0.0.1:8787/rpc --check
```

## Breaking Changes

Breaking changes require:

- updated SDK exported types;
- updated examples;
- updated generated RPC reference;
- updated `docs/developer/` integration docs;
- passing `npm run flowchain:sdk:e2e`.

Public RPC and Base 8453 bridge readiness remain blocked until the required
deployment names are configured and verified by the live gates.
