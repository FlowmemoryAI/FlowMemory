param(
    [string] $OwnerEnvFile = "devnet/local/owner-inputs/flowchain-owner.local.env",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OWNER_ENV_READINESS.md",
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$ownerEnvFullPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OwnerEnvFile
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

$knownOwnerInputs = @(
    "FLOWCHAIN_RPC_PUBLIC_URL",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_RPC_TLS_TERMINATED",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH",
    "FLOWCHAIN_TESTER_WRITE_ENABLED",
    "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
    "FLOWCHAIN_TESTER_MAX_SEND_UNITS",
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
    "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
    "FLOWCHAIN_BASE8453_FROM_BLOCK",
    "FLOWCHAIN_BASE8453_TO_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS"
)

$paths = [ordered]@{
    ownerInputs = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
    liveInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json"
    publicDeploymentContract = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
}

function Get-OwnerEnvReadinessRelativePath {
    param(
        [Parameter(Mandatory = $true)][string] $BasePath,
        [Parameter(Mandatory = $true)][string] $ChildPath
    )

    $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd("\", "/")
    $child = [System.IO.Path]::GetFullPath($ChildPath)
    $prefix = $base + [System.IO.Path]::DirectorySeparatorChar
    if ($child -eq $base) {
        return ""
    }
    if ($child.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $child.Substring($prefix.Length) -replace '\\', '/'
    }
    return $null
}

function Get-OwnerEnvReadinessProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

function ConvertTo-OwnerEnvReadinessSafeLine {
    param([AllowNull()][object] $Line)

    $text = "$Line"
    foreach ($name in $knownOwnerInputs) {
        $escapedName = [System.Text.RegularExpressions.Regex]::Escape($name)
        $text = [System.Text.RegularExpressions.Regex]::Replace(
            $text,
            "(?i)($escapedName\s*[:=]\s*)([^\s,;]+)",
            {
                param([System.Text.RegularExpressions.Match] $Match)
                return "$($Match.Groups[1].Value)<redacted>"
            }
        )
    }
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "https?://[^\s,)]+", "<redacted-url>")
    return $text
}

function Get-OwnerEnvReportStatus {
    param([AllowNull()][object] $Report)

    if ($null -eq $Report) {
        return "missing"
    }
    if ($Report.PSObject.Properties.Name -contains "status") {
        return "$($Report.status)"
    }
    return "unknown"
}

function Add-UniqueOwnerEnvName {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [AllowNull()][object] $Value
    )

    $name = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($name) -and -not $Target.Contains($name)) {
        [void] $Target.Add($name)
    }
}

function Invoke-OwnerEnvReadinessStep {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Command,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList,
        [Parameter(Mandatory = $true)][string] $ExpectedReportPath
    )

    Write-Host ""
    Write-Host "== $Name =="
    Write-Host $Command

    $startedAt = (Get-Date).ToUniversalTime().ToString("o")
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = (& powershell @ArgumentList 2>&1) | ForEach-Object { ConvertTo-OwnerEnvReadinessSafeLine -Line $_ }
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) {
            $exitCode = 0
        }
    }
    catch {
        $output = @(ConvertTo-OwnerEnvReadinessSafeLine -Line $_.Exception.Message)
        $exitCode = 1
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $childReport = Read-FlowChainJsonIfExists -Path $ExpectedReportPath
    $childStatus = Get-OwnerEnvReportStatus -Report $childReport
    $status = if ($childStatus -in @("passed", "blocked", "failed")) {
        $childStatus
    }
    elseif ($exitCode -eq 0) {
        "failed"
    }
    else {
        "failed"
    }

    Write-Host "$($status.ToUpperInvariant()): $Name"

    return [ordered]@{
        name = $Name
        command = $Command
        startedAt = $startedAt
        finishedAt = (Get-Date).ToUniversalTime().ToString("o")
        exitCode = [int] $exitCode
        status = $status
        reportPath = $ExpectedReportPath
        outputLineCount = @($output).Count
        outputRedactedTail = @($output | Select-Object -Last 80)
    }
}

$ownerEnvRelativePath = Get-OwnerEnvReadinessRelativePath -BasePath $repoRoot -ChildPath $ownerEnvFullPath
$ownerEnvInsideRepo = $null -ne $ownerEnvRelativePath
$ownerEnvExists = Test-Path -LiteralPath $ownerEnvFullPath
$ownerEnvIsFile = $false
if ($ownerEnvExists) {
    try {
        $ownerEnvIsFile = -not (Get-Item -LiteralPath $ownerEnvFullPath).PSIsContainer
    }
    catch {
        $ownerEnvIsFile = $false
    }
}

