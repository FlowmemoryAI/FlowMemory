param(
    [string] $OwnerEnvFile = "devnet/local/owner-inputs/flowchain-owner.local.env",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/live-cutover-rehearsal-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/LIVE_CUTOVER_REHEARSAL.md",
    [int] $ChildTimeoutSeconds = 900,
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$ownerEnvFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OwnerEnvFile)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$tmpDir = Join-Path $repoRoot "devnet/local/tmp/live-cutover-rehearsal"
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

if ($ChildTimeoutSeconds -lt 1) {
    throw "ChildTimeoutSeconds must be at least 1."
}

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
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS"
)
$optionalOwnerInputs = @(
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK"
)

$paths = [ordered]@{
    ownerEnvReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-report.json"
    publicDeploymentContract = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
    externalTesterPacket = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
    completionAudit = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json"
    truthTable = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json"
    noSecret = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
}

function Get-CutoverRelativePath {
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

function Get-CutoverProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

function Get-CutoverReportStatus {
    param([AllowNull()][object] $Report)

    if ($null -eq $Report) {
        return "missing"
    }
    return [string](Get-CutoverProp -Object $Report -Name "status" -Default "unknown")
}

function Add-UniqueCutoverName {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [AllowNull()][object] $Value
    )

    $name = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($name) -and -not $Target.Contains($name)) {
        [void] $Target.Add($name)
    }
}

