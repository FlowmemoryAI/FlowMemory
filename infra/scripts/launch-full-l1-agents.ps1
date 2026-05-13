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

$promptRoot = Join-Path $repoRoot "docs\agent-goals\full-l1"

$agents = @(
    @{
        Name = "chain-runtime"
        Worktree = "E:\FlowMemory\flowmemory-chain"
        Branch = "agent/full-l1-runtime"
        Prompt = "chain-runtime.md"
    },
    @{
        Name = "crypto-wallet"
        Worktree = "E:\FlowMemory\flowmemory-crypto"
        Branch = "agent/full-l1-crypto-wallet"
        Prompt = "crypto-wallet.md"
    },
    @{
        Name = "control-plane-indexer"
        Worktree = "E:\FlowMemory\flowmemory-indexer"
        Branch = "agent/full-l1-control-plane"
        Prompt = "control-plane-indexer.md"
    },
    @{
        Name = "dashboard-workbench"
        Worktree = "E:\FlowMemory\flowmemory-dashboard"
        Branch = "agent/full-l1-workbench"
        Prompt = "dashboard-workbench.md"
    },
    @{
        Name = "contracts-settlement"
        Worktree = "E:\FlowMemory\flowmemory-contracts"
        Branch = "agent/full-l1-contracts"
        Prompt = "contracts-settlement.md"
    },
    @{
        Name = "bridge-relayer"
        Worktree = "E:\FlowMemory\flowmemory-bridge-full"
        Branch = "agent/full-l1-bridge"
        Prompt = "bridge-relayer.md"
        CreateWorktree = $true
    },
    @{
        Name = "hardware-signals"
        Worktree = "E:\FlowMemory\flowmemory-hardware"
        Branch = "agent/full-l1-hardware"
        Prompt = "hardware-signals.md"
    },
    @{
        Name = "research-consensus"
        Worktree = "E:\FlowMemory\flowmemory-research"
        Branch = "agent/full-l1-research-consensus"
        Prompt = "research-consensus.md"
    },
    @{
        Name = "hq-integration-review"
        Worktree = "E:\FlowMemory\flowmemory-review"
        Branch = "agent/full-l1-hq-integration"
        Prompt = "hq-integration-review.md"
    }
)

function Invoke-Git {
    param(
        [string] $WorkingDirectory,
        [string[]] $Arguments
    )

    & git -C $WorkingDirectory @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed in $WorkingDirectory"
    }
}

function Test-DirtyWorktree {
    param([string] $Path)

    $status = & git -C $Path status --short
    if ($LASTEXITCODE -ne 0) {
        throw "Could not inspect worktree: $Path"
    }
    return [bool]$status
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

    if (-not $NoBranchPrepare -and (Test-Path -LiteralPath $worktree)) {
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

Write-Host "Full L1 agent launch complete."
