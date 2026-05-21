# Agent Bonds Public Launch Approval

Date: 2026-05-20

## Purpose

This document defines the final repo-side gate for a public value-bearing Agent Bonds launch.

## Required Inputs

- filled pilot config
- green readiness report
- built operator bundle
- completed external review report
- completed operator separation checklist
- completed multi-operator runtime evidence report
- signed go/no-go decision record

Practical reading of the launch packet fields:

- `settlementToken` in the pilot config is the stable asset used for refunds, payouts, verifier fees, and bonds.
- `stakeToken` in the pilot config is your project token.
- `multisigOwners` are operational signers. They do not imply multiple company owners; a single company owner can still use a company-controlled multisig.


The expected structured sign-off artifacts live under `fixtures/agent-bonds/approvals/` and are validated against JSON schemas in `schemas/flowmemory/`.

If you do not yet have the actual deployment and operator values handy, start with `docs/OPERATIONS/AGENT_BONDS_OWNER_INPUTS.md` and `fixtures/agent-bonds/owner-inputs.template.json`.


You can assemble a launch approval packet from the pilot config plus the four structured approval artifacts with:

```powershell
npm run flowmemory:agent-bonds:public-launch:assemble -- fixtures/agent-bonds/launch-approval.generated.json fixtures/agent-bonds/pilot-config.template.json fixtures/agent-bonds/approvals/external-review.template.json fixtures/agent-bonds/approvals/operator-separation.template.json fixtures/agent-bonds/approvals/runtime-evidence.template.json fixtures/agent-bonds/approvals/go-no-go.template.json devnet/local/agent-bonds-readiness/agent-bonds-readiness-report.json out/agent-bonds-operator-bundle
```

If you are starting from owner inputs instead of hand-editing every file, first run:

```powershell
npm run flowmemory:agent-bonds:owner-inputs:materialize -- fixtures/agent-bonds/owner-inputs.template.json fixtures/agent-bonds/pilot-config.generated.json fixtures/agent-bonds/approvals/external-review.generated.json fixtures/agent-bonds/approvals/operator-separation.generated.json fixtures/agent-bonds/approvals/runtime-evidence.generated.json fixtures/agent-bonds/approvals/go-no-go.generated.json fixtures/agent-bonds/launch-approval.generated.json
```

If you want one command that performs owner-input validation, materialization, operator bundle generation, and final gate evaluation, run:

```powershell
npm run flowmemory:agent-bonds:public-launch:package -- fixtures/agent-bonds/owner-inputs.template.json fixtures/agent-bonds/generated
```



## Validation Command

When those inputs exist, run:

```powershell
npm run flowmemory:agent-bonds:public-launch:validate -- fixtures/agent-bonds/launch-approval.generated.json fixtures/agent-bonds/pilot-config.template.json
```

The validator must fail while any required sign-off remains pending.

## What Success Means

A passing public-launch validation means the repo has direct evidence for:

- challenge-reduced verifier trust
- internally reviewed local contract surface plus static analysis evidence
- multisig / timelock / emergency custody controls
- capped pilot controls and exposure limits
- evidence-availability enforcement
- economic simulation evidence
- runtime readiness and recovery evidence
- operator reproducibility package
- honest launch boundary docs
- explicit owner and reviewer sign-offs

## What Success Does Not Mean

A passing repo validator still does not guarantee market success, legal sufficiency, or operational perfection. It means the launch claim is backed by concrete repository evidence instead of guesswork.
