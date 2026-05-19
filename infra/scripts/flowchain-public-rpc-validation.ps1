param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$validationDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-validation")
$backupDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/public-rpc-validation-backup")
$ownerEnvPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/public-rpc-validation-owner.env")
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/state.json")
New-Item -ItemType Directory -Force -Path $validationDir | Out-Null
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

$envNames = @(
    "FLOWCHAIN_RPC_PUBLIC_URL",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_RPC_TLS_TERMINATED",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH"
)

function Get-FreeLocalPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse("127.0.0.1"), 0)
    $listener.Start()
    try {
        return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally {
        $listener.Stop()
    }
}

function Get-ValidationProp {
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

function Get-ValidationSecretMarkerFindings {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Label
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

    $findings = New-Object System.Collections.ArrayList
    foreach ($pattern in $patterns) {
        if ($Text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            [void] $findings.Add([ordered]@{
                label = $Label
                marker = $pattern
            })
        }
    }
    return @($findings)
}

function Wait-ControlPlaneHealth {
    param(
        [Parameter(Mandatory = $true)][string] $BaseUrl,
        [int] $TimeoutSeconds = 20
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastError = $null
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-RestMethod -Uri "$BaseUrl/health" -Method Get -TimeoutSec 5
            if ($null -ne $response -and $response.schema -eq "flowmemory.control_plane.health.v0") {
                return
            }
            $lastError = "unexpected health schema"
        }
        catch {
            $lastError = $_.Exception.Message
        }
        Start-Sleep -Milliseconds 500
    }
    throw "Temporary control-plane did not become healthy. Last status: $lastError"
}

