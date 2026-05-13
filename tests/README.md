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

Before handing contract changes to review, run the local hardening wrapper and whitespace diff check:

```powershell
npm run contracts:hardening
git diff --check
```

`npm run contracts:hardening` runs `forge build`, `forge test`, and Slither when it is installed. Use `npm run contracts:hardening:slither` when an audit or review explicitly requires Slither.
