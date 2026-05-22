# Launch-Candidate Security Boundary Review

Date: 2026-05-13

Reviewer role: Security Review Agent

Result: pass for local/test V0 launch-candidate demos and guarded canary review.
Result: fail for any production, mainnet-launch, custody, verifier-network,
bridge, audited-cryptography, or production Uniswap hook claim.

## Scope

Reviewed the launch-candidate boundary across:

- source-of-truth docs: `docs/START_HERE.md`,
  `docs/FLOWMEMORY_HQ_CONTEXT.md`, `docs/CURRENT_STATE.md`,
  `docs/SECURITY_MODEL.md`, `docs/MARKETING_CLAIMS_GUARDRAILS.md`,
  `docs/PRODUCTION_READINESS_CHECKLIST.md`, and deployment/operator docs;
- existing review docs under `docs/reviews/`;
- contract boundary docs and selected contract surfaces for access-control
  assumptions;
- deployment, reader, canary, local wallet, and smoke scripts;
- README and launch-facing claim surfaces.

GitHub/source check: local `HEAD` and `origin/HEAD` both resolved to
`98386b9e40c271c5bac2d41ba3a9010d9e9da36e` before edits.

## Pass/Fail Matrix

| Area | V0 result | Notes |
| --- | --- | --- |
| Source-of-truth consistency | Pass with caveat | Current docs consistently say V0/local/test, with a real Base mainnet canary documented as canary-only. README still has older "do not claim mainnet deployment" wording that should be clarified to "production mainnet deployment" in a later README-scoped task. |
| Access control | Pass for V0, fail for production | Per-record owners, owner allowlists, self-registration, and open submission surfaces are documented. Direct deployer ownership, no multisig, no recovery, no timelock, and no decentralized verifier governance remain production blockers. |
| Unsafe claims | Pass after guardrail expansion | Claim scanning now covers README, docs, contract docs, and marketing, and blocks more production/mainnet launch wording unless explicitly framed as blocked, not implemented, or out of scope. |
| Secret handling | Pass for committed V0 surfaces, fail for production signing | `.gitignore`, CI secret checks, control-plane no-secret scanning, and canary reader outputs avoid committed credentials. The Base Sepolia deploy wrapper still passes a private key to `forge --private-key`, which is acceptable only as a local/test operator caveat. |
| Local wallet boundary | Pass for local no-value tests | The encrypted local test vault excludes private keys from public exports and is exercised in ignored `local test runtime/local/` output. It is not production custody, wallet connect, or value-bearing key management. |
| Deployment scripts | Pass for dry-run/testnet/canary boundaries | Base Sepolia deploy requires explicit env inputs. Base canary reading requires explicit acknowledgement, addresses, and small block ranges. Source verification redacts API key material. |
| Base mainnet canary | Pass as canary-only | The documented canary is real Base mainnet activity, but artifacts and dashboard state mark `productionReady: false` and separate canary data from local fixture acceptance. |
| Uniswap hook assumptions | Pass for V0, fail for production hook readiness | `FlowMemoryHookAdapter` is open/canary scaffold. `FlowMemoryAfterSwapHook` is PoolManager-gated and afterSwap-only, but there is no recorded mined hook address, deployment, PoolManager integration, source-verification plan, or go/no-go approval for production. |
| Verifier/trust claims | Pass for local signed statements | V0 verifier reports and attestations are deterministic signed claims. They are not zk proofs, decentralized consensus, staking, slashing, or a production verifier network. |
| Bridge and real funds | Pass for POC/canary-read boundary, fail for production bridge | `BaseBridgeLockbox` is test-only, owner-controlled, capped, and not trustless. Mainnet canary reads require real-funds acknowledgement and a small USD cap, but releases remain owner-controlled. |
| URI/off-chain data boundary | Pass as documented caveat | `metadataURI` and `evidenceURI` are arbitrary log strings. Contracts do not enforce length, content type, resolvability, privacy, or short-pointer behavior. |

## Blockers Before Any Production Claim

These are launch blockers for production language, not blockers for local/test
V0 demos:

- Record an explicit go/no-go decision in `docs/DECISIONS/`.
- Replace direct single-account operator ownership with a reviewed multisig or
  comparable account-control policy, including rotation and recovery.
- Separate deployer, worker admin, verifier admin, and emergency-response
  authority.
- Stop using command-line private-key broadcast for any production signing path;
  require a safer signer or keystore/hardware-wallet flow.
- Define verifier identity, signing policy, challenge lifecycle, finality,
  replay policy, and verifier-set governance.
- Complete and record source verification for every future deployed or
  redeployed contract address.
- For Uniswap v4, record the mined hook salt/address, hook permission bits,
  PoolManager address, constructor args, init code hash, deployment block,
  post-deploy reader range, and integration review.
- Keep broad Base mainnet readers disabled unless a separate production indexer
  design and incident-response plan are accepted.
- Add URI/pointer policy if any public copy implies off-chain storage
  enforcement, content availability, or privacy.
- Keep bridge releases, real-funds flows, and custody out of public user paths
  until a bridge threat model, release policy, caps, monitoring, and emergency
  playbook are accepted.
- Do not describe local wallet helpers as production custody or wallet support.
- Do not describe current verifier reports as audited or fully trustless proofs.

## Acceptable V0 Caveats

The following are acceptable only with explicit local/test/canary framing:

- Direct owner and owner-allowlist contracts for V0 commitment surfaces.
- Self-registration registries when downstream docs treat registrations as
  untrusted until verifier reports exist.
- Open submission surfaces that emit reconstructable commitments but do not
  custody funds or claim correctness.
- Base Sepolia deployment dry runs and explicit broadcasts using local ignored
  environment variables.
- Guarded Base mainnet canary reads for documented canary addresses and small
  explicit block ranges.
- A Base mainnet canary deployment described as canary-only and
  `productionReady: false`.
- Local encrypted no-value test vaults stored under ignored local output paths.
- Bridge POC observations and canary reads that do not claim production bridge
  security or real user deposit readiness.
- Fixture-backed dashboard and canary dashboard modes that stay visually and
  semantically separate.

## Concrete Guardrail Added

`infra/scripts/check-unsafe-claims.mjs` now:

- scans `contracts/` markdown boundary docs in addition to `README.md`,
  `docs/`, and `marketing/`;
- blocks unguarded positive claims for production launch, mainnet launch,
  production-mainnet, production deployment, production verifier network,
  production Uniswap hook, production bridge, production custody, and audited
  status;
- keeps existing allowances for lines or sections that clearly mark those
  phrases as blocked, rejected, gated, not implemented, or out of scope.

## Review Decision

No production or mainnet-launch claim is approved.

FlowMemory can proceed with V0 launch-candidate demos only if copy continues to
say local/test, Base Sepolia, guarded Base mainnet canary, no-value local test runtime,
fixture-backed dashboard, canary-only, and `productionReady: false` where
applicable.