$originalEnv = @{}
foreach ($name in $envNames) {
    $originalEnv[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}
$originalOwnerEnvFile = [Environment]::GetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", "Process")

$port = Get-FreeLocalPort
$baseUrl = "http://127.0.0.1:$port"
$allowedOrigin = "https://flowchain-validation-allowed.example"
$serverScript = Join-Path $repoRoot "services/control-plane/src/server.ts"
$stdoutPath = Join-Path $validationDir "control-plane.stdout.log"
$stderrPath = Join-Path $validationDir "control-plane.stderr.log"
$readinessReportPath = Join-Path $validationDir "public-rpc-readiness-report.json"
$serverProcess = $null

try {
    Set-Content -LiteralPath $ownerEnvPath -Value (@(
        "FLOWCHAIN_RPC_PUBLIC_URL=$baseUrl",
        "FLOWCHAIN_RPC_ALLOWED_ORIGINS=$allowedOrigin",
        "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE=20",
        "FLOWCHAIN_RPC_TLS_TERMINATED=true",
        "FLOWCHAIN_RPC_STATE_BACKUP_PATH=$backupDir"
    ) -join "`r`n") -Encoding UTF8
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", $ownerEnvPath, "Process")
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_RPC_PUBLIC_URL", $baseUrl, "Process")
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_RPC_ALLOWED_ORIGINS", $allowedOrigin, "Process")
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "20", "Process")
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_RPC_TLS_TERMINATED", "true", "Process")
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_RPC_STATE_BACKUP_PATH", $backupDir, "Process")

    $serverProcess = Start-Process -FilePath "node" `
        -ArgumentList @($serverScript, "--host", "127.0.0.1", "--port", "$port") `
        -WorkingDirectory $repoRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru

    Wait-ControlPlaneHealth -BaseUrl $baseUrl

    $readinessOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-public-rpc-readiness.ps1") `
        -StatePath $stateFullPath `
        -ReportPath $readinessReportPath `
        -AllowBlocked 2>&1
    $readinessExitCode = $LASTEXITCODE
    $readinessReport = Read-FlowChainJsonIfExists -Path $readinessReportPath

    $checks = Get-ValidationProp -Object $readinessReport -Name "checks"
    $deploymentChecks = Get-ValidationProp -Object $readinessReport -Name "deploymentChecks"
    $cors = Get-ValidationProp -Object $readinessReport -Name "cors"
    $endpointChecks = @((Get-ValidationProp -Object $readinessReport -Name "endpointChecks" -Default @()))
    $failedEndpointChecks = @($endpointChecks | Where-Object { "$($_.status)" -ne "passed" })
    $missingEnvNames = @((Get-ValidationProp -Object $readinessReport -Name "missingEnvNames" -Default @()))
    $problems = @((Get-ValidationProp -Object $readinessReport -Name "problems" -Default @()))
    $failedProblems = @($problems | Where-Object { "$($_.kind)" -eq "failed" })

    $validationChecks = [ordered]@{
        readinessExitedCleanly = $readinessExitCode -eq 0
        localEndpointBlocksPublicReady = (Get-ValidationProp -Object $readinessReport -Name "status") -eq "blocked" -and (Get-ValidationProp -Object $readinessReport -Name "explicitLocalEndpoint") -eq $true -and (Get-ValidationProp -Object $readinessReport -Name "publicRpcReady") -eq $false
        localEndpointSelfReportsNonProduction = (Get-ValidationProp -Object $deploymentChecks -Name "readinessEndpointPresent" -Default $false) -eq $true -and (Get-ValidationProp -Object $deploymentChecks -Name "readinessPublicRpcReady" -Default $true) -eq $false -and (Get-ValidationProp -Object $deploymentChecks -Name "readinessProductionReady" -Default $true) -eq $false -and (Get-ValidationProp -Object $deploymentChecks -Name "readinessLocalOnlyFalse" -Default $true) -eq $false -and (Get-ValidationProp -Object $deploymentChecks -Name "readinessDeploymentModePublicEdge" -Default $true) -eq $false
        discoveryMatchesReadinessDeployment = (Get-ValidationProp -Object $checks -Name "discoveryMatchesReadinessDeployment" -Default $false) -eq $true
        readinessDeploymentFlagsConsistent = (Get-ValidationProp -Object $checks -Name "readinessDeploymentFlagsConsistent" -Default $false) -eq $true
        noPublicRpcEnvMissing = $missingEnvNames.Count -eq 0
        noFailedEndpointChecks = $failedEndpointChecks.Count -eq 0
        allowedOriginAccepted = (Get-ValidationProp -Object $checks -Name "corsConfiguredOriginAccepted" -Default $false) -eq $true -and (Get-ValidationProp -Object $cors -Name "configuredOriginAccepted" -Default $false) -eq $true
        disallowedOriginProbePerformed = (Get-ValidationProp -Object $checks -Name "corsDisallowedOriginProbePerformed" -Default $false) -eq $true -and (Get-ValidationProp -Object $cors -Name "disallowedOriginProbePerformed" -Default $false) -eq $true
        disallowedOriginRejected = (Get-ValidationProp -Object $checks -Name "corsDisallowedOriginRejected" -Default $false) -eq $true -and (Get-ValidationProp -Object $cors -Name "disallowedOriginRejected" -Default $false) -eq $true
        rateLimitProbePerformed = (Get-ValidationProp -Object $checks -Name "rateLimitProbePerformed" -Default $false) -eq $true
        rateLimitRejected = (Get-ValidationProp -Object $checks -Name "rateLimitRejectionObserved" -Default $false) -eq $true
        rateLimitRetryAfterHeaderPresent = (Get-ValidationProp -Object $checks -Name "rateLimitRetryAfterHeaderPresent" -Default $false) -eq $true
        responseHygienePassed = (Get-ValidationProp -Object $checks -Name "responseHygienePassed" -Default $false) -eq $true
        failedProblemsAbsent = $failedProblems.Count -eq 0
        secretMarkerFindingsEmpty = $true
        envValuesPrintedFalse = $true
        noSecrets = $true
        broadcastsFalse = $true
    }

    $report = [ordered]@{
        schema = "flowchain.public_rpc_validation_report.v0"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        status = "pending"
        validationScope = "local-control-plane-public-rpc-readiness-rehearsal"
        publicRpcReady = $false
        expectedBlockedBecauseEndpointIsLocal = $true
        checks = $validationChecks
        failedChecks = @()
        secretMarkerFindings = @()
        readinessStatus = Get-ValidationProp -Object $readinessReport -Name "status" -Default "missing"
        readinessExitCode = $readinessExitCode
        endpointCheckCount = $endpointChecks.Count
        failedEndpointCheckCount = $failedEndpointChecks.Count
        missingEnvCount = $missingEnvNames.Count
        failedProblemCount = $failedProblems.Count
        reportPaths = [ordered]@{
            validation = $reportFullPath
            readiness = $readinessReportPath
            stdout = $stdoutPath
            stderr = $stderrPath
        }
        readinessOutputRedacted = @($readinessOutput | ForEach-Object { "$_" })
        envValuesPrinted = $false
        noSecrets = $true
        broadcasts = $false
    }

    $preliminaryReportText = $report | ConvertTo-Json -Depth 18
    $secretMarkerFindings = @(Get-ValidationSecretMarkerFindings -Text $preliminaryReportText -Label "public RPC validation report")
    $validationChecks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
    $validationChecks["noSecrets"] = $secretMarkerFindings.Count -eq 0
    $failedValidationChecks = @($validationChecks.GetEnumerator() | Where-Object { $_.Value -ne $true })
    $status = if ($failedValidationChecks.Count -eq 0) { "passed" } else { "failed" }
    $report["status"] = $status
    $report["checks"] = $validationChecks
    $report["failedChecks"] = @($failedValidationChecks | ForEach-Object { $_.Key })
    $report["secretMarkerFindings"] = @($secretMarkerFindings)
    $report["noSecrets"] = $secretMarkerFindings.Count -eq 0
}
finally {
    if ($null -ne $serverProcess -and -not $serverProcess.HasExited) {
        Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue
        $serverProcess.WaitForExit(5000) | Out-Null
    }
    foreach ($name in $envNames) {
        [Environment]::SetEnvironmentVariable($name, $originalEnv[$name], "Process")
    }
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", $originalOwnerEnvFile, "Process")
    Remove-Item -LiteralPath $ownerEnvPath -Force -ErrorAction SilentlyContinue
}

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "public RPC validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

Write-Host "FlowChain public RPC validation status: $($report.status)"
Write-Host "Readiness status: $($report.readinessStatus)"
Write-Host "Report: $reportFullPath"
if ($report.status -ne "passed") {
    Write-Host "Failed checks: $((@($report.failedChecks)) -join ', ')"
    exit 1
}
exit 0
