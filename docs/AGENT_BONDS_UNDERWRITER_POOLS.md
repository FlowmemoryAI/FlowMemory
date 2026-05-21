# Agent Bonds Underwriter Pools

Underwriter pools are not insurance.

Use the following terms:
- capacity backing;
- recourse backing;
- underwriting;
- loss allocation.

Do not claim:
- insured;
- guaranteed reimbursement;
- risk-free protection.

Two pool types are modeled:
- stake capacity pools backed by the project token;
- USDC recourse pools backed by USDC.

Pools are optional and additive. Basic Agent Bonds tasks must not require them.

The repo now includes an onchain USDC recourse-pool implementation and registry surface:
- `contracts/AgentUnderwriterPool.sol`
- `contracts/UnderwriterPoolRegistry.sol`

The current Agent Bonds manager can optionally lock approved USDC recourse coverage per task through `openTaskWithRecourse(...)`.

Covered failure paths currently include:
- invalid verifier-confirmed task failure;
- expired no-submission slash.

Successful and refunded tasks release the locked recourse coverage back to the pool.
