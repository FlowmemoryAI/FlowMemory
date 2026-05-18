param(
    [string] $TokenPath = "devnet/local/owner-inputs/tester-write-token.local.txt",
    [string] $OwnerEnvFile = "devnet/local/owner-inputs/flowchain-owner.local.env",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/tester-write-token-setup-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/TESTER_WRITE_TOKEN_SETUP.md",
    [int] $MaxSendUnits = 10,
    [switch] $Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$tokenFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $TokenPath)
$ownerEnvFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OwnerEnvFile)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

function Get-TesterTokenRelativePath {
    param(
        [Parameter(Mandatory = $true)][string] $BasePath,
        [Parameter(Mandatory = $true)][string] $ChildPath
    )

    $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd("\", "/")
    $child = [System.IO.Path]::GetFullPath($ChildPath)
    $prefix = $base + [System.IO.Path]::DirectorySeparatorChar
    if (-not $child.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside repo."
    }
    return $child.Substring($prefix.Length) -replace '\\', '/'
}

function Test-TesterTokenGitIgnored {
    param([Parameter(Mandatory = $true)][string] $RelativePath)

    $ignoredOutput = @(& git -C $repoRoot check-ignore --quiet -- $RelativePath 2>&1)
    $ignoredExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
    return [ordered]@{
        ignored = $ignoredExitCode -eq 0
        exitCode = $ignoredExitCode
        outputLineCount = @($ignoredOutput).Count
    }
}

function New-TesterBearerToken {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return ([Convert]::ToBase64String($bytes)).TrimEnd("=").Replace("+", "-").Replace("/", "_")
}

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string] $Value)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join "")
}

function Set-OwnerEnvAssignment {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Lines,
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Value
    )

    $pattern = "^\s*$([System.Text.RegularExpressions.Regex]::Escape($Name))\s*="
    for ($index = 0; $index -lt $Lines.Count; $index++) {
        if ($Lines[$index] -match $pattern) {
            $Lines[$index] = "$Name=$Value"
            return
        }
    }
    [void] $Lines.Add("$Name=$Value")
}

function Get-TesterTokenSecretMarkerFindings {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Label
    )

    $findings = New-Object System.Collections.ArrayList
    foreach ($pattern in @(
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
        )) {
        if ($Text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            [void] $findings.Add([ordered]@{ label = $Label; marker = $pattern })
        }
    }
    return @($findings)
}

if ($MaxSendUnits -lt 1) {
    throw "MaxSendUnits must be positive."
}

$tokenRelativePath = Get-TesterTokenRelativePath -BasePath $repoRoot -ChildPath $tokenFullPath
$ownerEnvRelativePath = Get-TesterTokenRelativePath -BasePath $repoRoot -ChildPath $ownerEnvFullPath
$tokenIgnore = Test-TesterTokenGitIgnored -RelativePath $tokenRelativePath
$ownerEnvIgnore = Test-TesterTokenGitIgnored -RelativePath $ownerEnvRelativePath

if ($tokenIgnore.ignored -ne $true) {
    throw "Refusing to write tester token because token path is not git-ignored: $tokenRelativePath"
}
if ($ownerEnvIgnore.ignored -ne $true) {
    throw "Refusing to update owner env file because path is not git-ignored: $ownerEnvRelativePath"
}

$tokenCreated = $false
$tokenPreserved = $false
if ((Test-Path -LiteralPath $tokenFullPath) -and -not $Force.IsPresent) {
    $testerToken = (Get-Content -Raw -LiteralPath $tokenFullPath).Trim()
    $tokenPreserved = $true
}
else {
    $testerToken = New-TesterBearerToken
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $tokenFullPath) | Out-Null
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tokenFullPath, $testerToken + [Environment]::NewLine, $utf8NoBom)
    $tokenCreated = $true
}

if ([string]::IsNullOrWhiteSpace($testerToken) -or $testerToken.Length -lt 32) {
    throw "Tester token is missing or too short."
}

$tokenHash = Get-Sha256Hex -Value $testerToken
$ownerEnvLines = New-Object System.Collections.ArrayList
if (Test-Path -LiteralPath $ownerEnvFullPath) {
    foreach ($line in @(Get-Content -LiteralPath $ownerEnvFullPath)) {
        [void] $ownerEnvLines.Add("$line")
    }
}
else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ownerEnvFullPath) | Out-Null
    [void] $ownerEnvLines.Add("# FlowChain owner input file.")
    [void] $ownerEnvLines.Add("# Keep this local file ignored. Do not commit real values.")
    [void] $ownerEnvLines.Add("")
}

Set-OwnerEnvAssignment -Lines $ownerEnvLines -Name "FLOWCHAIN_TESTER_WRITE_ENABLED" -Value "true"
Set-OwnerEnvAssignment -Lines $ownerEnvLines -Name "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256" -Value $tokenHash
Set-OwnerEnvAssignment -Lines $ownerEnvLines -Name "FLOWCHAIN_TESTER_MAX_SEND_UNITS" -Value ([string]$MaxSendUnits)

