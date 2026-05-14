# Real-Value Pilot Wallet PR Output

Status: wallet/operator implementation is PR-ready. The branch is rebased onto
GitHub source-of-truth `origin/main` commit `c4959f8`, and the raw product E2E
gate passed in this worktree after the upstream default/audit Slither split.

## What Changed

- Added pilot operator config, public metadata, signed message builders, and
  public envelope validation in `crypto/`.
- Hardened pilot config-from-env so unsupported chain IDs, malformed cap ids,
  zero caps, used-over-max caps, closed cap windows, and secret-shaped local
  paths fail before config export. Base mainnet configs also fail before export
  unless the cap is `USDC-6` and no more than 25 USD.
- Tightened pilot config and public metadata schemas so `nextCommands` requires
  the full five-command deploy, observe, credit, release-sign, and
  release-verify workflow.
- Added CLI commands for pilot config-from-env, public metadata export, pilot
  signing, pilot verification, exact next-command output, and deterministic
  pilot E2E.
- Added pilot schemas under `schemas/flowmemory/`.
- Added root `npm run flowchain:real-value-pilot:wallet`, delegating to the
  crypto pilot E2E proof.
- Added wallet-only PowerShell wrappers:
  `infra/scripts/flowchain-wallet-pilot-config.ps1` and
  `infra/scripts/flowchain-wallet-pilot-observe.ps1`.
- Added operator documentation at
  `docs/OPERATIONS/REAL_VALUE_PILOT_WALLET_OPERATOR.md`.

## Env And Config Boundary

Pilot config may contain public chain, contract, operator, and cap policy:

- `FLOWCHAIN_PILOT_CHAIN_ID`
- `FLOWCHAIN_PILOT_CONTRACT_ADDRESS`
- `FLOWCHAIN_PILOT_OPERATOR_ID`
- `FLOWCHAIN_PILOT_CAP_ID`
- `FLOWCHAIN_PILOT_CAP_ASSET_ID`
- `FLOWCHAIN_PILOT_CAP_MAX_AMOUNT`
- `FLOWCHAIN_PILOT_CAP_UNIT`
- `FLOWCHAIN_PILOT_CAP_WINDOW_START_UNIX_MS`
- `FLOWCHAIN_PILOT_CAP_WINDOW_END_UNIX_MS`

Runtime-only values must remain in the local shell and must not be committed:

- `FLOWMEMORY_TEST_WALLET_PASSWORD`
- `FLOWCHAIN_PILOT_RPC_URL`
- private keys, seed phrases, mnemonics, RPC credentials, API keys, and
  webhook URLs.

Public metadata export is limited to signer ids, key ids, public keys, chain
id, contract address, and cap data. It excludes vault material and runtime
network credentials.

## Commands Run

```powershell
npm install --prefix crypto
npm test --prefix crypto
npm run wallet:product-smoke --prefix crypto
npm run wallet:pilot-e2e --prefix crypto
npm run flowchain:real-value-pilot:wallet
npm run wallet:pilot-config --prefix crypto -- --created-at-unix-ms 1778702400000 --out out/pilot-wallet-config-check.json
npm run wallet:pilot-next --prefix crypto -- --config out/pilot-wallet-config-check.json
standalone wallet:create + wallet:pilot-config + wallet:pilot-metadata CLI workflow under crypto/out/pilot-metadata-cli
standalone wallet:pilot-metadata mismatch CLI workflow under crypto/out/pilot-metadata-negative-cli
standalone wallet:create + wallet:pilot-config + generated release evidence + wallet:pilot-sign + wallet:pilot-verify CLI workflow under crypto/out/pilot-sign-cli
git merge --ff-only origin/main
git rebase origin/main
$tokens = $null; $errors = $null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'infra/scripts/flowchain-wallet-pilot-config.ps1'), [ref] $tokens, [ref] $errors) | Out-Null; if ($errors.Count -gt 0) { $errors | Format-List | Out-String; exit 1 }; 'flowchain-wallet-pilot-config.ps1 parser OK'
$tokens = $null; $errors = $null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'infra/scripts/flowchain-wallet-pilot-observe.ps1'), [ref] $tokens, [ref] $errors) | Out-Null; if ($errors.Count -gt 0) { $errors | Format-List | Out-String; exit 1 }; 'flowchain-wallet-pilot-observe.ps1 parser OK'
rg -n "private[_ -]?key|seed phrase|mnemonic|rpc[_ -]?url|api[_ -]?key|webhook|BEGIN .*PRIVATE|FLOWMEMORY_TEST_WALLET_PASSWORD|FLOWCHAIN_PILOT_RPC_URL" crypto schemas/flowmemory infra/scripts/flowchain-wallet-pilot-config.ps1 infra/scripts/flowchain-wallet-pilot-observe.ps1 docs/OPERATIONS docs/agent-runs/real-value-pilot-wallet
node --input-type=module -e "const mod = await import('./crypto/src/pilot-envelope-validation.js'); const names = Object.keys(mod).sort(); console.log(names.join('\n')); if (!names.includes('validatePilotOperatorEnvelope')) process.exit(1);"
rg -n -e 'from "\.\/wallet\.js"' -e "from './wallet\.js'" -e 'createEncryptedTestVault' -e 'unlockEncryptedTestVault' -e 'signLocalTransactionWithVault' crypto/src/pilot-envelope-validation.js crypto/src/pilot-envelope-validation.d.ts; if ($LASTEXITCODE -eq 1) { 'no wallet/vault imports in pilot public validator'; exit 0 } elseif ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
npm run flowchain:product-e2e
slither . --config-file .slither.config.json
gh issue list --search "BaseBridgeLockbox slither OR releaseNative" --limit 20
gh issue view 131 --json number,title,state,labels,url,body
gh issue comment 131 --body-file -
gh issue comment 131 --body-file -
git diff --check
```

