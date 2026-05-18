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

$promptRoot = Join-Path $repoRoot "docs\agent-goals\flowchain-real-value-pilot"

$agents = @(
    @{
        Name = "pilot-hq"
        Worktree = "E:\FlowMemory\flowmemory-live-hq"
        Branch = "agent/real-value-pilot-hq"
        Prompt = "pilot-hq.md"
    },
    @{
        Name = "pilot-contracts"
        Worktree = "E:\FlowMemory\flowmemory-live-contracts"
        Branch = "agent/real-value-pilot-contracts"
        Prompt = "pilot-contracts.md"
    },
    @{
        Name = "pilot-bridge-relayer"
        Worktree = "E:\FlowMemory\flowmemory-live-bridge"
        Branch = "agent/real-value-pilot-bridge"
        Prompt = "pilot-bridge-relayer.md"
    },
    @{
        Name = "pilot-chain-runtime"
        Worktree = "E:\FlowMemory\flowmemory-live-chain"
        Branch = "agent/real-value-pilot-chain"
        Prompt = "pilot-chain-runtime.md"
    },
    @{
        Name = "pilot-wallet-operator"
        Worktree = "E:\FlowMemory\flowmemory-live-wallet"
        Branch = "agent/real-value-pilot-wallet"
        Prompt = "pilot-wallet-operator.md"
    },
    @{
        Name = "pilot-control-dashboard"
        Worktree = "E:\FlowMemory\flowmemory-live-control-dashboard"
        Branch = "agent/real-value-pilot-control-dashboard"
        Prompt = "pilot-control-plane-dashboard.md"
    },
    @{
        Name = "pilot-ops-installer"
        Worktree = "E:\FlowMemory\flowmemory-live-ops"
        Branch = "agent/real-value-pilot-ops"
        Prompt = "pilot-ops-installer.md"
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
        Write-Host "Creating worktree $worktree on $branch"
        if (-not $DryRun) {
            & git -C $repoRoot worktree add -B $branch $worktree origin/main
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create worktree $worktree"
            }
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

Write-Host "FlowChain real-value pilot agent launch complete."
