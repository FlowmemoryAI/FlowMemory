param(
    [string]$InstallRoot = (Join-Path ([Environment]::GetFolderPath("UserProfile")) "FlowMemory"),
    [string]$RepoUrl = "https://github.com/FlowmemoryAI/FlowMemory.git",
    [string]$Branch = "main",
    [switch]$SkipToolInstall,
    [switch]$SkipRepoSetup,
    [switch]$SkipSmoke,
    [switch]$NoServers,
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[ok] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[warn] $Message" -ForegroundColor Yellow
}

function Invoke-Checked {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList
    )

    Write-Host "> $FilePath $($ArgumentList -join ' ')" -ForegroundColor DarkGray
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($ArgumentList -join ' ')"
    }
}

function Add-UserPathEntry {
    param([string]$PathToAdd)

    $expanded = [Environment]::ExpandEnvironmentVariables($PathToAdd)
    if (-not (Test-Path -LiteralPath $expanded)) {
        return
    }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ([string]::IsNullOrWhiteSpace($userPath)) {
        $userPath = ""
    }

    $parts = $userPath.Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)
    $alreadyPresent = $false
    foreach ($part in $parts) {
        if ($part.TrimEnd("\") -ieq $expanded.TrimEnd("\")) {
            $alreadyPresent = $true
            break
        }
    }

    if (-not $alreadyPresent) {
        $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $expanded } else { "$userPath;$expanded" }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    }
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $extras = @(
        (Join-Path $env:ProgramFiles "Git\cmd"),
        (Join-Path $env:ProgramFiles "Git\bin"),
        (Join-Path $env:ProgramFiles "nodejs"),
        (Join-Path $env:USERPROFILE ".cargo\bin"),
        (Join-Path $env:USERPROFILE ".foundry\bin"),
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python312"),
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python312\Scripts")
    )

    $env:Path = (@($machinePath, $userPath) + $extras | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    }) -join ";"
}

function Test-Tool {
    param([string]$Command)
    Refresh-Path
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-Python {
    Refresh-Path
    if (Get-Command py -ErrorAction SilentlyContinue) {
        & py -3 --version *> $null
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
    }

    if (Get-Command python -ErrorAction SilentlyContinue) {
        & python --version *> $null
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
    }

    return $false
}

function Install-WingetPackage {
    param(
        [string]$DisplayName,
        [string]$Command,
        [string]$PackageId
    )

    if (Test-Tool $Command) {
        Write-Ok "$DisplayName is already installed"
        return
    }

    if ($SkipToolInstall) {
        Write-Warn "$DisplayName is missing, and -SkipToolInstall was set"
        return
    }

    Write-Step "Install $DisplayName"
    Invoke-Checked "winget" @(
        "install",
        "--id",
        $PackageId,
        "--exact",
        "--source",
        "winget",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--silent"
    )
    Refresh-Path

    if (-not (Test-Tool $Command)) {
        throw "$DisplayName was installed, but '$Command' is not available in this PowerShell session. Close PowerShell, open it again, and rerun this installer."
    }

    Write-Ok "$DisplayName installed"
}

function Install-Python {
    if (Test-Python) {
        Write-Ok "Python 3 is already installed"
        return
    }

    if ($SkipToolInstall) {
        Write-Warn "Python 3 is missing, and -SkipToolInstall was set"
        return
    }

    Write-Step "Install Python 3"
    Invoke-Checked "winget" @(
        "install",
        "--id",
        "Python.Python.3.12",
        "--exact",
        "--source",
        "winget",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--silent"
    )
    Refresh-Path

    if (-not (Test-Python)) {
        throw "Python 3 was installed, but it is not available in this PowerShell session. Close PowerShell, open it again, and rerun this installer."
    }

    Write-Ok "Python 3 installed"
}

function Install-Rust {
    if ((Test-Tool "cargo") -and (Test-Tool "rustc")) {
        Write-Ok "Rust and Cargo are already installed"
        return
    }

    if ($SkipToolInstall) {
        Write-Warn "Rust/Cargo is missing, and -SkipToolInstall was set"
        return
    }

    Write-Step "Install Rust toolchain"
    Invoke-Checked "winget" @(
        "install",
        "--id",
        "Rustlang.Rustup",
        "--exact",
        "--source",
        "winget",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--silent"
    )
    Add-UserPathEntry (Join-Path $env:USERPROFILE ".cargo\bin")
    Refresh-Path

    if (Test-Tool "rustup") {
        Invoke-Checked "rustup" @("default", "stable")
    }

    if (-not ((Test-Tool "cargo") -and (Test-Tool "rustc"))) {
        throw "Rust was installed, but Cargo/Rustc are not available in this PowerShell session. Close PowerShell, open it again, and rerun this installer."
    }

    Write-Ok "Rust and Cargo installed"
}

function Get-GitBash {
    Refresh-Path

    $programFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86")
    $candidates = @(
        (Join-Path $env:ProgramFiles "Git\bin\bash.exe"),
        (Join-Path $env:ProgramFiles "Git\usr\bin\bash.exe")
    )

    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        $candidates += @(
            (Join-Path $programFilesX86 "Git\bin\bash.exe"),
            (Join-Path $programFilesX86 "Git\usr\bin\bash.exe")
        )
    }

    $bashCommand = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($bashCommand) {
        $candidates += $bashCommand.Source
    }

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    return $null
}

