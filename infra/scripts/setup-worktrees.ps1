$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$expectedRepo = "E:\FlowMemory\flowmemory-main"
$flowMemoryRoot = "E:\FlowMemory"

function Resolve-CanonicalPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    return (Resolve-Path -LiteralPath $Path).Path.TrimEnd("\")
}

function Test-GitRef {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Ref
    )

    & git show-ref --verify --quiet $Ref *> $null
    return $LASTEXITCODE -eq 0
}

function Add-AgentWorktree {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $Branch
    )

    if (Test-Path -LiteralPath $Path) {
        Write-Host "Exists, skipping: $Path"
        return
    }

    Write-Host "Creating: $Path ($Branch)"

    if (Test-GitRef "refs/heads/$Branch") {
        & git worktree add $Path $Branch
    }
    elseif (Test-GitRef "refs/remotes/origin/$Branch") {
        & git worktree add -b $Branch $Path "origin/$Branch"
    }
    else {
        & git worktree add -b $Branch $Path HEAD
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create worktree $Path for branch $Branch."
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git was not found on PATH. Install Git or add it to PATH, then rerun this script."
}

$currentPath = Resolve-CanonicalPath (Get-Location).Path
$expectedPath = Resolve-CanonicalPath $expectedRepo

if ($currentPath -ne $expectedPath) {
    throw "Run this script from $expectedRepo. Current path: $currentPath"
}

$gitRootRaw = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Current directory is not inside a Git repository."
}

$gitRoot = Resolve-CanonicalPath $gitRootRaw
if ($gitRoot -ne $expectedPath) {
    throw "Expected Git root $expectedRepo, but found $gitRoot."
}

$worktrees = @(
    @{ Path = "$flowMemoryRoot\flowmemory-contracts"; Branch = "agent/contracts" },
    @{ Path = "$flowMemoryRoot\flowmemory-indexer"; Branch = "agent/indexer" },
    @{ Path = "$flowMemoryRoot\flowmemory-hardware"; Branch = "agent/hardware" },
    @{ Path = "$flowMemoryRoot\flowmemory-dashboard"; Branch = "agent/dashboard" },
    @{ Path = "$flowMemoryRoot\flowmemory-research"; Branch = "agent/research" },
    @{ Path = "$flowMemoryRoot\flowmemory-crypto"; Branch = "agent/crypto" },
    @{ Path = "$flowMemoryRoot\flowmemory-chain"; Branch = "agent/chain" },
    @{ Path = "$flowMemoryRoot\flowmemory-review"; Branch = "agent/review" }
)

foreach ($worktree in $worktrees) {
    Add-AgentWorktree -Path $worktree.Path -Branch $worktree.Branch
}

Write-Host ""
Write-Host "Exact cd commands:"
foreach ($worktree in $worktrees) {
    Write-Host "cd $($worktree.Path)"
}

Write-Host ""
Write-Host "How to run Codex in each worktree:"
Write-Host "Open a separate PowerShell window for each agent, then run one cd command followed by codex."
Write-Host ""
foreach ($worktree in $worktrees) {
    Write-Host "cd $($worktree.Path)"
    Write-Host "codex"
    Write-Host ""
}