function ConvertTo-CutoverSafeLine {
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

function Test-CutoverGitIgnored {
    param([Parameter(Mandatory = $true)][string] $RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        return [ordered]@{ ignored = $false; exitCode = 1; outputLineCount = 0 }
    }
    $output = @(& git -C $repoRoot check-ignore --quiet -- $RelativePath 2>&1 | ForEach-Object { ConvertTo-CutoverSafeLine -Line $_ })
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
    return [ordered]@{
        ignored = $exitCode -eq 0
        exitCode = $exitCode
        outputLineCount = @($output).Count
    }
}

function Invoke-CutoverStep {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Command,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList,
        [Parameter(Mandatory = $true)][string] $ExpectedReportPath
    )

    Write-Host ""
    Write-Host "== $Name =="
    Write-Host $Command

    $runId = "$(Get-Date -Format 'yyyyMMddHHmmssfff')-$PID-$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"
    $stdoutPath = Join-Path $tmpDir "$runId.stdout.log"
    $stderrPath = Join-Path $tmpDir "$runId.stderr.log"
    $startedAt = (Get-Date).ToUniversalTime().ToString("o")
    $timedOut = $false
    try {
        $process = Start-Process -FilePath "powershell" `
            -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $ArgumentList) `
            -WorkingDirectory $repoRoot `
            -PassThru `
            -WindowStyle Hidden `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
        $timedOut = -not $process.WaitForExit($ChildTimeoutSeconds * 1000)
        if ($timedOut) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $exitCode = 124
        }
        else {
            $process.Refresh()
            $exitCode = [int] $process.ExitCode
        }
        $output = @()
        if (Test-Path -LiteralPath $stdoutPath) {
            $output += @(Get-Content -LiteralPath $stdoutPath -Tail 80 | ForEach-Object { ConvertTo-CutoverSafeLine -Line $_ })
        }
        if (Test-Path -LiteralPath $stderrPath) {
            $output += @(Get-Content -LiteralPath $stderrPath -Tail 80 | ForEach-Object { ConvertTo-CutoverSafeLine -Line $_ })
        }
    }
    catch {
        $output = @(ConvertTo-CutoverSafeLine -Line $_.Exception.Message)
        $exitCode = 1
    }

    $childReport = Read-FlowChainJsonIfExists -Path $ExpectedReportPath
    $childStatus = Get-CutoverReportStatus -Report $childReport
    $status = if ($timedOut) {
        "failed"
    }
    elseif ($childStatus -in @("passed", "blocked", "failed")) {
        $childStatus
    }
    elseif ($exitCode -eq 0) {
        "passed"
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
        timedOut = $timedOut
        status = $status
        reportPath = $ExpectedReportPath
        stdoutPath = $stdoutPath
        stderrPath = $stderrPath
        outputRedactedTail = @($output | Select-Object -Last 80)
    }
}

$ownerEnvRelativePath = Get-CutoverRelativePath -BasePath $repoRoot -ChildPath $ownerEnvFullPath
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
$ownerEnvGitIgnore = Test-CutoverGitIgnored -RelativePath $ownerEnvRelativePath
$ownerEnvPathSafe = $ownerEnvExists -and $ownerEnvIsFile -and $ownerEnvGitIgnore.ignored -eq $true

$pathProblems = New-Object System.Collections.ArrayList
if (-not $ownerEnvExists) {
    [void] $pathProblems.Add("owner env file is missing")
}
elseif (-not $ownerEnvIsFile) {
    [void] $pathProblems.Add("owner env path is not a file")
}
if ($ownerEnvGitIgnore.ignored -ne $true) {
    [void] $pathProblems.Add("owner env file is not git-ignored")
}

$steps = New-Object System.Collections.ArrayList
$previousOwnerEnvFile = [Environment]::GetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", "Process")
try {
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", $ownerEnvFullPath, "Process")

    [void] $steps.Add((Invoke-CutoverStep `
        -Name "Owner env readiness" `
        -Command "npm run flowchain:owner-env:readiness -- -AllowBlocked" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-env-readiness.ps1"), "-OwnerEnvFile", $ownerEnvFullPath, "-AllowBlocked") `
        -ExpectedReportPath $paths.ownerEnvReadiness))

    [void] $steps.Add((Invoke-CutoverStep `
        -Name "Public deployment contract" `
        -Command "npm run flowchain:public-deployment:contract -- -AllowBlocked -NoRefresh" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-deployment-contract.ps1"), "-AllowBlocked", "-NoRefresh") `
        -ExpectedReportPath $paths.publicDeploymentContract))

    [void] $steps.Add((Invoke-CutoverStep `
        -Name "External tester packet" `
        -Command "npm run flowchain:external-tester:packet -- -AllowBlocked" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-external-tester-packet.ps1"), "-AllowBlocked") `
        -ExpectedReportPath $paths.externalTesterPacket))

    [void] $steps.Add((Invoke-CutoverStep `
        -Name "Completion audit" `
        -Command "npm run flowchain:completion:audit -- -NoRefresh -AllowBlocked" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-completion-audit.ps1"), "-NoRefresh", "-AllowBlocked") `
        -ExpectedReportPath $paths.completionAudit))

    [void] $steps.Add((Invoke-CutoverStep `
        -Name "Production truth table" `
        -Command "npm run flowchain:truth-table -- -AllowBlocked" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-production-truth-table.ps1"), "-AllowBlocked") `
        -ExpectedReportPath $paths.truthTable))

    [void] $steps.Add((Invoke-CutoverStep `
        -Name "No-secret scan" `
        -Command "npm run flowchain:no-secret:scan" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-no-secret-scan.ps1")) `
        -ExpectedReportPath $paths.noSecret))
}
finally {
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", $previousOwnerEnvFile, "Process")
}

$reports = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    $reports[$entry.Key] = Read-FlowChainJsonIfExists -Path $entry.Value
}

$missingEnvNames = New-Object System.Collections.ArrayList
$invalidEnvNames = New-Object System.Collections.ArrayList
foreach ($report in $reports.Values) {
    foreach ($name in @((Get-CutoverProp -Object $report -Name "missingEnvNames" -Default @()))) {
        if ($name -notin $optionalOwnerInputs) {
            Add-UniqueCutoverName -Target $missingEnvNames -Value $name
        }
    }
    foreach ($name in @((Get-CutoverProp -Object $report -Name "invalidEnvNames" -Default @()))) {
        Add-UniqueCutoverName -Target $invalidEnvNames -Value $name
    }
}