function Install-Foundry {
    if (Test-Tool "forge") {
        Write-Ok "Foundry is already installed"
        return
    }

    if ($SkipToolInstall) {
        Write-Warn "Foundry is missing, and -SkipToolInstall was set"
        return
    }

    $bash = Get-GitBash
    if ([string]::IsNullOrWhiteSpace($bash)) {
        throw "Git Bash is required to install Foundry on Windows. Rerun this installer so Git can be installed first."
    }

    Write-Step "Install Foundry"
    Write-Host "Foundry's Windows installer runs through Git Bash, so this step uses Git Bash automatically."
    Invoke-Checked $bash @("-lc", "curl -L https://foundry.paradigm.xyz | bash")
    Invoke-Checked $bash @("-lc", 'export PATH="$HOME/.foundry/bin:$PATH"; foundryup')

    Add-UserPathEntry (Join-Path $env:USERPROFILE ".foundry\bin")
    Refresh-Path

    if (-not (Test-Tool "forge")) {
        throw "Foundry installed, but 'forge' is not available in this PowerShell session. Close PowerShell, open it again, and rerun this installer."
    }

    Write-Ok "Foundry installed"
}

function Show-ToolStatus {
    Write-Step "Tool status"

    $tools = @(
        @{ Name = "winget"; Available = (Test-Tool "winget") },
        @{ Name = "git"; Available = (Test-Tool "git") },
        @{ Name = "node"; Available = (Test-Tool "node") },
        @{ Name = "npm"; Available = (Test-Tool "npm") },
        @{ Name = "cargo"; Available = (Test-Tool "cargo") },
        @{ Name = "rustc"; Available = (Test-Tool "rustc") },
        @{ Name = "forge"; Available = (Test-Tool "forge") },
        @{ Name = "python3"; Available = (Test-Python) }
    )

    $missing = @()
    foreach ($tool in $tools) {
        if ($tool.Available) {
            Write-Ok $tool.Name
        } else {
            Write-Warn $tool.Name
            $missing += $tool.Name
        }
    }

    return $missing
}

function Install-Tools {
    Write-Step "Prepare Windows tools"
    if ($SkipToolInstall) {
        Write-Warn "Skipping tool installation because -SkipToolInstall was set"
        return
    }

    if (-not (Test-Tool "winget")) {
        throw "winget is missing. Install or update 'App Installer' from the Microsoft Store, then rerun this installer."
    }

    Invoke-Checked "winget" @("source", "update")
    Install-WingetPackage -DisplayName "Git for Windows" -Command "git" -PackageId "Git.Git"
    Install-WingetPackage -DisplayName "Node.js LTS" -Command "node" -PackageId "OpenJS.NodeJS.LTS"

    if (-not (Test-Tool "npm")) {
        throw "Node.js is installed, but npm is missing. Close PowerShell, open it again, and rerun this installer."
    }

    Install-Python
    Install-Rust
    Install-Foundry
}

