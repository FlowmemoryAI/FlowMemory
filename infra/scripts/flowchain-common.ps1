$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Add-FlowChainRustToolchainToPathIfNeeded {
    $cargo = Get-Command cargo -ErrorAction SilentlyContinue
    $rustc = Get-Command rustc -ErrorAction SilentlyContinue
    if ($cargo -and $rustc) {
        try {
            & cargo --version *> $null
            $cargoExitCode = $LASTEXITCODE
            & rustc --version *> $null
            $rustcExitCode = $LASTEXITCODE
            if ($cargoExitCode -eq 0 -and $rustcExitCode -eq 0) {
                return
            }
        }
        catch {
        }
    }

    $defaultCargoHome = Join-Path $env:USERPROFILE ".cargo"
    $configuredCargoHome = [Environment]::GetEnvironmentVariable("CARGO_HOME", "Process")
    if ([string]::IsNullOrWhiteSpace($configuredCargoHome) -or -not (Test-Path -LiteralPath (Join-Path $configuredCargoHome "bin\rustup.exe"))) {
        $env:CARGO_HOME = $defaultCargoHome
    }
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable("RUSTUP_HOME", "Process"))) {
        $env:RUSTUP_HOME = Join-Path $env:USERPROFILE ".rustup"
    }

    $rustupPath = Join-Path $env:USERPROFILE ".cargo\bin\rustup.exe"
    if (-not (Test-Path -LiteralPath $rustupPath)) {
        return
    }

    $toolchainCandidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:FLOWCHAIN_RUSTUP_TOOLCHAIN)) {
        $toolchainCandidates += $env:FLOWCHAIN_RUSTUP_TOOLCHAIN
    }
    $toolchainCandidates += @(
        "1.95.0-x86_64-pc-windows-gnu",
        "stable-x86_64-pc-windows-gnu",
        "stable-x86_64-pc-windows-msvc",
        ""
    )

    foreach ($toolchain in $toolchainCandidates) {
        try {
            if ([string]::IsNullOrWhiteSpace($toolchain)) {
                $cargoPath = (& $rustupPath which cargo 2>$null).Trim()
                $rustcPath = (& $rustupPath which rustc 2>$null).Trim()
            }
            else {
                $cargoPath = (& $rustupPath which cargo --toolchain $toolchain 2>$null).Trim()
                $rustcPath = (& $rustupPath which rustc --toolchain $toolchain 2>$null).Trim()
            }
        }
        catch {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($cargoPath) -or [string]::IsNullOrWhiteSpace($rustcPath)) {
            continue
        }
        if (-not (Test-Path -LiteralPath $cargoPath) -or -not (Test-Path -LiteralPath $rustcPath)) {
            continue
        }

        $toolchainBin = Split-Path -Parent $cargoPath
        $pathParts = @($env:PATH -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($toolchainBin -notin $pathParts) {
            $env:PATH = "$toolchainBin;$env:PATH"
        }
        if (-not [string]::IsNullOrWhiteSpace($toolchain)) {
            $env:FLOWCHAIN_RUSTUP_TOOLCHAIN = $toolchain
        }
        return
    }
}

Add-FlowChainRustToolchainToPathIfNeeded

function Get-FlowChainRepoRoot {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git was not found on PATH."
    }

    $root = (& git rev-parse --show-toplevel 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
        throw "Run this command from inside the FlowMemory Git repository."
    }

    return $root
}

function Set-FlowChainRepoRoot {
    $root = Get-FlowChainRepoRoot
    Set-Location -LiteralPath $root
    return $root
}

function Resolve-FlowChainPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $RepoRoot
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Assert-FlowChainPathInsideRepo {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $RepoRoot
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $prefix = $fullRoot + [System.IO.Path]::DirectorySeparatorChar

    if ($fullPath -ne $fullRoot -and -not $fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to use path outside repository: $fullPath"
    }

    return $fullPath
}

function Invoke-FlowChainCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Label,

        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [string[]] $ArgumentList = @()
    )

    Write-Host ""
    Write-Host "== $Label =="
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

