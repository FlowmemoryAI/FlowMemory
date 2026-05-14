# Retry After Issue 131

Use this file when GitHub issue #131 is resolved or a source-of-truth fix for
the Slither/product-e2e blocker lands on `main`.

## Preconditions

- #131 is closed, or the owning contracts/review agent confirms the exact
  `npm run flowchain:product-e2e` gate should now pass when Slither is present
  on `PATH`.
- This hardware branch has been updated only if the update is allowed by the
  current task scope or explicitly approved by HQ.
- No generated side effects outside the hardware-signals scope are kept.

## Commands

Run from `E:\FlowMemory\flowmemory-hardware`:

```powershell
git fetch --all --prune
gh issue view 131 --repo FlowmemoryAI/FlowMemory --json number,state,updatedAt,url
npm run flowchain:hardware:smoke
git diff --check
npm run flowchain:product-e2e
node -e "const p=require('./package.json'); console.log(Object.prototype.hasOwnProperty.call(p.scripts,'flowchain:l1-e2e') ? 'exists' : 'missing')"
```

If `flowchain:l1-e2e` exists after a mainline update, run it last:

```powershell
npm run flowchain:l1-e2e
```

## Completion Rule

Only mark the hardware-signals goal complete when:

- `npm run flowchain:hardware:smoke` passes.
- `git diff --check` passes.
- Exact `npm run flowchain:product-e2e` passes in the unmodified environment.
- `npm run flowchain:l1-e2e` is either absent or passes.
- Generated side effects outside the allowed hardware-signals scope are removed.

Then update:

- `docs/agent-runs/hardware-signals/AUDIT.md`
- `docs/agent-runs/hardware-signals/CHECKLIST.md`
- `docs/agent-runs/hardware-signals/EXPERIMENTS.md`
- `docs/agent-runs/hardware-signals/NOTES.md`
- `docs/agent-runs/hardware-signals/PR_SUMMARY.md`
