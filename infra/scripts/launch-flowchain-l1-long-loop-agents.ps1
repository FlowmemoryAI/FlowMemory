param(
    [switch] $DryRun,
    [switch] $NoBranchPrepare
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = (& git rev-parse --show-toplevel).Trim()
if ([string]::IsNullOrWhiteSpace($repoRoot)) {
    throw "Run this script inside the FlowMemory repository."
}

$promptRoot = Join-Path $repoRoot "docs\agent-goals\flowchain-l1-long-loop"

$agents = @(
    @{
        Name = "chain-network"
        Worktree = "E:\FlowMemory\flowmemory-chain"
        Branch = "agent/l1-loop-chain-network"
        Prompt = "chain-network.md"
    },
    @{
        Name = "wallet-crypto"
        Worktree = "E:\FlowMemory\flowmemory-crypto"
        Branch = "agent/l1-loop-wallet-crypto"
        Prompt = "wallet-crypto.md"
    },
    @{
        Name = "control-plane-explorer"
        Worktree = "E:\FlowMemory\flowmemory-indexer"
        Branch = "agent/l1-loop-control-plane-explorer"
        Prompt = "control-plane-explorer.md"
    },
    @{
        Name = "dashboard-workbench"
        Worktree = "E:\FlowMemory\flowmemory-dashboard"
        Branch = "agent/l1-loop-dashboard-workbench"
        Prompt = "dashboard-workbench.md"
    },
    @{
        Name = "bridge-testnet"
        Worktree = "E:\FlowMemory\flowmemory-bridge-full"
        Branch = "agent/l1-loop-bridge-testnet"
        Prompt = "bridge-testnet.md"
    },
    @{
        Name = "contracts-settlement"
        Worktree = "E:\FlowMemory\flowmemory-contracts"
        Branch = "agent/l1-loop-contracts-settlement"
        Prompt = "contracts-settlement.md"
    },
    @{
        Name = "installer-ops"
        Worktree = "E:\FlowMemory\flowmemory-review"
        Branch = "agent/l1-loop-installer-ops"
        Prompt = "installer-ops.md"
    },
    @{
        Name = "hq-review"
        Worktree = "E:\FlowMemory\flowmemory-hq-review-loop"
        Branch = "agent/l1-loop-hq-review"
        Prompt = "hq-review.md"
        CreateWorktree = $true
    },
    @{
        Name = "hardware-signals"
        Worktree = "E:\FlowMemory\flowmemory-hardware"
        Branch = "agent/l1-loop-hardware-signals"
        Prompt = "hardware-signals.md"
    },
    @{
        Name = "research-decisions"
        Worktree = "E:\FlowMemory\flowmemory-research"
        Branch = "agent/l1-loop-research-decisions"
        Prompt = "research-decisions.md"
    }
)

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string] $WorkingDirectory,

        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    & git -C $WorkingDirectory @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed in $WorkingDirectory"
    }
}

function Test-DirtyWorktree {
    param([Parameter(Mandatory = $true)][string] $Path)

    $status = & git -C $Path status --short
    if ($LASTEXITCODE -ne 0) {
        throw "Could not inspect worktree: $Path"
    }
    return [bool] $status
}

Write-Host "Fetching origin/main..."
Invoke-Git -WorkingDirectory $repoRoot -Arguments @("fetch", "origin", "main")

foreach ($agent in $agents) {
    $worktree = $agent.Worktree
    $branch = $agent.Branch
    $promptPath = Join-Path $promptRoot $agent.Prompt

    if (-not (Test-Path -LiteralPath $promptPath)) {
        throw "Missing prompt file: $promptPath"
    }

    if (-not (Test-Path -LiteralPath $worktree)) {
        if ($agent.CreateWorktree) {
            Write-Host "Creating worktree $worktree on $branch"
            if (-not $DryRun) {
                & git -C $repoRoot worktree add -B $branch $worktree origin/main
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to create worktree $worktree"
                }
            }
        }
        else {
            throw "Missing worktree: $worktree"
        }
    }

    if (-not $NoBranchPrepare) {
        if (Test-DirtyWorktree -Path $worktree) {
            Write-Warning "Skipping branch switch for dirty worktree: $worktree"
        }
        else {
            Write-Host "Preparing $($agent.Name): $branch from origin/main"
            if (-not $DryRun) {
                Invoke-Git -WorkingDirectory $worktree -Arguments @("switch", "-C", $branch, "origin/main")
            }
        }
    }

    $command = @"
`$prompt = Get-Content -Raw -LiteralPath "$promptPath"
Set-Location -LiteralPath "$worktree"
codex --cd "$worktree" -s danger-full-access -a never `$prompt
"@

    Write-Host "Launching $($agent.Name) in $worktree"
    if (-not $DryRun) {
        Start-Process powershell.exe -ArgumentList @(
            "-NoExit",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            $command
        )
    }
}

Write-Host "FlowChain L1 long-loop agent launch complete."