$ownerInputsReport = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json")
$ownerInputValidNames = @((Get-CutoverProp -Object $ownerInputsReport -Name "inputs" -Default @()) | Where-Object {
        (Get-CutoverProp -Object $_ -Name "present" -Default $false) -eq $true `
            -and (Get-CutoverProp -Object $_ -Name "valid" -Default $false) -eq $true
    } | ForEach-Object {
        [string](Get-CutoverProp -Object $_ -Name "name" -Default "")
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$filteredMissingEnvNames = New-Object System.Collections.ArrayList
foreach ($name in @($missingEnvNames)) {
    if ($name -notin $ownerInputValidNames) {
        Add-UniqueCutoverName -Target $filteredMissingEnvNames -Value $name
    }
}
$filteredInvalidEnvNames = New-Object System.Collections.ArrayList
foreach ($name in @($invalidEnvNames)) {
    if ($name -notin $ownerInputValidNames) {
        Add-UniqueCutoverName -Target $filteredInvalidEnvNames -Value $name
    }
}
$missingEnvNames = $filteredMissingEnvNames
$invalidEnvNames = $filteredInvalidEnvNames

$unknownMissingEnvNames = @($missingEnvNames | Where-Object { $_ -notin $knownOwnerInputs })
$failedSteps = @($steps | Where-Object { "$($_.status)" -eq "failed" -or [int] $_.exitCode -eq 124 -or $_.timedOut -eq $true })
$ready = [ordered]@{
    ownerEnvReady = (Get-CutoverProp -Object (Get-CutoverProp -Object $reports.ownerEnvReadiness -Name "readiness") -Name "ownerInputsReady" -Default $false) -eq $true
    publicDeploymentReady = (Get-CutoverProp -Object $reports.publicDeploymentContract -Name "deploymentReady" -Default $false) -eq $true
    testerPacketShareable = (Get-CutoverProp -Object $reports.externalTesterPacket -Name "packetShareable" -Default $false) -eq $true
    completionReady = (Get-CutoverProp -Object $reports.completionAudit -Name "completionReady" -Default $false) -eq $true
    truthTableCompleted = (Get-CutoverReportStatus -Report $reports.truthTable) -in @("passed", "blocked-owner-input")
    noSecretScanPassed = (Get-CutoverReportStatus -Report $reports.noSecret) -eq "passed"
}
$allReady = @($ready.GetEnumerator() | Where-Object { $_.Value -ne $true }).Count -eq 0
$blockedOnlyOnKnownOwnerInputs = $ownerEnvPathSafe `
    -and $failedSteps.Count -eq 0 `
    -and @($invalidEnvNames).Count -eq 0 `
    -and @($unknownMissingEnvNames).Count -eq 0 `
    -and @($missingEnvNames).Count -gt 0

$status = if (-not $ownerEnvPathSafe -or $failedSteps.Count -gt 0 -or @($invalidEnvNames).Count -gt 0 -or @($unknownMissingEnvNames).Count -gt 0) {
    "failed"
}
elseif ($allReady -and @($missingEnvNames).Count -eq 0) {
    "passed"
}
else {
    "blocked"
}

$checks = [ordered]@{
    ownerEnvFilePathSafe = $ownerEnvPathSafe
    ownerEnvFileExists = $ownerEnvExists
    ownerEnvFileIsFile = $ownerEnvIsFile
    ownerEnvFileGitIgnored = $ownerEnvGitIgnore.ignored -eq $true
    stepsRan = @($steps).Count -eq 6
    stepCommandsSucceeded = @($steps | Where-Object { [int] $_.exitCode -ne 0 -and "$($_.status)" -ne "blocked" }).Count -eq 0
    noFailedSteps = $failedSteps.Count -eq 0
    missingEnvNamesEmpty = @($missingEnvNames).Count -eq 0
    invalidEnvNamesEmpty = @($invalidEnvNames).Count -eq 0
    unknownMissingEnvNamesEmpty = @($unknownMissingEnvNames).Count -eq 0
    blockedOnlyOnKnownOwnerInputs = $blockedOnlyOnKnownOwnerInputs
    ownerEnvReady = $ready.ownerEnvReady
    publicDeploymentReady = $ready.publicDeploymentReady
    testerPacketShareable = $ready.testerPacketShareable
    completionReady = $ready.completionReady
    truthTableCompleted = $ready.truthTableCompleted
    noSecretScanPassed = $ready.noSecretScanPassed
    envValuesPrintedFalse = $true
    noSecrets = $true
    broadcastsFalse = $true
}
$failedChecks = @($checks.GetEnumerator() | Where-Object {
        $_.Key -notin @(
            "missingEnvNamesEmpty",
            "blockedOnlyOnKnownOwnerInputs",
            "ownerEnvReady",
            "publicDeploymentReady",
            "testerPacketShareable",
            "completionReady",
            "truthTableCompleted"
        ) -and $_.Value -ne $true
    } | ForEach-Object { $_.Key })
if ($status -eq "passed") {
    $failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
}

$report = [ordered]@{
    schema = "flowchain.live_cutover_rehearsal_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    ownerEnvFile = [ordered]@{
        path = $ownerEnvFullPath
        relativePath = $ownerEnvRelativePath
        exists = $ownerEnvExists
        isFile = $ownerEnvIsFile
        gitIgnored = $ownerEnvGitIgnore.ignored
        problems = @($pathProblems)
    }
    ready = $ready
    blockedOnlyOnKnownExternalOwnerInputs = $blockedOnlyOnKnownOwnerInputs
    missingEnvNames = @($missingEnvNames)
    invalidEnvNames = @($invalidEnvNames)
    unknownMissingEnvNames = @($unknownMissingEnvNames)
    steps = @($steps)
    reportPaths = $paths
    checks = $checks
    failedChecks = @($failedChecks)
    nextCommands = @(
        "npm run flowchain:owner-env:readiness -- -AllowBlocked",
        "npm run flowchain:public-deployment:contract -- -AllowBlocked",
        "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked",
        "npm run flowchain:truth-table -- -AllowBlocked"
    )
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 20
Assert-FlowChainNoSecretText -Text $reportText -Label "live cutover rehearsal report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Live Cutover Rehearsal")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This command runs the owner-env, public deployment, tester packet, completion audit, truth table, and no-secret gates through one redacted rehearsal. It records env names and statuses only.")
$markdownLines.Add("")
$markdownLines.Add("Owner env file: ``$ownerEnvRelativePath``")
$markdownLines.Add("Owner env file git-ignored: $($ownerEnvGitIgnore.ignored)")
$markdownLines.Add("Blocked only on known owner inputs: $blockedOnlyOnKnownOwnerInputs")
$markdownLines.Add("")
$markdownLines.Add("## Gate Status")
$markdownLines.Add("")
$markdownLines.Add("| Gate | Ready |")
$markdownLines.Add("| --- | --- |")
foreach ($entry in $ready.GetEnumerator()) {
    $markdownLines.Add("| $($entry.Key) | $($entry.Value) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Steps")
$markdownLines.Add("")
$markdownLines.Add("| Step | Status | Report |")
$markdownLines.Add("| --- | --- | --- |")
foreach ($step in @($steps)) {
    $markdownLines.Add("| $($step.name) | $($step.status) | ``$($step.reportPath)`` |")
}
$markdownLines.Add("")
$markdownLines.Add("## Missing Owner Env Names")
$markdownLines.Add("")
if (@($missingEnvNames).Count -eq 0) {
    $markdownLines.Add("- none")
}
else {
    foreach ($name in @($missingEnvNames)) {
        $markdownLines.Add("- ``$name``")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Next Commands")
$markdownLines.Add("")
foreach ($command in @($report.nextCommands)) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
if ($status -eq "passed") {
    $markdownLines.Add("All rehearsal gates passed with no missing owner env names.")
}
elseif ($status -eq "blocked") {
    $markdownLines.Add("The rehearsal is runnable and remains blocked only on the missing owner env names above.")
}
else {
    $markdownLines.Add("Fix failed steps, unsafe owner env file state, invalid owner input names, or unknown blockers before sharing the network.")
}

$markdownText = ($markdownLines -join [Environment]::NewLine) + [Environment]::NewLine
Assert-FlowChainNoSecretText -Text $markdownText -Label "live cutover rehearsal markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($markdownFullPath, $markdownText, $utf8NoBom)

Write-Host ""
Write-Host "FlowChain live cutover rehearsal status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if (@($missingEnvNames).Count -gt 0) {
    Write-Host "Missing env names: $($missingEnvNames -join ', ')"
}
if (@($failedChecks).Count -gt 0) {
    Write-Host "Failed checks: $($failedChecks -join ', ')"
}

if ($status -eq "passed" -or ($status -eq "blocked" -and $AllowBlocked)) {
    exit 0
}
exit 1
