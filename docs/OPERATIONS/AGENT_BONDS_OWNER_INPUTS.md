# Agent Bonds Owner Inputs

Date: 2026-05-20

## Purpose

If you want me to assemble the final public-launch packet for you, I need one real-world input set from you.


## Machine-Readable Input Template

- `fixtures/agent-bonds/owner-inputs.template.json`
- `schemas/flowmemory/agent-bonds-owner-inputs.schema.json`
- `npm run flowmemory:agent-bonds:owner-inputs:validate -- fixtures/agent-bonds/owner-inputs.template.json`
- `npm run flowmemory:agent-bonds:owner-inputs:status -- fixtures/agent-bonds/owner-inputs.canary-reference.json fixtures/agent-bonds/discovered-live-references.json`

## One-Command Materialization

Once you fill `fixtures/agent-bonds/owner-inputs.template.json`, you can generate the pilot config plus approval scaffolding with:

```powershell
npm run flowmemory:agent-bonds:owner-inputs:materialize -- fixtures/agent-bonds/owner-inputs.template.json fixtures/agent-bonds/pilot-config.generated.json fixtures/agent-bonds/approvals/external-review.generated.json fixtures/agent-bonds/approvals/operator-separation.generated.json fixtures/agent-bonds/approvals/runtime-evidence.generated.json fixtures/agent-bonds/approvals/go-no-go.generated.json fixtures/agent-bonds/launch-approval.generated.json
```


## Canary-Prefilled Starting Point

If you want a repo-backed starting point that already includes the strongest discovered live address, use:

- `fixtures/agent-bonds/owner-inputs.canary-reference.json`

Then inspect what is still unresolved with:

```powershell
npm run flowmemory:agent-bonds:owner-inputs:status -- fixtures/agent-bonds/owner-inputs.canary-reference.json fixtures/agent-bonds/discovered-live-references.json
```

## One-Command Packaging

If you have a real filled owner-input file and want the repo to do the full repo-side packaging flow for you, run:

```powershell
npm run flowmemory:agent-bonds:public-launch:package -- fixtures/agent-bonds/owner-inputs.template.json fixtures/agent-bonds/generated
```

That will:

- validate the owner inputs
- materialize pilot config and approval artifacts
- rebuild the operator bundle
- attempt public-launch validation
- tell you whether you are only blocked on external signoff or fully ready



## Minimum Inputs You Must Supply

### 1. Real deployment / target network inputs

- target network name
- target chain id
- settlement token address
- stake token address
- deployed escrow address
- deployed stake registry address
- deployed policy registry address
- deployed manager address
- deployed multisig address

### Practical token split if you only launch one token

- `settlementToken` should be an external stable settlement asset, typically USDC on Base or another stablecoin you are willing to use for refunds, payouts, verifier fees, and bonds.
- `stakeToken` should be your project token.
  - If you are using Base mainnet, the official Circle USDC address is `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`.
- If you are launching only one project token, that token belongs in `stakeToken`, not `settlementToken`.

### Current implemented utility for your project token

- stake the token to become an eligible agent
- stake the token to become an eligible verifier
- increase allowed open-task bond capacity through larger stake
- accept slash exposure on verifier/operator misbehavior through the stake registry

If you launch the token tomorrow, those are the clean utility lanes already grounded by the current repo. Do not market the token as the stable payout/refund asset.



### 2. Real operator roles

- multisig owner 1
- multisig owner 2
- multisig owner 3
- multisig threshold
- pause guardian
- resolution authority
- designated verifier
- confirming verifier
- allowlisted requester
- allowlisted agent

### Practical operator note if you own the company

- `multisigOwners` are signer addresses, not separate equity owners.
- If you are the sole company owner, the recommended production-shaped setup is still a 2-of-3 or similar company-controlled multisig using separate signer devices or wallets you control.
- A single hot-wallet owner path is acceptable for internal/local testing, but it is not the safer public value-bearing posture this launch gate is trying to enforce.


### 3. Real caps and policy

- max payout per task
- max open exposure
- max open tasks
- required confirmations
- minimum availability window

### 4. Real sign-offs

- external reviewer name / firm
- external review completion date
- owner signoff name
- runtime rehearsal completion date
- final go/no-go decision owner and date

## Existing Live References Already Found In Repo

The strongest candidate prior live address already committed in the repo is:

- `0x3A6fBA5a78216ba3a8DA8d8F501dee2C8186aFf9`

See:

- `docs/OPERATIONS/AGENT_BONDS_DISCOVERED_LIVE_REFERENCES.md`
- `fixtures/agent-bonds/discovered-live-references.json`
- `fixtures/agent-bonds/owner-inputs.canary-reference.json`

## After You Give Me Those Inputs

I can convert them into:

- a filled pilot config
- filled approval artifacts
- an assembled launch approval packet
- a final public-launch validation run
- the exact list of any remaining external blockers
