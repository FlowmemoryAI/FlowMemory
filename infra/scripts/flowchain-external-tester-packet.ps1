param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json",
    [string] $PacketPath = "docs/agent-runs/live-product-infra-rpc/EXTERNAL_TESTER_PACKET.md",
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$packetFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $PacketPath)

$readinessReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
$testerNetworkReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json"
$ownerInputsReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
$completionAuditReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json"

function Get-PacketProp {
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

function Add-UniquePacketName {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [object] $Value
    )

    $name = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($name) -and -not $Target.Contains($name)) {
        [void] $Target.Add($name)
    }
}

$readinessOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-external-tester-readiness.ps1") -AllowBlocked 2>&1
$readinessExitCode = $LASTEXITCODE
$ownerInputsOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-owner-inputs.ps1") -AllowBlocked 2>&1
$ownerInputsExitCode = $LASTEXITCODE

$readiness = Read-FlowChainJsonIfExists -Path $readinessReportPath
$testerNetwork = Read-FlowChainJsonIfExists -Path $testerNetworkReportPath
$ownerInputs = Read-FlowChainJsonIfExists -Path $ownerInputsReportPath
$completionAudit = Read-FlowChainJsonIfExists -Path $completionAuditReportPath

$readinessStatus = [string](Get-PacketProp -Object $readiness -Name "status" -Default "missing")
$ownerInputsStatus = [string](Get-PacketProp -Object $ownerInputs -Name "status" -Default "missing")
$completionStatus = [string](Get-PacketProp -Object $completionAudit -Name "status" -Default "missing")
$externalSharingReady = Get-PacketProp -Object $readiness -Name "externalSharingReady" -Default $false
$localTesterRehearsalReady = Get-PacketProp -Object $readiness -Name "localTesterRehearsalReady" -Default $false
$latestHeight = [string](Get-PacketProp -Object $readiness -Name "latestHeight" -Default "")
$readinessChecks = Get-PacketProp -Object $readiness -Name "checks"
$packetExecutableSmokeValidated = (Get-PacketProp -Object $readinessChecks -Name "packetExecutableSmokeValidated" -Default $false) -eq $true `
    -and (Get-PacketProp -Object $testerNetwork -Name "packetExecutableSmokeValidated" -Default $false) -eq $true
$packetSmokeRoutes = @(Get-PacketProp -Object $testerNetwork -Name "packetSmokeRoutes" -Default @())
$packetSmokeChecks = Get-PacketProp -Object $testerNetwork -Name "packetSmokeChecks"

$missingEnvNames = New-Object System.Collections.ArrayList
foreach ($source in @($readiness, $ownerInputs, $completionAudit)) {
    foreach ($name in @((Get-PacketProp -Object $source -Name "missingEnvNames" -Default @()))) {
        Add-UniquePacketName -Target $missingEnvNames -Value $name
    }
}
foreach ($name in @((Get-PacketProp -Object $ownerInputs -Name "invalidEnvNames" -Default @()))) {
    Add-UniquePacketName -Target $missingEnvNames -Value $name
}

$failed = $readinessExitCode -ne 0 -or $ownerInputsExitCode -ne 0 -or $readinessStatus -eq "failed" -or $ownerInputsStatus -eq "failed" -or -not $packetExecutableSmokeValidated
$packetShareable = $externalSharingReady -eq $true -and $readinessStatus -eq "passed" -and $ownerInputsStatus -eq "passed" -and $packetExecutableSmokeValidated
$status = if ($failed) { "failed" } elseif ($packetShareable) { "passed" } else { "blocked" }
$generatedAt = (Get-Date).ToUniversalTime().ToString("o")

$packetLines = New-Object System.Collections.Generic.List[string]
$packetLines.Add("# FlowChain External Tester Packet")
$packetLines.Add("")
$packetLines.Add("Generated: $generatedAt")
$packetLines.Add("Status: $status")
$packetLines.Add("Shareable externally: $packetShareable")
$packetLines.Add("Latest observed height: $latestHeight")
$packetLines.Add("")
if ($packetShareable) {
    $packetLines.Add("The live infrastructure gates have passed. The owner should distribute the public endpoint out of band; do not commit endpoint values into this repo.")
}
else {
    $packetLines.Add("Do not share this network externally yet. Local wallet rehearsal is available, but external sharing remains blocked until the listed owner input names and live infrastructure gates pass.")
}
$packetLines.Add("")
$packetLines.Add("## Tester Scope")
$packetLines.Add("")
$packetLines.Add("- Use pilot test units only.")
$packetLines.Add("- Create a fresh test wallet through the service.")
$packetLines.Add("- Wait for a bridge credit or owner-funded pilot balance before sending.")
$packetLines.Add("- Send a small transfer to another tester and confirm it appears after new blocks are produced.")
$packetLines.Add("- Do not reuse passwords from other services.")
$packetLines.Add("- Do not send Base mainnet funds unless the owner has separately confirmed the bridge pilot is active and capped.")
$packetLines.Add("")
$packetLines.Add("## Endpoint Checks")
$packetLines.Add("")
$packetLines.Add("Replace <OWNER_PUBLIC_ENDPOINT> with the endpoint distributed by the owner outside this repository.")
$packetLines.Add("")
$packetLines.Add('```powershell')
$packetLines.Add("Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/health'")
$packetLines.Add("Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/rpc/discover'")
$packetLines.Add("Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/rpc/readiness'")
$packetLines.Add("Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/chain/status'")
$packetLines.Add('```')
$packetLines.Add("")
$packetLines.Add("## Wallet Flow")
$packetLines.Add("")
$packetLines.Add('```powershell')
$packetLines.Add('$createBody = @{ label = "tester-one"; password = "<fresh-test-password>" } | ConvertTo-Json')
$packetLines.Add("Invoke-RestMethod -Method Post -Uri '<OWNER_PUBLIC_ENDPOINT>/wallets/create' -ContentType 'application/json' -Body `$createBody")
$packetLines.Add("Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/wallets/balances'")
$packetLines.Add('$sendBody = @{ from = "<sender-account-id>"; to = "<recipient-account-id>"; amountUnits = "1"; memo = "external-tester-pilot"; applyBlock = $false; createRecipient = $false } | ConvertTo-Json')
$packetLines.Add("Invoke-RestMethod -Method Post -Uri '<OWNER_PUBLIC_ENDPOINT>/wallets/send' -ContentType 'application/json' -Body `$sendBody")
$packetLines.Add("Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/wallets/transfers'")
$packetLines.Add('```')
$packetLines.Add("")
$packetLines.Add("## Current Gate Evidence")
$packetLines.Add("")
$packetLines.Add("- External tester readiness: $readinessStatus")
$packetLines.Add("- Owner inputs: $ownerInputsStatus")
$packetLines.Add("- Completion audit: $completionStatus")
$packetLines.Add("- Local tester rehearsal ready: $localTesterRehearsalReady")
$packetLines.Add("- External sharing ready: $externalSharingReady")
$packetLines.Add("- Packet executable smoke validated: $packetExecutableSmokeValidated")
$packetLines.Add("")
if ($missingEnvNames.Count -gt 0) {
    $packetLines.Add("## Blocking Env Names")
    $packetLines.Add("")
    foreach ($name in @($missingEnvNames)) {
        $packetLines.Add("- $name")
    }
    $packetLines.Add("")
}
$packetLines.Add("## Owner Verification Commands")
$packetLines.Add("")
$packetLines.Add("- npm run flowchain:owner-inputs")
$packetLines.Add("- npm run flowchain:owner-env:readiness -- -AllowBlocked")
$packetLines.Add("- npm run flowchain:live-infra:check")
$packetLines.Add("- npm run flowchain:tester:readiness")
$packetLines.Add("- npm run flowchain:completion:audit")
$packetLines.Add("- npm run flowchain:live-product:e2e")

