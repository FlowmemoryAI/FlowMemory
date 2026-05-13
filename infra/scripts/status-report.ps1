$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Title
    )

    Write-Host ""
    Write-Host "== $Title =="
}

function Get-WorktreePaths {
    $lines = & git worktree list --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list git worktrees."
    }

    foreach ($line in $lines) {
        if ($line -like "worktree *") {
            $line.Substring("worktree ".Length)
        }
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git was not found on PATH."
}

$repoRoot = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
    throw "Run this script inside a Git repository."
}

Set-Location -LiteralPath $repoRoot

Write-Section "Repository"
Write-Host "Root: $repoRoot"
& git status --short --branch

Write-Section "Worktrees"
$dirtyWorktrees = @()
foreach ($path in Get-WorktreePaths) {
    Write-Host ""
    Write-Host $path
    $status = & git -C $path status --short --branch
    $status | ForEach-Object { Write-Host "  $_" }

    $dirty = $status | Where-Object {
        $_ -and
        ($_ -notlike "## *")
    }

    if ($dirty) {
        $dirtyWorktrees += $path
    }
}

Write-Section "Dirty Worktrees"
if ($dirtyWorktrees.Count -eq 0) {
    Write-Host "None"
}
else {
    $dirtyWorktrees | ForEach-Object { Write-Host $_ }
}

if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Section "Open Pull Requests"
    & gh pr list --repo FlowmemoryAI/FlowMemory --state open --limit 50

    Write-Section "Open Issues"
    & gh issue list --repo FlowmemoryAI/FlowMemory --state open --limit 80
}
else {
    Write-Section "GitHub"
    Write-Host "gh CLI not found; skipping PR and issue summaries."
}
