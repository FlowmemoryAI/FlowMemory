# Production L1 Crypto Experiments

This file records runnable checks and implementation experiments for the production-L1 crypto work.

## Planned Checks

- `npm test --prefix crypto`
- `npm run validate:vectors --prefix crypto`
- `npm run validate:production-l1-crypto --prefix crypto`
- `npm run wallet:e2e --prefix crypto`
- `git diff --check`

## Results

- `npm test --prefix crypto`
  - Result: pass, 23 tests.
- `npm run validate:vectors --prefix crypto`
  - Result: `FLOWMEMORY_CRYPTO_VECTORS_OK 46`.
- `npm run validate:production-l1-crypto --prefix crypto`
  - Result: `FLOWCHAIN_PRODUCTION_L1_CRYPTO_OK positive=11 negative=14 hashHelpers=13 schemas=6`.
- `npm run wallet:e2e --prefix crypto`
  - Result: pass, signed transfer verified, mutated payload failed, wrong chain failed.
- `npm run scan:no-secrets --prefix crypto`
  - Result: pass.
- `git diff --check`
  - Result: pass. Git printed CRLF normalization warnings only.