function Reset-FlowChainDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $fullPath) {
        $lastRemoveError = $null
        for ($attempt = 1; $attempt -le 5; $attempt++) {
            try {
                Remove-Item -LiteralPath $fullPath -Recurse -Force -ErrorAction Stop
                break
            }
            catch {
                $lastRemoveError = $_
                Start-Sleep -Milliseconds (200 * $attempt)
            }
        }

        if (Test-Path -LiteralPath $fullPath) {
            $parent = Split-Path -Parent $fullPath
            $leaf = Split-Path -Leaf $fullPath
            $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssfffZ")
            $stalePath = Join-Path $parent "$leaf.stale-$PID-$stamp"
            try {
                Move-Item -LiteralPath $fullPath -Destination $stalePath -ErrorAction Stop
                Write-Host "Moved locked stale directory to: $stalePath"
            }
            catch {
                $removeMessage = if ($null -ne $lastRemoveError) { $lastRemoveError.Exception.Message } else { "not attempted" }
                throw "Unable to reset directory $fullPath. Last remove error: $removeMessage. Move error: $($_.Exception.Message)"
            }
        }
    }

    New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
    return $fullPath
}

function Join-FlowChainProcessArguments {
    param(
        [string[]] $ArgumentList = @()
    )

    return ($ArgumentList | ForEach-Object {
        if ($_.IndexOfAny([char[]] @(" ", "`t", '"')) -ge 0) {
            '"' + ($_.Replace('"', '\"')) + '"'
        }
        else {
            $_
        }
    }) -join " "
}

function Set-FlowChainCargoTargetDir {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,

        [string] $Purpose = "local"
    )

    $safePurpose = ($Purpose -replace '[^A-Za-z0-9_.-]', '-').Trim("-")
    if ([string]::IsNullOrWhiteSpace($safePurpose)) {
        $safePurpose = "local"
    }

    # Keep Cargo outputs away from the default crate target so a running local
    # node cannot lock flowmemory-devnet.exe and break setup on Windows.
    $targetDir = Join-Path $RepoRoot "devnet/local/cargo-target/$safePurpose-$PID"
    $tempDir = Join-Path $RepoRoot "devnet/local/tmp/$safePurpose-$PID"
    $env:CARGO_TARGET_DIR = $targetDir
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    $env:TEMP = $tempDir
    $env:TMP = $tempDir
    return $targetDir
}

function Write-FlowChainJson {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [object] $Value,

        [int] $Depth = 12
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    $body = ($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $lastWriteError = $null
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            [System.IO.File]::WriteAllText($Path, $body, $utf8NoBom)
            return
        }
        catch {
            $lastWriteError = $_
            Start-Sleep -Milliseconds (100 * $attempt)
        }
    }
    throw "Unable to write JSON file $Path. Last write error: $($lastWriteError.Exception.Message)"
}

function Assert-FlowChainNoSecretText {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text,

        [Parameter(Mandatory = $true)]
        [string] $Label
    )

    $patterns = @(
        "privateKey",
        "private_key",
        "seedPhrase",
        "seed phrase",
        "mnemonic",
        "rpcUrl",
        "rpc-url",
        "apiKey",
        "webhook",
        "BEGIN RSA PRIVATE KEY",
        "BEGIN OPENSSH PRIVATE KEY"
    )

    foreach ($pattern in $patterns) {
        if ($Text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            throw "Potential secret marker '$pattern' found in $Label."
        }
    }
}

function Assert-FlowChainNoSecretFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Cannot scan missing path: $Path"
    }

    $item = Get-Item -LiteralPath $Path
    $files = @()
    if ($item.PSIsContainer) {
        $files = Get-ChildItem -LiteralPath $Path -Recurse -File | Where-Object {
            $_.Extension -in @(".json", ".txt", ".md", ".env")
        }
    }
    else {
        $files = @($item)
    }

    foreach ($file in $files) {
        $text = Get-Content -Raw -LiteralPath $file.FullName
        Assert-FlowChainNoSecretText -Text $text -Label $file.FullName
    }
}

function New-FlowChainLocalOperator {
    param(
        [Parameter(Mandatory = $true)]
        [string] $OperatorPath,

        [switch] $Force
    )

    if ((Test-Path -LiteralPath $OperatorPath) -and -not $Force) {
        Write-Host "Local operator file already exists: $OperatorPath"
        return
    }

    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $hex = "0x" + (($bytes | ForEach-Object { $_.ToString("x2") }) -join "")
    $publicIdInput = [System.Text.Encoding]::UTF8.GetBytes("flowchain-local-operator:" + $hex)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $operatorId = "local-operator:" + (($sha.ComputeHash($publicIdInput) | ForEach-Object { $_.ToString("x2") }) -join "")

    $operator = [ordered]@{
        schema = "flowchain.local_operator.v0"
        operatorId = $operatorId
        keyKind = "local-dev-only"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        localPrivateKeyHex = $hex
        warning = "Generated for private/local second-computer validation only. Do not commit this file."
    }

    Write-FlowChainJson -Path $OperatorPath -Value $operator
    Write-Host "Wrote local-only operator file: $OperatorPath"
}
