param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json",
    [int] $MaxTesterReportAgeMinutes = 30,
    [int] $MaxPublicTesterGatewayReportAgeMinutes = 30,
    [switch] $NoRefreshTesterNetwork,
    [switch] $NoRefreshPublicTesterGateway,
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$optionalMissingEnvNames = @(
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK"
)
$serviceStatusReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
$liveInfraReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json"
$liveProductReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json"
$ownerInputsReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
$testerNetworkReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json"
$publicTesterGatewayReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json"

function ConvertTo-ExternalTesterSafeLine {
    param([AllowNull()][object] $Line)

    $text = "$Line"
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "https?://[^\s,)]+", "<redacted-url>")
    return $text
}

function Add-UniqueName {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [object] $Value
    )

    $name = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($name) -and -not $Target.Contains($name)) {
        [void] $Target.Add($name)
    }
}

function Get-PropertyValue {
    param(
        [object] $Object,
        [string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

function Test-ReportFresh {
    param(
        [AllowNull()][object] $Report,
        [int] $MaxAgeMinutes
    )

    if ($null -eq $Report -or -not ($Report.PSObject.Properties.Name -contains "generatedAt")) {
        return $false
    }
    try {
        $generatedAt = [System.DateTimeOffset]::Parse("$($Report.generatedAt)", [System.Globalization.CultureInfo]::InvariantCulture)
        $age = [System.DateTimeOffset]::UtcNow - $generatedAt.ToUniversalTime()
        return $age.TotalMinutes -le $MaxAgeMinutes
    }
    catch {
        return $false
    }
}

function Test-PacketExecutableSmokeReport {
    param([AllowNull()][object] $Report)

    if ($null -eq $Report) {
        return $false
    }
    if ((Get-PropertyValue -Object $Report -Name "packetExecutableSmokeValidated" -Default $false) -ne $true) {
        return $false
    }
    $checks = Get-PropertyValue -Object $Report -Name "packetSmokeChecks"
    foreach ($name in @("health", "rpcDiscover", "rpcReadiness", "chainStatus", "walletCreate", "walletBalances", "walletSend", "walletTransfers")) {
        if ((Get-PropertyValue -Object $checks -Name $name -Default $false) -ne $true) {
            return $false
        }
    }
    return $true
}

function Test-RoutePresent {
    param(
        [AllowNull()][object] $Routes,
        [Parameter(Mandatory = $true)][string] $Route
    )

    foreach ($candidate in @($Routes)) {
        if ("$candidate" -eq $Route) {
            return $true
        }
    }
    return $false
}

function Test-PublicTesterGatewayReport {
    param([AllowNull()][object] $Report)

    if ($null -eq $Report) {
        return $false
    }
    return (Get-PropertyValue -Object $Report -Name "status") -eq "passed" `
        -and (Get-PropertyValue -Object $Report -Name "testerGatewayConfigured" -Default $false) -eq $true `
        -and (Get-PropertyValue -Object $Report -Name "testerWriteTokenHashConfigured" -Default $false) -eq $true `
        -and (Get-PropertyValue -Object $Report -Name "testerFaucetSchema") -eq "flowmemory.control_plane.tester_faucet_result.v0" `
        -and (Get-PropertyValue -Object $Report -Name "walletSendSchema") -eq "flowmemory.control_plane.tester_wallet_send_result.v0" `
        -and (Get-PropertyValue -Object $Report -Name "transferAccepted" -Default $false) -eq $true `
        -and (Get-PropertyValue -Object $Report -Name "capRejected" -Default $false) -eq $true `
        -and (Get-PropertyValue -Object $Report -Name "noSecrets" -Default $false) -eq $true `
        -and (Get-PropertyValue -Object $Report -Name "envValuesPrinted" -Default $true) -eq $false `
        -and (Test-RoutePresent -Routes (Get-PropertyValue -Object $Report -Name "routes" -Default @()) -Route "/tester/faucet")
}

function Invoke-ExternalTesterChild {
    param(
        [Parameter(Mandatory = $true)][string[]] $ArgumentList
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = (& powershell @ArgumentList 2>&1) | ForEach-Object { ConvertTo-ExternalTesterSafeLine -Line $_ }
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) {
            $exitCode = 0
        }
    }
    catch {
        $output = @(ConvertTo-ExternalTesterSafeLine -Line $_.Exception.Message)
        $exitCode = 1
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    return [ordered]@{
        exitCode = [int] $exitCode
        outputRedactedTail = @($output | Select-Object -Last 80)
    }
}

$serviceOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-service-status.ps1") -AllowBlocked 2>&1
$serviceExitCode = $LASTEXITCODE
$liveInfraRefresh = Invoke-ExternalTesterChild -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-infra-check.ps1"), "-AllowBlocked")
$testerNetworkReportBefore = Read-FlowChainJsonIfExists -Path $testerNetworkReportPath
$testerNetworkFreshBefore = Test-ReportFresh -Report $testerNetworkReportBefore -MaxAgeMinutes $MaxTesterReportAgeMinutes
$testerNetworkPacketSmokeBefore = Test-PacketExecutableSmokeReport -Report $testerNetworkReportBefore
$publicTesterGatewayReportBefore = Read-FlowChainJsonIfExists -Path $publicTesterGatewayReportPath
$publicTesterGatewayFreshBefore = Test-ReportFresh -Report $publicTesterGatewayReportBefore -MaxAgeMinutes $MaxPublicTesterGatewayReportAgeMinutes
$publicTesterGatewayReadyBefore = Test-PublicTesterGatewayReport -Report $publicTesterGatewayReportBefore
$testerNetworkRefreshPerformed = $false
$testerNetworkRefresh = [ordered]@{
    exitCode = $null
    outputRedactedTail = @()
}
$publicTesterGatewayRefreshPerformed = $false
$publicTesterGatewayRefresh = [ordered]@{
    exitCode = $null
    outputRedactedTail = @()
}
if (-not $NoRefreshTesterNetwork.IsPresent -and (-not $testerNetworkFreshBefore -or -not $testerNetworkPacketSmokeBefore)) {
    $testerNetworkRefreshPerformed = $true
    $testerNetworkRefresh = Invoke-ExternalTesterChild -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-service-tester-network-e2e.ps1"))
}
if (-not $NoRefreshPublicTesterGateway.IsPresent -and (-not $publicTesterGatewayFreshBefore -or -not $publicTesterGatewayReadyBefore)) {
    $publicTesterGatewayRefreshPerformed = $true
    $publicTesterGatewayRefresh = Invoke-ExternalTesterChild -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-tester-gateway-e2e.ps1"))
}

$serviceReport = Read-FlowChainJsonIfExists -Path $serviceStatusReportPath
$liveInfraReport = Read-FlowChainJsonIfExists -Path $liveInfraReportPath
$liveProductReport = Read-FlowChainJsonIfExists -Path $liveProductReportPath
$ownerInputsReport = Read-FlowChainJsonIfExists -Path $ownerInputsReportPath
$testerNetworkReport = Read-FlowChainJsonIfExists -Path $testerNetworkReportPath
$publicTesterGatewayReport = Read-FlowChainJsonIfExists -Path $publicTesterGatewayReportPath
$testerNetworkFresh = Test-ReportFresh -Report $testerNetworkReport -MaxAgeMinutes $MaxTesterReportAgeMinutes
$testerNetworkPacketSmokeValidated = Test-PacketExecutableSmokeReport -Report $testerNetworkReport
$publicTesterGatewayFresh = Test-ReportFresh -Report $publicTesterGatewayReport -MaxAgeMinutes $MaxPublicTesterGatewayReportAgeMinutes
$publicTesterGatewayReady = Test-PublicTesterGatewayReport -Report $publicTesterGatewayReport

$missingEnvNames = New-Object System.Collections.ArrayList
foreach ($name in @((Get-PropertyValue -Object $liveInfraReport -Name "missingEnvNames" -Default @()))) {
    if ($name -notin $optionalMissingEnvNames) {
        Add-UniqueName -Target $missingEnvNames -Value $name
    }
}
foreach ($name in @((Get-PropertyValue -Object $liveProductReport -Name "missingEnvNames" -Default @()))) {
    if ($name -notin $optionalMissingEnvNames) {
        Add-UniqueName -Target $missingEnvNames -Value $name
    }
}
$ownerInputValidNames = @((Get-PropertyValue -Object $ownerInputsReport -Name "inputs" -Default @()) | Where-Object {
        (Get-PropertyValue -Object $_ -Name "present" -Default $false) -eq $true `
            -and (Get-PropertyValue -Object $_ -Name "valid" -Default $false) -eq $true
    } | ForEach-Object {
        [string](Get-PropertyValue -Object $_ -Name "name" -Default "")
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$filteredMissingEnvNames = New-Object System.Collections.ArrayList
foreach ($name in @($missingEnvNames)) {
    if ($name -notin $ownerInputValidNames) {
        Add-UniqueName -Target $filteredMissingEnvNames -Value $name
    }
}
$missingEnvNames = $filteredMissingEnvNames

$serviceReady = $serviceExitCode -eq 0 `
    -and $null -ne $serviceReport `
    -and (Get-PropertyValue -Object $serviceReport -Name "status") -eq "passed" `
    -and (Get-PropertyValue -Object (Get-PropertyValue -Object $serviceReport -Name "node") -Name "status") -eq "running" `
    -and (Get-PropertyValue -Object (Get-PropertyValue -Object $serviceReport -Name "controlPlane") -Name "status") -eq "running"

$chain = Get-PropertyValue -Object $serviceReport -Name "chain"
$latestHeight = Get-PropertyValue -Object $chain -Name "latestHeight" -Default ""
$stateFileLastWriteAgeSeconds = [int] (Get-PropertyValue -Object $chain -Name "stateFileLastWriteAgeSeconds" -Default 999999)
$chainProducing = "$latestHeight" -match '^\d+$' -and [int64] "$latestHeight" -gt 0 -and $stateFileLastWriteAgeSeconds -le 60

$testerWalletCreates = @((Get-PropertyValue -Object $testerNetworkReport -Name "testerWalletCreates" -Default @()))
$testerTransfers = @((Get-PropertyValue -Object $testerNetworkReport -Name "transferResults" -Default @()))
$testerSecretBoundary = $testerWalletCreates.Count -ge 4
foreach ($wallet in $testerWalletCreates) {
    $testerSecretBoundary = $testerSecretBoundary -and (Get-PropertyValue -Object $wallet -Name "secretMaterialReturned") -eq $false
}
$testerNetworkReady = $null -ne $testerNetworkReport `
    -and (Get-PropertyValue -Object $testerNetworkReport -Name "status") -eq "passed" `
    -and $testerNetworkFresh `
    -and [int] (Get-PropertyValue -Object $testerNetworkReport -Name "testerCount" -Default 0) -ge 4 `
    -and $testerWalletCreates.Count -ge 4 `
    -and $testerTransfers.Count -ge 4 `
    -and $testerSecretBoundary `
    -and $testerNetworkPacketSmokeValidated

$liveInfraReady = $liveInfraRefresh.exitCode -eq 0 -and $null -ne $liveInfraReport -and (Get-PropertyValue -Object $liveInfraReport -Name "status") -eq "passed"
$externalSharingReady = $serviceReady -and $chainProducing -and $testerNetworkReady -and $publicTesterGatewayReady -and $liveInfraReady
$localTesterRehearsalReady = $serviceReady -and $chainProducing -and $testerNetworkReady -and $publicTesterGatewayReady
$refreshFailed = $liveInfraRefresh.exitCode -ne 0 `
    -or ($testerNetworkRefreshPerformed -and $testerNetworkRefresh.exitCode -ne 0) `
    -or ($publicTesterGatewayRefreshPerformed -and $publicTesterGatewayRefresh.exitCode -ne 0)

$status = if ($externalSharingReady) {
    "passed"
} elseif ($refreshFailed -or -not $serviceReady -or -not $chainProducing -or -not $testerNetworkReady) {
    "failed"
} else {
    "blocked"
}

$report = [ordered]@{
    schema = "flowchain.external_tester_readiness_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    localTesterRehearsalReady = $localTesterRehearsalReady
    externalSharingReady = $externalSharingReady
    checks = [ordered]@{
        serviceReady = $serviceReady
        chainProducing = $chainProducing
        testerWalletNetworkReady = $testerNetworkReady
        testerWalletNetworkFresh = $testerNetworkFresh
        packetExecutableSmokeValidated = $testerNetworkPacketSmokeValidated
        publicTesterGatewayReady = $publicTesterGatewayReady
        publicTesterGatewayFresh = $publicTesterGatewayFresh
        publicTesterGatewayFaucetRouteValidated = Test-RoutePresent -Routes (Get-PropertyValue -Object $publicTesterGatewayReport -Name "routes" -Default @()) -Route "/tester/faucet"
        liveInfraReady = $liveInfraReady
    }
    latestHeight = "$latestHeight"
    stateFileLastWriteAgeSeconds = $stateFileLastWriteAgeSeconds
    testerNetwork = [ordered]@{
        status = Get-PropertyValue -Object $testerNetworkReport -Name "status"
        generatedAt = Get-PropertyValue -Object $testerNetworkReport -Name "generatedAt"
        testerCount = Get-PropertyValue -Object $testerNetworkReport -Name "testerCount"
        chainBeforeBlock = Get-PropertyValue -Object $testerNetworkReport -Name "chainBeforeBlock"
        chainAfterBlock = Get-PropertyValue -Object $testerNetworkReport -Name "chainAfterBlock"
        walletCreateCount = $testerWalletCreates.Count
        transferCount = $testerTransfers.Count
        packetExecutableSmokeValidated = $testerNetworkPacketSmokeValidated
        packetSmokeChecks = Get-PropertyValue -Object $testerNetworkReport -Name "packetSmokeChecks"
        packetSmokeRoutes = Get-PropertyValue -Object $testerNetworkReport -Name "packetSmokeRoutes" -Default @()
        secretMaterialReturned = $false
    }
    publicTesterGateway = [ordered]@{
        status = Get-PropertyValue -Object $publicTesterGatewayReport -Name "status"
        generatedAt = Get-PropertyValue -Object $publicTesterGatewayReport -Name "generatedAt"
        fresh = $publicTesterGatewayFresh
        ready = $publicTesterGatewayReady
        maxSendUnits = Get-PropertyValue -Object $publicTesterGatewayReport -Name "maxSendUnits"
        testerFaucetSchema = Get-PropertyValue -Object $publicTesterGatewayReport -Name "testerFaucetSchema"
        walletCreateSchema = Get-PropertyValue -Object $publicTesterGatewayReport -Name "walletCreateSchema"
        walletSendSchema = Get-PropertyValue -Object $publicTesterGatewayReport -Name "walletSendSchema"
        transferAccepted = Get-PropertyValue -Object $publicTesterGatewayReport -Name "transferAccepted"
        capRejected = Get-PropertyValue -Object $publicTesterGatewayReport -Name "capRejected"
        routes = Get-PropertyValue -Object $publicTesterGatewayReport -Name "routes" -Default @()
        envValuesPrinted = Get-PropertyValue -Object $publicTesterGatewayReport -Name "envValuesPrinted"
        noSecrets = Get-PropertyValue -Object $publicTesterGatewayReport -Name "noSecrets"
    }
    missingEnvNames = @($missingEnvNames)
    reportPaths = [ordered]@{
        serviceStatus = $serviceStatusReportPath
        liveInfra = $liveInfraReportPath
        liveProduct = $liveProductReportPath
        testerNetwork = $testerNetworkReportPath
        publicTesterGateway = $publicTesterGatewayReportPath
        externalTesterReadiness = $reportFullPath
    }
    refresh = [ordered]@{
        serviceStatusExitCode = $serviceExitCode
        liveInfraExitCode = $liveInfraRefresh.exitCode
        liveInfraOutputRedactedTail = @($liveInfraRefresh.outputRedactedTail)
        testerNetworkRefreshPerformed = $testerNetworkRefreshPerformed
        testerNetworkFreshBeforeRefresh = $testerNetworkFreshBefore
        testerNetworkPacketSmokeBeforeRefresh = $testerNetworkPacketSmokeBefore
        testerNetworkFreshAfterRefresh = $testerNetworkFresh
        testerNetworkPacketSmokeAfterRefresh = $testerNetworkPacketSmokeValidated
        testerNetworkRefreshExitCode = $testerNetworkRefresh.exitCode
        testerNetworkRefreshOutputRedactedTail = @($testerNetworkRefresh.outputRedactedTail)
        publicTesterGatewayRefreshPerformed = $publicTesterGatewayRefreshPerformed
        publicTesterGatewayFreshBeforeRefresh = $publicTesterGatewayFreshBefore
        publicTesterGatewayReadyBeforeRefresh = $publicTesterGatewayReadyBefore
        publicTesterGatewayFreshAfterRefresh = $publicTesterGatewayFresh
        publicTesterGatewayReadyAfterRefresh = $publicTesterGatewayReady
        publicTesterGatewayRefreshExitCode = $publicTesterGatewayRefresh.exitCode
        publicTesterGatewayRefreshOutputRedactedTail = @($publicTesterGatewayRefresh.outputRedactedTail)
    }
    ownerNextActions = @(
        "Configure the FLOWCHAIN_RPC_* public RPC and backup env names in the service environment.",
        "Configure FLOWCHAIN_TESTER_WRITE_ENABLED, FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256, and FLOWCHAIN_TESTER_MAX_SEND_UNITS before public friends-and-family wallet writes.",
        "Configure the FLOWCHAIN_BASE8453_* and FLOWCHAIN_PILOT_* bridge env names after owner verification.",
        "Rerun npm run flowchain:live-infra:check, npm run flowchain:tester:gateway:e2e, and npm run flowchain:tester:readiness before sharing the network externally."
    )
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $true
}

$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "external tester readiness report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

Write-Host "FlowChain external tester readiness status: $status"
Write-Host "Local tester rehearsal ready: $localTesterRehearsalReady"
Write-Host "External sharing ready: $externalSharingReady"
Write-Host "Report: $reportFullPath"
if ($missingEnvNames.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnvNames)) -join ', ')"
}
if ($status -eq "passed" -or ($status -eq "blocked" -and $AllowBlocked)) {
    exit 0
}
exit 1