$gitCheckExitCode = $null
$gitCheckOutput = @()
$ownerEnvGitIgnored = $null
if ($ownerEnvInsideRepo -and -not [string]::IsNullOrWhiteSpace($ownerEnvRelativePath)) {
    $gitCheckOutput = @(& git -C $repoRoot check-ignore --quiet -- $ownerEnvRelativePath 2>&1 | ForEach-Object { ConvertTo-OwnerEnvReadinessSafeLine -Line $_ })
    $gitCheckExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
    $ownerEnvGitIgnored = $gitCheckExitCode -eq 0
}
elseif ($ownerEnvInsideRepo) {
    $gitCheckExitCode = 1
    $ownerEnvGitIgnored = $false
}

$pathProblems = New-Object System.Collections.ArrayList
if (-not $ownerEnvExists) {
    [void] $pathProblems.Add("owner env file is missing")
}
elseif (-not $ownerEnvIsFile) {
    [void] $pathProblems.Add("owner env path is not a file")
}
if ($ownerEnvInsideRepo -and $ownerEnvGitIgnored -ne $true) {
    [void] $pathProblems.Add("owner env file is inside the repo but is not git-ignored")
}

$pathSafeForChildUse = $ownerEnvExists -and $ownerEnvIsFile -and ((-not $ownerEnvInsideRepo) -or $ownerEnvGitIgnored -eq $true)
$steps = New-Object System.Collections.ArrayList
$previousOwnerEnvFile = [Environment]::GetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", "Process")
try {
    if ($pathSafeForChildUse) {
        [Environment]::SetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", $ownerEnvFullPath, "Process")

        [void] $steps.Add((Invoke-OwnerEnvReadinessStep `
            -Name "Owner input contract from local env file" `
            -Command "npm run flowchain:owner-inputs -- -AllowBlocked" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-inputs.ps1"), "-AllowBlocked", "-ReportPath", $paths.ownerInputs) `
            -ExpectedReportPath $paths.ownerInputs))

        [void] $steps.Add((Invoke-OwnerEnvReadinessStep `
            -Name "Live infrastructure with local env file" `
            -Command "npm run flowchain:live-infra:check -- -AllowBlocked" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-infra-check.ps1"), "-AllowBlocked") `
            -ExpectedReportPath $paths.liveInfra))

        [void] $steps.Add((Invoke-OwnerEnvReadinessStep `
            -Name "Public deployment contract with local env file" `
            -Command "npm run flowchain:public-deployment:contract -- -AllowBlocked -NoRefresh" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-deployment-contract.ps1"), "-AllowBlocked", "-NoRefresh") `
            -ExpectedReportPath $paths.publicDeploymentContract))
    }
}
finally {
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", $previousOwnerEnvFile, "Process")
}

$ownerInputsReport = Read-FlowChainJsonIfExists -Path $paths.ownerInputs
$liveInfraReport = Read-FlowChainJsonIfExists -Path $paths.liveInfra
$deploymentContractReport = Read-FlowChainJsonIfExists -Path $paths.publicDeploymentContract

$reportStatuses = [ordered]@{
    ownerInputs = Get-OwnerEnvReportStatus -Report $ownerInputsReport
    liveInfra = Get-OwnerEnvReportStatus -Report $liveInfraReport
    publicDeploymentContract = Get-OwnerEnvReportStatus -Report $deploymentContractReport
}

$missingEnvNames = New-Object System.Collections.ArrayList
$invalidEnvNames = New-Object System.Collections.ArrayList
foreach ($report in @($ownerInputsReport, $liveInfraReport, $deploymentContractReport)) {
    foreach ($name in @((Get-OwnerEnvReadinessProp -Object $report -Name "missingEnvNames" -Default @()))) {
        Add-UniqueOwnerEnvName -Target $missingEnvNames -Value $name
    }
    foreach ($name in @((Get-OwnerEnvReadinessProp -Object $report -Name "invalidEnvNames" -Default @()))) {
        Add-UniqueOwnerEnvName -Target $invalidEnvNames -Value $name
    }
}

$unknownMissingEnvNames = @($missingEnvNames | Where-Object { $_ -notin $knownOwnerInputs })
$failedSteps = @($steps | Where-Object { "$($_.status)" -eq "failed" -or [int] $_.exitCode -ne 0 })
$allReportsPassed = $reportStatuses.ownerInputs -eq "passed" -and $reportStatuses.liveInfra -eq "passed" -and $reportStatuses.publicDeploymentContract -eq "passed"
$blockedOnlyOnKnownOwnerInputs = $pathSafeForChildUse `
    -and $failedSteps.Count -eq 0 `
    -and @($invalidEnvNames).Count -eq 0 `
    -and @($unknownMissingEnvNames).Count -eq 0 `
    -and @($missingEnvNames).Count -gt 0

$status = if (-not $pathSafeForChildUse -or $failedSteps.Count -gt 0 -or @($invalidEnvNames).Count -gt 0 -or @($unknownMissingEnvNames).Count -gt 0) {
    "failed"
}
elseif ($allReportsPassed) {
    "passed"
}
else {
    "blocked"
}

