# Agent Bonds Pilot Deployment

Date: 2026-05-20

## Scope

This deployment path is for a capped Agent Bonds pilot only.

It is not approval for an uncapped public launch.

## Deployment Script

- `script/DeployAgentBondsPilot.s.sol`

## Deployment Guardrails

The script:

- only allows local Anvil, Base Sepolia, or Base mainnet chain ids
- requires explicit Base 8453 pilot acknowledgement for Base mainnet
- deploys the timelocked multisig, escrow, stake registry, policy registry, and manager contracts
- wires manager authority into escrow and stake registry
- creates one production-shaped objective task policy
- enables pilot mode
- configures pilot caps
- seeds one requester, one agent, one verifier, and one confirming verifier allowlist entry
- starts two-step ownership transfer for escrow, stake registry, policy registry, and manager to the deployed timelocked multisig

## Required Environment Inputs

The script expects explicit environment values for:

- broadcaster address
- owner address
- multisig owner addresses
- multisig threshold
- multisig minimum timelock delay
- pause guardian
- resolution authority
- settlement token
- stake token
- pilot requester
- pilot agent
- designated verifier
- confirming verifier
- stake thresholds
- capacity thresholds
- payout and exposure caps
- policy bond/fee basis points
- required confirmations
- submission/dispute/grace/availability windows
- minimum bond and fee floors
- evidence schema hash
- risk tier
- Base 8453 pilot acknowledgement when applicable

## Required Before Broadcast

1. validate the filled pilot config template
2. run `npm run flowmemory:agent-bonds:readiness`
3. run `npm run contracts:hardening:slither`
4. complete the operator separation checklist
5. hand the external review packet to the reviewer
6. confirm the public boundary docs still match the deployment plan

## Required After Broadcast

1. record deployed addresses, including the timelocked multisig address returned by the deployment script
2. have the timelocked multisig accept ownership of escrow, stake registry, policy registry, and manager through its queued/approved/executed operation flow
3. verify that pause guardian and resolution authority are the expected operators
4. re-run readiness and pilot config validation with the deployed addresses recorded in the pilot config file
5. publish only capped-pilot claims, not uncapped public-launch claims