$ownerEnvText = ($ownerEnvLines -join [Environment]::NewLine) + [Environment]::NewLine
$ownerEnvUtf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($ownerEnvFullPath, $ownerEnvText, $ownerEnvUtf8)

$ownerEnvReloaded = Get-Content -Raw -LiteralPath $ownerEnvFullPath
$tokenFileExists = Test-Path -LiteralPath $tokenFullPath
$ownerEnvFileExists = Test-Path -LiteralPath $ownerEnvFullPath
$ownerEnvHasTesterEnabled = $ownerEnvReloaded -match '(?m)^\s*FLOWCHAIN_TESTER_WRITE_ENABLED\s*=\s*true\s*$'
$ownerEnvHasTesterHash = $ownerEnvReloaded -match '(?m)^\s*FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256\s*=\s*[0-9a-f]{64}\s*$'
$ownerEnvHasTesterCap = $ownerEnvReloaded -match '(?m)^\s*FLOWCHAIN_TESTER_MAX_SEND_UNITS\s*=\s*[1-9][0-9]*\s*$'

$checks = [ordered]@{
    tokenPathGitIgnored = $tokenIgnore.ignored -eq $true
    ownerEnvPathGitIgnored = $ownerEnvIgnore.ignored -eq $true
    tokenFileExists = $tokenFileExists
    ownerEnvFileExists = $ownerEnvFileExists
    tokenLengthSufficient = $testerToken.Length -ge 32
    tokenHashLengthValid = $tokenHash.Length -eq 64
    ownerEnvTesterEnabledWritten = $ownerEnvHasTesterEnabled
    ownerEnvTesterHashWritten = $ownerEnvHasTesterHash
    ownerEnvTesterCapWritten = $ownerEnvHasTesterCap
    rawTokenPrintedFalse = $true
    tokenHashPrintedFalse = $true
    envValuesPrintedFalse = $true
    noSecrets = $true
    broadcastsFalse = $true
    secretMarkerFindingsEmpty = $true
}

$report = [ordered]@{
    schema = "flowchain.tester_write_token_setup_report.v0"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    status = "pending"
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    tokenCreated = $tokenCreated
    tokenPreserved = $tokenPreserved
    tokenPath = $tokenRelativePath
    ownerEnvFile = $ownerEnvRelativePath
    tokenHashLength = $tokenHash.Length
    maxSendUnitsConfigured = $true
    rawTokenPrinted = $false
    tokenHashPrinted = $false
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
    nextCommands = @(
        "npm run flowchain:owner-env:readiness -- -AllowBlocked",
        "npm run flowchain:tester:gateway:e2e",
        "npm run flowchain:external-tester:packet -- -AllowBlocked"
    )
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 12
$secretMarkerFindings = @(Get-TesterTokenSecretMarkerFindings -Text $preliminaryReportText -Label "tester write token setup report")
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $secretMarkerFindings.Count -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report["status"] = $status
$report["checks"] = $checks
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

$reportText = $report | ConvertTo-Json -Depth 12
Assert-FlowChainNoSecretText -Text $reportText -Label "tester write token setup report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 12

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Tester Write Token Setup")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("A tester write bearer token exists in ignored local storage, and the ignored owner env file has the tester write fields. The committed report and this markdown do not contain the raw token or token digest.")
$markdownLines.Add("")
$markdownLines.Add("Token file: ``$tokenRelativePath``")
$markdownLines.Add("Owner env file: ``$ownerEnvRelativePath``")
$markdownLines.Add("Token created: $tokenCreated")
$markdownLines.Add("Existing token preserved: $tokenPreserved")
$markdownLines.Add("")
$markdownLines.Add("## Next Commands")
$markdownLines.Add("")
foreach ($command in @($report.nextCommands)) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
$markdownLines.Add("Share the raw token out-of-band only with approved testers after the public deployment contract marks the packet shareable. Do not paste it into chat, GitHub, or committed files.")

$markdownText = ($markdownLines -join [Environment]::NewLine) + [Environment]::NewLine
Assert-FlowChainNoSecretText -Text $markdownText -Label "tester write token setup markdown"
$markdownParent = Split-Path -Parent $markdownFullPath
if (-not [string]::IsNullOrWhiteSpace($markdownParent)) {
    New-Item -ItemType Directory -Force -Path $markdownParent | Out-Null
}
$markdownUtf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($markdownFullPath, $markdownText, $markdownUtf8)

Write-Host "FlowChain tester write token setup status: $status"
Write-Host "Token file: $tokenRelativePath"
Write-Host "Owner env file: $ownerEnvRelativePath"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    exit 1
}
