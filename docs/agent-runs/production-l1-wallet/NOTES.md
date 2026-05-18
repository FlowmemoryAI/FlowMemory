# Owner-Gated L1 Wallet Notes

## Starting Context

- Repository state is launch-candidate V0 hardening with a private/local FlowChain testnet package as the next milestone.
- Current project docs explicitly keep production mainnet, public validators, production bridge, tokenomics, and audited cryptography out of scope.
- This wallet work must focus on local/private pilot usability: local vault custody, public metadata, signed envelopes, local transfer proof, product/DEX/withdrawal signing, and safe operator bridge preparation.

## Source-Of-Truth Check

- `infra/scripts/status-report.ps1` reported current GitHub PRs and issues. No direct conflict was found with this assigned wallet worktree.
- Sibling worktrees have unrelated dirty changes; this task will not edit those folders or generated outputs.
