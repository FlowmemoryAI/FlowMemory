param(
    [ValidateSet("contracts", "indexer", "crypto", "chain", "dashboard", "hardware", "research", "review")]
    [string] $Agent,

    [string] $Goal,

    [string] $GoalFile,

    [switch] $List,

    [switch] $DryRun,

    [switch] $NoEnter
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$flowMemoryRoot = if ([string]::IsNullOrWhiteSpace($env:FLOWMEMORY_WORKTREE_ROOT)) { Join-Path $HOME "FlowMemory" } else { $env:FLOWMEMORY_WORKTREE_ROOT }

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class FlowMemoryWindowTools {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    public static List<Tuple<IntPtr, string>> GetVisibleWindows() {
        var windows = new List<Tuple<IntPtr, string>>();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            if (IsWindowVisible(hWnd)) {
                var sb = new StringBuilder(512);
                GetWindowText(hWnd, sb, sb.Capacity);
                var title = sb.ToString();
                if (!String.IsNullOrWhiteSpace(title)) {
                    windows.Add(Tuple.Create(hWnd, title));
                }
            }
            return true;
        }, IntPtr.Zero);
        return windows;
    }
}
"@

$agents = @{
    contracts = @{
        TitlePattern = "flowmemory-contracts"
        Worktree = "$flowMemoryRoot\flowmemory-contracts"
    }
    indexer = @{
        TitlePattern = "flowmemory-indexer"
        Worktree = "$flowMemoryRoot\flowmemory-indexer"
    }
    crypto = @{
        TitlePattern = "flowmemory-crypto"
        Worktree = "$flowMemoryRoot\flowmemory-crypto"
    }
    chain = @{
        TitlePattern = "flowmemory-chain"
        Worktree = "$flowMemoryRoot\flowmemory-chain"
    }
    dashboard = @{
        TitlePattern = "flowmemory-dashboard"
        Worktree = "$flowMemoryRoot\flowmemory-dashboard"
    }
    hardware = @{
        TitlePattern = "flowmemory-hardware"
        Worktree = "$flowMemoryRoot\flowmemory-hardware"
    }
    research = @{
        TitlePattern = "flowmemory-research"
        Worktree = "$flowMemoryRoot\flowmemory-research"
    }
    review = @{
        TitlePattern = "flowmemory-review"
        Worktree = "$flowMemoryRoot\flowmemory-review"
    }
}

function Get-AgentWindow {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Pattern
    )

    $windows = [FlowMemoryWindowTools]::GetVisibleWindows()
    $matches = @($windows | Where-Object { $_.Item2 -like "*$Pattern*" })

    if ($matches.Count -eq 0) {
        throw "No visible terminal window matched title pattern '$Pattern'. Use -List to inspect visible windows."
    }

    if ($matches.Count -gt 1) {
        $titles = ($matches | ForEach-Object { $_.Item2 }) -join "; "
        throw "More than one visible terminal matched '$Pattern': $titles"
    }

    return $matches[0]
}

function Get-VisibleAgentWindows {
    [FlowMemoryWindowTools]::GetVisibleWindows() |
        Where-Object { $_.Item2 -match "FlowMemory|flowmemory|Codex|codex|PowerShell" } |
        Sort-Object { $_.Item2 } |
        ForEach-Object {
            [pscustomobject]@{
                Handle = $_.Item1
                Title = $_.Item2
            }
        }
}

if ($List) {
    Get-VisibleAgentWindows | Format-Table -AutoSize
    exit 0
}

if (-not $Agent) {
    throw "Specify -Agent or use -List."
}

if ([string]::IsNullOrWhiteSpace($Goal) -and [string]::IsNullOrWhiteSpace($GoalFile)) {
    throw "Specify -Goal or -GoalFile."
}

if (-not $agents.ContainsKey($Agent)) {
    throw "Unknown agent '$Agent'."
}

$agentConfig = $agents[$Agent]
$window = Get-AgentWindow -Pattern $agentConfig.TitlePattern

$dispatchRoot = "$flowMemoryRoot\agent-dispatch"
New-Item -ItemType Directory -Force -Path $dispatchRoot | Out-Null

$goalText = $Goal
if (-not [string]::IsNullOrWhiteSpace($GoalFile)) {
    $goalText = Get-Content -LiteralPath $GoalFile -Raw
}

$goalPath = Join-Path $dispatchRoot "$Agent-goal.md"
$payload = @"
# FlowMemory $Agent Agent Goal

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")
Worktree: $($agentConfig.Worktree)
Window title: $($window.Item2)

$goalText
"@

Set-Content -LiteralPath $goalPath -Value $payload -Encoding UTF8

$oneLineGoal = "/goal Read the goal file at $goalPath and execute it from your current FlowMemory worktree. First restate the objective, allowed scope, forbidden scope, branch, and current git status. Then proceed only within the goal."

Write-Host "Agent: $Agent"
Write-Host "Window: $($window.Item2)"
Write-Host "Goal file: $goalPath"
Write-Host "Prompt:"
Write-Host $oneLineGoal

if ($DryRun) {
    Write-Host "Dry run only. Nothing was pasted."
    exit 0
}

Set-Clipboard -Value $oneLineGoal
[FlowMemoryWindowTools]::SetForegroundWindow($window.Item1) | Out-Null
Start-Sleep -Milliseconds 350

$shell = New-Object -ComObject WScript.Shell
$shell.SendKeys("^v")
Start-Sleep -Milliseconds 150

if (-not $NoEnter) {
    $shell.SendKeys("{ENTER}")
}

Write-Host "Dispatched goal to $Agent."
