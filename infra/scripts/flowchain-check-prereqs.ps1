param(
    [switch] $Strict
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot

function Add-Check {
    param(
        [System.Collections.ArrayList] $Checks,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Command,

        [Parameter(Mandatory = $true)]
        [bool] $Required,

        [string[]] $VersionArgs = @("--version")
    )

    $found = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $found) {
        [void] $Checks.Add([pscustomobject]@{
            Name = $Name
            Required = $Required
            Status = "missing"
            Version = ""
            NextStep = "Install $Name and reopen PowerShell."
        })
        return
    }

    $version = ""
    try {
        $version = (& $Command @VersionArgs 2>$null | Select-Object -First 1)
    }
    catch {
        $version = "found"
    }

    [void] $Checks.Add([pscustomobject]@{
        Name = $Name
        Required = $Required
        Status = "ok"
        Version = $version
        NextStep = ""
    })
}

function Find-MsvcBuildTools {
    $linkCommand = Get-Command "link.exe" -ErrorAction SilentlyContinue
    if ($linkCommand) {
        return [pscustomobject]@{
            Found = $true
            Version = "link.exe at $($linkCommand.Source)"
        }
    }

    $programFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86")
    $vswhere = if ([string]::IsNullOrWhiteSpace($programFilesX86)) {
        $null
    } else {
        Join-Path $programFilesX86 "Microsoft Visual Studio\Installer\vswhere.exe"
    }

    if (-not [string]::IsNullOrWhiteSpace($vswhere) -and (Test-Path -LiteralPath $vswhere)) {
        $installPath = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null | Select-Object -First 1)
        if (-not [string]::IsNullOrWhiteSpace($installPath)) {
            return [pscustomobject]@{
                Found = $true
                Version = "Visual C++ tools at $installPath"
            }
        }
    }

    $candidateRoots = @(
        (Join-Path $env:ProgramFiles "Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC"),
        (Join-Path $env:ProgramFiles "Microsoft Visual Studio\2022\Community\VC\Tools\MSVC")
    )
    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        $candidateRoots += Join-Path $programFilesX86 "Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC"
    }

    foreach ($root in $candidateRoots) {
        if (Test-Path -LiteralPath $root) {
            return [pscustomobject]@{
                Found = $true
                Version = "Visual C++ tools at $root"
            }
        }
    }

    return [pscustomobject]@{
        Found = $false
        Version = ""
    }
}

function Add-MsvcCheck {
    param([System.Collections.ArrayList] $Checks)

    $msvc = Find-MsvcBuildTools
    [void] $Checks.Add([pscustomobject]@{
        Name = "MSVC C++ build tools"
        Required = $true
        Status = if ($msvc.Found) { "ok" } else { "missing" }
        Version = $msvc.Version
        NextStep = if ($msvc.Found) {
            ""
        } else {
            "Install Visual Studio Build Tools 2022 with the C++ workload, then reopen PowerShell."
        }
    })
}

$checks = New-Object System.Collections.ArrayList
Add-Check -Checks $checks -Name "Git" -Command "git" -Required $true
Add-Check -Checks $checks -Name "Node.js" -Command "node" -Required $true
Add-Check -Checks $checks -Name "npm" -Command "npm" -Required $true
Add-Check -Checks $checks -Name "Rust cargo" -Command "cargo" -Required $true
Add-Check -Checks $checks -Name "Rust compiler" -Command "rustc" -Required $true
Add-MsvcCheck -Checks $checks
Add-Check -Checks $checks -Name "Foundry forge" -Command "forge" -Required $true
Add-Check -Checks $checks -Name "Python" -Command "python" -Required:$Strict

Write-Host ""
Write-Host "== FlowChain Prerequisites =="
$checks | Format-Table -AutoSize

$requiredMissing = @($checks | Where-Object { $_.Required -and $_.Status -ne "ok" })
if ($requiredMissing.Count -gt 0) {
    throw "Missing required prerequisites: $($requiredMissing.Name -join ', ')"
}

Write-Host ""
Write-Host "== Dependency Install State =="
$dependencyRows = @(
    [pscustomobject]@{
        Area = "root npm workspaces"
        Path = "node_modules"
        Status = if (Test-Path -LiteralPath (Join-Path $repoRoot "node_modules")) { "installed" } else { "missing" }
        InstallCommand = "npm install"
    },
    [pscustomobject]@{
        Area = "dashboard workbench"
        Path = "apps/dashboard/node_modules"
        Status = if (Test-Path -LiteralPath (Join-Path $repoRoot "apps/dashboard/node_modules")) { "installed" } else { "missing" }
        InstallCommand = "npm install --prefix apps/dashboard"
    },
    [pscustomobject]@{
        Area = "crypto package"
        Path = "crypto/node_modules"
        Status = if (Test-Path -LiteralPath (Join-Path $repoRoot "crypto/node_modules")) { "installed" } else { "missing" }
        InstallCommand = "npm install --prefix crypto"
    }
)
$dependencyRows | Format-Table -AutoSize

$missingDeps = @($dependencyRows | Where-Object { $_.Status -ne "installed" })
if ($Strict -and $missingDeps.Count -gt 0) {
    throw "Missing installed dependencies. Run: $($missingDeps.InstallCommand -join '; ')"
}

Write-Host ""
Write-Host "Next command on a clean second computer:"
Write-Host "npm run flowchain:init"
