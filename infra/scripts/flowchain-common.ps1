$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

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

function Set-FlowChainCargoTargetDir {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot
    )

    $targetDir = Join-Path $RepoRoot "crates/flowmemory-devnet/target"
    $env:CARGO_TARGET_DIR = $targetDir
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
    [System.IO.File]::WriteAllText($Path, $body, $utf8NoBom)
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