function Get-RepoDirectory {
    $localSetup = Join-Path $PSScriptRoot "START_FLOWCHAIN_LOCAL.ps1"
    $localGit = Join-Path $PSScriptRoot ".git"
    if ((Test-Path -LiteralPath $localSetup) -and (Test-Path -LiteralPath $localGit)) {
        Write-Ok "Using current repository at $PSScriptRoot"
        return $PSScriptRoot
    }

    $repoDir = Join-Path $InstallRoot "FlowMemory"
    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null

    if (Test-Path -LiteralPath (Join-Path $repoDir ".git")) {
        Write-Step "Update existing FlowMemory checkout"
        Invoke-Checked "git" @("-C", $repoDir, "fetch", "origin")
        Invoke-Checked "git" @("-C", $repoDir, "checkout", $Branch)
        Invoke-Checked "git" @("-C", $repoDir, "pull", "--ff-only", "origin", $Branch)
        return $repoDir
    }

    if (Test-Path -LiteralPath $repoDir) {
        $entries = Get-ChildItem -LiteralPath $repoDir -Force -ErrorAction SilentlyContinue
        if ($entries.Count -gt 0) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $repoDir = Join-Path $InstallRoot "FlowMemory-$timestamp"
            Write-Warn "Existing non-git folder found. Cloning into $repoDir instead."
        }
    }

    Write-Step "Clone FlowMemory"
    Invoke-Checked "git" @("clone", "--branch", $Branch, $RepoUrl, $repoDir)
    return $repoDir
}

function Run-RepoSetup {
    param([string]$RepoDir)

    if ($SkipRepoSetup) {
        Write-Warn "Skipping repo setup because -SkipRepoSetup was set"
        return
    }

    $setupScript = Join-Path $RepoDir "START_FLOWCHAIN_LOCAL.ps1"
    if (-not (Test-Path -LiteralPath $setupScript)) {
        throw "Expected setup script not found: $setupScript"
    }

    Write-Step "Run FlowChain local setup"
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $setupScript
    )

    if ($SkipSmoke) {
        $args += "-SkipSmoke"
    }

    if ($NoServers) {
        $args += "-NoServers"
    }

    Invoke-Checked "powershell" $args
}

Write-Host "FlowChain beginner Windows installer" -ForegroundColor Cyan
Write-Host "This installs local developer tools, clones FlowMemory, and starts the local/private test package."
Write-Host "It does not install production validator software, deploy mainnet contracts, or use real funds."

if (-not $SkipToolInstall) {
    Write-Host ""
    Write-Host "Windows may ask for permission while installing tools. Click Yes if prompted." -ForegroundColor Yellow
}

Refresh-Path

if ($CheckOnly) {
    $missingTools = @(Show-ToolStatus)
    if ($missingTools.Count -gt 0) {
        throw "Missing tools: $($missingTools -join ', ')"
    }
    exit 0
}

Install-Tools
$missingAfterInstall = @(Show-ToolStatus)
if ($missingAfterInstall.Count -gt 0) {
    throw "Missing tools after install attempt: $($missingAfterInstall -join ', ')"
}

$repoDirectory = Get-RepoDirectory
Run-RepoSetup -RepoDir $repoDirectory

Write-Host ""
Write-Host "FlowChain local/private setup is ready." -ForegroundColor Green
Write-Host "Repository: $repoDirectory"
Write-Host "Dashboard: http://127.0.0.1:5173/"
Write-Host "Control plane: http://127.0.0.1:8675/"
Write-Host ""
Write-Host "To rerun later:"
Write-Host "cd `"$repoDirectory`""
Write-Host "powershell -ExecutionPolicy Bypass -File .\START_FLOWCHAIN_LOCAL.ps1 -SkipInstall"
