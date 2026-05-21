# Agent Bonds Approval Artifacts

These files are the structured sign-off inputs for the final public-launch gate.

Files:

- `external-review.template.json`
- `operator-separation.template.json`
- `runtime-evidence.template.json`
- `go-no-go.template.json`

Workflow:

1. replace each template with real values after the real-world step is complete;
2. keep the referenced markdown/report documents updated;
3. assemble a launch approval packet with:

```powershell
npm run flowmemory:agent-bonds:public-launch:assemble -- fixtures/agent-bonds/launch-approval.generated.json fixtures/agent-bonds/pilot-config.template.json fixtures/agent-bonds/approvals/external-review.template.json fixtures/agent-bonds/approvals/operator-separation.template.json fixtures/agent-bonds/approvals/runtime-evidence.template.json fixtures/agent-bonds/approvals/go-no-go.template.json devnet/local/agent-bonds-readiness/agent-bonds-readiness-report.json out/agent-bonds-operator-bundle
```

4. validate with:

```powershell
npm run flowmemory:agent-bonds:public-launch:validate -- fixtures/agent-bonds/launch-approval.generated.json fixtures/agent-bonds/pilot-config.template.json
```
