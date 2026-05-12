# START_HERE

## How to run multiple Codex agents safely from E drive

Use one Git worktree per Codex agent. Each worktree has its own branch and folder under `E:\FlowMemory`, so agents can work without sharing the same checkout.

Start from the main checkout:

```powershell
cd E:\FlowMemory\flowmemory-main
.\infra\scripts\setup-worktrees.ps1
```

The setup script creates these worktrees if they do not already exist:

```text
E:\FlowMemory\flowmemory-contracts   agent/contracts
E:\FlowMemory\flowmemory-indexer     agent/indexer
E:\FlowMemory\flowmemory-hardware    agent/hardware
E:\FlowMemory\flowmemory-dashboard   agent/dashboard
E:\FlowMemory\flowmemory-research    agent/research
E:\FlowMemory\flowmemory-crypto      agent/crypto
E:\FlowMemory\flowmemory-chain       agent/chain
E:\FlowMemory\flowmemory-review      agent/review
```

Run each Codex agent from its assigned worktree in a separate PowerShell window:

```powershell
cd E:\FlowMemory\flowmemory-contracts
codex
```

```powershell
cd E:\FlowMemory\flowmemory-indexer
codex
```

```powershell
cd E:\FlowMemory\flowmemory-hardware
codex
```

```powershell
cd E:\FlowMemory\flowmemory-dashboard
codex
```

```powershell
cd E:\FlowMemory\flowmemory-research
codex
```

```powershell
cd E:\FlowMemory\flowmemory-crypto
codex
```

```powershell
cd E:\FlowMemory\flowmemory-chain
codex
```

```powershell
cd E:\FlowMemory\flowmemory-review
codex
```

Safety rules:

- Keep `E:\FlowMemory\flowmemory-main` as the main checkout and coordination point.
- Run each agent only inside its assigned worktree folder.
- Check `git status --short --branch` before starting and before handing off work.
- Avoid assigning two agents to edit the same files at the same time.
- Use `git worktree list` from `E:\FlowMemory\flowmemory-main` to inspect all local worktrees.