$report = [ordered]@{
    schema = "flowchain.owner_env_readiness_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    repoPath = $repoRoot
    ownerEnvFile = [ordered]@{
        configuredByRunner = $true
        path = $ownerEnvFullPath
        relativePath = $ownerEnvRelativePath
        insideRepo = $ownerEnvInsideRepo
        exists = $ownerEnvExists
        isFile = $ownerEnvIsFile
        gitIgnored = $ownerEnvGitIgnored
        gitCheckExitCode = $gitCheckExitCode
        gitCheckOutputRedacted = @($gitCheckOutput)
        problems = @($pathProblems)
    }
    readiness = [ordered]@{
        ownerInputsReady = (Get-OwnerEnvReadinessProp -Object $ownerInputsReport -Name "ownerInputReady" -Default $false)
        liveInfraReady = $reportStatuses.liveInfra -eq "passed"
        publicDeploymentContractReady = $reportStatuses.publicDeploymentContract -eq "passed"
        blockedOnlyOnKnownExternalOwnerInputs = $blockedOnlyOnKnownOwnerInputs
    }
    reportStatuses = $reportStatuses
    missingEnvNames = @($missingEnvNames)
    invalidEnvNames = @($invalidEnvNames)
    unknownMissingEnvNames = @($unknownMissingEnvNames)
    requiredOwnerEnvNames = $knownOwnerInputs
    steps = @($steps)
    reportPaths = $paths
    nextCommands = @(
        "npm run flowchain:owner-env:template",
        "npm run flowchain:owner-env:readiness -- -AllowBlocked",
        "npm run flowchain:completion:audit -- -AllowBlocked"
    )
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 20
Assert-FlowChainNoSecretText -Text $reportText -Label "owner env readiness report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Owner Env Readiness")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This gate points the live checks at the ignored local owner env file and records only env names, statuses, and redacted child output.")
$markdownLines.Add("")
$markdownLines.Add("Owner env file: ``$($report.ownerEnvFile.relativePath)``")
$markdownLines.Add("Inside repo: $ownerEnvInsideRepo")
$markdownLines.Add("Git ignored: $ownerEnvGitIgnored")
$markdownLines.Add("")
$markdownLines.Add("## Setup Required")
$markdownLines.Add("")
$markdownLines.Add("- Public DNS plus TLS edge or tunnel forwarding HTTPS traffic to the local FlowChain control plane on ``127.0.0.1:8787``.")
$markdownLines.Add("- Explicit browser origins and a per-minute public request limit for the RPC edge.")
$markdownLines.Add("- A tester write gateway flag, SHA-256 token digest, and per-send cap before public friends-and-family wallet writes.")
$markdownLines.Add("- An always-on host that keeps the node and control plane running.")
$markdownLines.Add("- A writable state backup directory for public operation.")
$markdownLines.Add("- A Base 8453 provider endpoint, deployed lockbox address, supported token address, block range, confirmations, and capped pilot limits for the bridge observer.")
$markdownLines.Add("")
$markdownLines.Add("## Required Env Names")
$markdownLines.Add("")
foreach ($name in $knownOwnerInputs) {
    $markdownLines.Add("- ``$name``")
}
$markdownLines.Add("")
$markdownLines.Add("## Step Status")
$markdownLines.Add("")
$markdownLines.Add("| Step | Status | Report |")
$markdownLines.Add("| --- | --- | --- |")
foreach ($step in @($steps)) {
    $markdownLines.Add("| $($step.name) | $($step.status) | ``$($step.reportPath)`` |")
}
if (@($steps).Count -eq 0) {
    $markdownLines.Add("| owner env path safety | failed | ``$reportFullPath`` |")
}
$markdownLines.Add("")
$markdownLines.Add("## Next Commands")
$markdownLines.Add("")
foreach ($command in @($report.nextCommands)) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
if ($status -eq "passed") {
    $markdownLines.Add("The owner env file is structurally valid and the live infrastructure gates passed.")
}
elseif ($status -eq "blocked") {
    $markdownLines.Add("The runner is working and remains blocked only on the missing owner env names listed in the JSON report.")
}
else {
    $markdownLines.Add("Fix the owner env file path, git-ignore state, or invalid owner values before sharing the public network.")
}

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "owner env readiness markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host ""
Write-Host "FlowChain owner env readiness status: $status"
Write-Host "Owner env file: $ownerEnvFullPath"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if (@($missingEnvNames).Count -gt 0) {
    Write-Host "Missing env names: $($missingEnvNames -join ', ')"
}
if (@($invalidEnvNames).Count -gt 0) {
    Write-Host "Invalid env names: $($invalidEnvNames -join ', ')"
}
if (@($pathProblems).Count -gt 0) {
    Write-Host "Owner env file problems: $($pathProblems -join '; ')"
}

if ($status -eq "passed" -or ($status -eq "blocked" -and $AllowBlocked)) {
    exit 0
}
exit 1
