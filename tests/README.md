# Contract Tests

The initial contract tests use Foundry without `forge-std` so they can run before dependency management exists.

Run from the repository root:

```powershell
forge test --root . --contracts . --match-path tests/RootfieldRegistry.t.sol --out E:\tmp\flowmemory-forge-out --cache-path E:\tmp\flowmemory-forge-cache -vv
```

When root-level config is in scope, add a `foundry.toml` that sets `src = "contracts"` and `test = "tests"` so the command can become `forge test`.
