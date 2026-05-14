# Real-Value Pilot Wallet Experiments

## Planned Checks

| Check | Command | Result |
| --- | --- | --- |
| Crypto tests | `npm test --prefix crypto` | pass: 23 tests, including fail-closed pilot config validation for unsupported chain id, malformed cap id, zero cap, used-over-max cap, closed cap window, secret-shaped local path, Base mainnet non-`USDC-6` cap, and Base mainnet cap above 25 USD |
| Product wallet smoke | `npm run wallet:product-smoke --prefix crypto` | pass: 8 documents, 8 transactions, 9 negative transactions |
| Pilot wallet E2E | `npm run wallet:pilot-e2e --prefix crypto` | pass: 5 documents, 5 envelopes, 7 negative cases; validates pilot config/public metadata schemas with five next commands |
| Root pilot wallet command | `npm run flowchain:real-value-pilot:wallet` | pass: delegates to `crypto` pilot E2E; 5 documents, 5 envelopes, 7 negative cases |
| Env config CLI | `npm run wallet:pilot-config --prefix crypto -- --created-at-unix-ms 1778702400000 --out out/pilot-wallet-config-check.json` with explicit `FLOWCHAIN_PILOT_*` env values | pass: wrote validated non-secret config |
| Standalone public metadata CLI | `wallet:create`, `wallet:pilot-config`, and `wallet:pilot-metadata` under `crypto/out/pilot-metadata-cli` with operator id derived from the created vault | pass: metadata operator matched the vault signer and output contained no secret-shaped material |
| Standalone public metadata mismatch CLI | `wallet:create`, `wallet:pilot-config`, and `wallet:pilot-metadata` under `crypto/out/pilot-metadata-negative-cli` with a mismatched config operator id | pass: `wallet:pilot-metadata` failed with `active operator signer matching the pilot config` |
| Standalone pilot sign/verify CLI | `wallet:create`, `wallet:pilot-config`, generated release evidence, `wallet:pilot-sign`, and `wallet:pilot-verify` under `crypto/out/pilot-sign-cli` | pass: verify output was `{ "valid": true, "errors": [] }` |
| Next-command CLI | `npm run wallet:pilot-next --prefix crypto -- --config out/pilot-wallet-config-check.json` | pass: printed deploy plan, observe, bridge credit smoke, release signing, and release verification commands |
| Fast-forward source-of-truth | `git merge --ff-only origin/main` | pass: branch initially advanced to `14f378b`, which makes Slither optional for the default hardening gate |
| Rebase source-of-truth | `git rebase origin/main` | pass: branch now sits on `c4959f8`, which includes the merged control-plane/dashboard pilot proof |
| Product E2E, raw current environment | `npm run flowchain:product-e2e` | pass after current rebase; wrote `devnet/local/product-e2e/flowchain-product-e2e-report.json` |
| Slither audit reproduction | `slither . --config-file .slither.config.json` | fail: `missing-zero-check` and `low-level-calls` on `BaseBridgeLockbox.releaseNative`; `_recordRelease` has the zero-recipient runtime check, so follow-up belongs to contract/hardening owner and is tracked by #131 |
| Product E2E, optional-Slither path | `npm run flowchain:product-e2e` with only `C:\Users\ntrap\AppData\Roaming\Python\Python311\Scripts` removed from `PATH` | pass |
| GitHub blocker lookup | `gh issue list --search "BaseBridgeLockbox slither OR releaseNative" --limit 20`; `gh issue view 131 --json number,title,state,labels,url,body` | pass: source-of-truth blocker is open as #131, `[contracts/security] Reconcile Slither findings blocking flowchain product E2E` |
| GitHub blocker handoff | `gh issue comment 131 --body-file -` | posted wallet-branch evidence to https://github.com/FlowmemoryAI/FlowMemory/issues/131#issuecomment-4446800854 |
| GitHub post-fast-forward handoff | `gh issue comment 131 --body-file -` | posted raw product E2E pass evidence to https://github.com/FlowmemoryAI/FlowMemory/issues/131#issuecomment-4446898654 |
| PowerShell parser, config wrapper | `$tokens = $null; $errors = $null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'infra/scripts/flowchain-wallet-pilot-config.ps1'), [ref] $tokens, [ref] $errors) \| Out-Null; if ($errors.Count -gt 0) { $errors \| Format-List \| Out-String; exit 1 }; 'flowchain-wallet-pilot-config.ps1 parser OK'` | pass |
| PowerShell parser, observe wrapper | `$tokens = $null; $errors = $null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'infra/scripts/flowchain-wallet-pilot-observe.ps1'), [ref] $tokens, [ref] $errors) \| Out-Null; if ($errors.Count -gt 0) { $errors \| Format-List \| Out-String; exit 1 }; 'flowchain-wallet-pilot-observe.ps1 parser OK'` | pass |
| Secret boundary scan | `rg -n "private[_ -]?key\|seed phrase\|mnemonic\|rpc[_ -]?url\|api[_ -]?key\|webhook\|BEGIN .*PRIVATE\|FLOWMEMORY_TEST_WALLET_PASSWORD\|FLOWCHAIN_PILOT_RPC_URL" crypto schemas/flowmemory infra/scripts/flowchain-wallet-pilot-config.ps1 infra/scripts/flowchain-wallet-pilot-observe.ps1 docs/OPERATIONS docs/agent-runs/real-value-pilot-wallet` | reviewed: matches are placeholders, test canaries, validation regexes, and documentation warnings |
| Public validator import check | `node --input-type=module -e "const mod = await import('./crypto/src/pilot-envelope-validation.js'); const names = Object.keys(mod).sort(); console.log(names.join('\n')); if (!names.includes('validatePilotOperatorEnvelope')) process.exit(1);"` | pass: `validatePilotOperatorEnvelope` is exported |
| Public validator vault scan | `rg -n -e 'from "\.\/wallet\.js"' -e "from './wallet\.js'" -e 'createEncryptedTestVault' -e 'unlockEncryptedTestVault' -e 'signLocalTransactionWithVault' crypto/src/pilot-envelope-validation.js crypto/src/pilot-envelope-validation.d.ts; if ($LASTEXITCODE -eq 1) { 'no wallet/vault imports in pilot public validator'; exit 0 } elseif ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }` | pass: no wallet/vault imports in public validator |
| Diff whitespace | `git diff --check` | pass with CRLF warnings only |

## Verification Cases

- Wrong chain ID.
- Wrong contract address.
- Wrong operator.
- Mutated payload.
- Replay nonce.
- Expired message.
- Missing cap fields.
- Public validation subpath does not import vault create, unlock, or signing helpers.
- Config-from-env output excludes local network credentials and signing material.
- Secret-shaped material excluded from public metadata.
