# Contract Tests

The initial contract tests use Foundry without `forge-std` so they can run before dependency management exists.

Run from the repository root:

```powershell
forge test
```

`foundry.toml` sets `contracts/` as the source directory and `tests/` as the test directory. Build output goes to `out/` and cache data goes to `cache/`, which should remain generated artifacts.

Run a specific suite when iterating:

```powershell
forge test --match-contract RootfieldRegistryTest
forge test --match-contract LiveV0PackageTest
```