$packetText = $packetLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $packetText -Label "external tester packet"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $packetFullPath) | Out-Null
Set-Content -LiteralPath $packetFullPath -Value $packetText -Encoding UTF8

$report = [ordered]@{
    schema = "flowchain.external_tester_packet_report.v0"
    generatedAt = $generatedAt
    status = $status
    packetShareable = $packetShareable
    packetPath = $packetFullPath
    latestHeight = $latestHeight
    readinessStatus = $readinessStatus
    ownerInputsStatus = $ownerInputsStatus
    completionAuditStatus = $completionStatus
    localTesterRehearsalReady = $localTesterRehearsalReady
    externalSharingReady = $externalSharingReady
    packetExecutableSmokeValidated = $packetExecutableSmokeValidated
    packetSmokeChecks = $packetSmokeChecks
    packetSmokeRoutes = $packetSmokeRoutes
    missingEnvNames = @($missingEnvNames)
    reportPaths = [ordered]@{
        readiness = $readinessReportPath
        testerNetwork = $testerNetworkReportPath
        ownerInputs = $ownerInputsReportPath
        completionAudit = $completionAuditReportPath
        packet = $packetFullPath
    }
    readinessCommandExitCode = $readinessExitCode
    ownerInputsCommandExitCode = $ownerInputsExitCode
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 14
Assert-FlowChainNoSecretText -Text $reportText -Label "external tester packet report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 14

Write-Host "FlowChain external tester packet status: $status"
Write-Host "Shareable externally: $packetShareable"
Write-Host "Report: $reportFullPath"
Write-Host "Packet: $packetFullPath"
if ($missingEnvNames.Count -gt 0) {
    Write-Host "Missing or invalid env names: $($missingEnvNames -join ', ')"
}

if ($status -eq "passed" -or ($status -eq "blocked" -and $AllowBlocked)) {
    exit 0
}
exit 1