Optional-Slither product E2E reproduction:

```powershell
$slitherDir = 'C:\Users\ntrap\AppData\Roaming\Python\Python311\Scripts'
$env:PATH = (($env:PATH -split ';') | Where-Object { $_ -and ([System.IO.Path]::GetFullPath($_).TrimEnd('\') -ne $slitherDir.TrimEnd('\')) }) -join ';'
npm run flowchain:product-e2e
```

## Results

- `npm test --prefix crypto`: passed, 23 tests.
- `npm run wallet:product-smoke --prefix crypto`: passed, 8 documents, 8
  transactions, 9 negative transactions.
- `npm run wallet:pilot-e2e --prefix crypto`: passed, 5 documents, 5 envelopes,
  7 negative cases.
- `npm run flowchain:real-value-pilot:wallet`: passed, 5 documents, 5
  envelopes, 7 negative cases.
- `wallet:pilot-config`: passed and wrote non-secret operator config after
  fail-closed cap policy validation, including Base mainnet `USDC-6` <=25 USD
  guardrails.
- Standalone metadata CLI workflow: passed. Created a local vault, derived the
  operator id from its public account, created config from env, exported pilot
  public metadata, verified the metadata operator matched the vault signer, and
  scanned output for secret-shaped material.
- Standalone metadata mismatch CLI workflow: passed. `wallet:pilot-metadata`
  fails when the config operator id does not match an active operator signer in
  the vault metadata.
- Standalone pilot sign/verify CLI workflow: passed. Created a local vault,
  created config from env, generated release evidence, signed it with
  `wallet:pilot-sign`, and verified it with `wallet:pilot-verify`; output was
  `{ "valid": true, "errors": [] }`.
- `wallet:pilot-next`: passed and printed:

```powershell
npm run deploy:base-sepolia:plan
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-wallet-pilot-observe.ps1 -ConfigPath devnet/local/pilot-wallet/operator-config.local.json -FromBlock <from-block> -ToBlock <to-block>
npm run bridge:local-credit:smoke
npm run wallet:pilot-sign --prefix crypto -- --config devnet/local/pilot-wallet/operator-config.local.json --vault devnet/local/pilot-wallet/operator-vault.json --document <pilot-release-evidence.json> --chain-id 84532 --nonce <next-nonce> --out <pilot-release-envelope.json>
npm run wallet:pilot-verify --prefix crypto -- --config devnet/local/pilot-wallet/operator-config.local.json --document <pilot-release-evidence.json> --envelope <pilot-release-envelope.json> --expected-nonce <next-nonce>
```

- PowerShell parser checks: passed.
- Secret-pattern scan: reviewed matches; output is limited to placeholders,
  test canaries, validation regexes, and documentation warnings.
- Public validator import check: passed; `validatePilotOperatorEnvelope` is
  exported and the public validator has no wallet/vault imports.
- `git merge --ff-only origin/main`: passed; branch initially advanced to
  `14f378b` without a merge commit.
- `git rebase origin/main`: passed; branch now sits on `c4959f8`, which
  includes the merged control-plane/dashboard proof command.
- `npm run flowchain:product-e2e`: passed in the raw current environment after
  the current rebase. Report:
  `devnet/local/product-e2e/flowchain-product-e2e-report.json`.
- `git diff --check`: passed with CRLF warnings only.

## Remaining Integration Follow-Up

No wallet/operator acceptance blocker remains. Explicit Slither audit still
reports findings in `contracts/bridge/BaseBridgeLockbox.sol`, which is outside
this task's wallet/operator write scope:

- `missing-zero-check` on `BaseBridgeLockbox.releaseNative(...).recipient`
  flowing into `recipient.call{value: amount}("")`.
- `low-level-calls` on `recipient.call{value: amount}("")`.

Read-only inspection found `_recordRelease` already rejects
`recipient == address(0)` at `contracts/bridge/BaseBridgeLockbox.sol:308-313`,
so the zero-check finding likely needs contract-structure or Slither-policy
handling. The low-level native call finding remains a hardening-policy issue.

GitHub issue #131 is the source-of-truth tracker for that audit follow-up:
https://github.com/FlowmemoryAI/FlowMemory/issues/131.

Wallet-branch evidence was posted to #131:
https://github.com/FlowmemoryAI/FlowMemory/issues/131#issuecomment-4446800854.

Post-fast-forward raw product E2E pass evidence was posted to #131:
https://github.com/FlowmemoryAI/FlowMemory/issues/131#issuecomment-4446898654.
