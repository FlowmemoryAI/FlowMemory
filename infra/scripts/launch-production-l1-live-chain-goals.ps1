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

$promptRoot = Join-Path $repoRoot "docs\agent-goals\production-l1-live-chain"

$agents = @(
    @{ Name = "live-hq"; Worktree = "E:\FlowMemory\flowmemory-live-hq"; Branch = "agent/live-product-hq"; Prompt = "01-hq-orchestrator.md" },
    @{ Name = "runtime-consensus"; Worktree = "E:\FlowMemory\flowmemory-live-runtime"; Branch = "agent/live-product-runtime-consensus"; Prompt = "02-chain-runtime-consensus.md" },
    @{ Name = "node-rpc"; Worktree = "E:\FlowMemory\flowmemory-live-node-rpc"; Branch = "agent/live-product-node-rpc"; Prompt = "03-node-rpc-network.md" },
    @{ Name = "wallet-keys"; Worktree = "E:\FlowMemory\flowmemory-live-wallet-keys"; Branch = "agent/live-product-wallet-keys"; Prompt = "04-wallet-keys-signing.md" },
    @{ Name = "ledger-execution"; Worktree = "E:\FlowMemory\flowmemory-live-ledger"; Branch = "agent/live-product-ledger-execution"; Prompt = "05-transaction-ledger-execution.md" },
    @{ Name = "base8453-bridge"; Worktree = "E:\FlowMemory\flowmemory-live-bridge-relayer"; Branch = "agent/live-product-base8453-bridge"; Prompt = "06-base8453-bridge-relayer.md" },
    @{ Name = "bridge-credit"; Worktree = "E:\FlowMemory\flowmemory-live-bridge-credit"; Branch = "agent/live-product-bridge-credit-withdrawal"; Prompt = "07-bridge-credit-withdrawal.md" },
    @{ Name = "assets-dex"; Worktree = "E:\FlowMemory\flowmemory-live-assets-dex"; Branch = "agent/live-product-assets-dex"; Prompt = "08-assets-dex-swap.md" },
    @{ Name = "control-plane"; Worktree = "E:\FlowMemory\flowmemory-live-control-plane"; Branch = "agent/live-product-control-plane-explorer"; Prompt = "09-control-plane-explorer.md" },
    @{ Name = "wallet-apps"; Worktree = "E:\FlowMemory\flowmemory-live-wallet-apps"; Branch = "agent/live-product-wallet-apps"; Prompt = "10-desktop-mobile-wallet.md" },
    @{ Name = "ops-installer"; Worktree = "E:\FlowMemory\flowmemory-live-ops"; Branch = "agent/live-product-ops-installer"; Prompt = "11-ops-installer-monitoring.md" },
    @{ Name = "storage-recovery"; Worktree = "E:\FlowMemory\flowmemory-live-storage"; Branch = "agent/live-product-state-storage-recovery"; Prompt = "12-state-storage-recovery.md" },
    @{ Name = "verification"; Worktree = "E:\FlowMemory\flowmemory-live-verification"; Branch = "agent/live-product-verification"; Prompt = "13-live-product-verification.md" },
    @{ Name = "sdk-docs"; Worktree = "E:\FlowMemory\flowmemory-live-sdk-docs"; Branch = "agent/live-product-sdk-docs"; Prompt = "14-sdk-docs-developer-tooling.md" }
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

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
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

Write-Host "Production L1 live-chain goal launch complete."
