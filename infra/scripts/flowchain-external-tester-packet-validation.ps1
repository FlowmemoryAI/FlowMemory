param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/external-tester-packet-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/EXTERNAL_TESTER_PACKET_VALIDATION.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

$paths = [ordered]@{
    packetScript = Join-Path $repoRoot "infra/scripts/flowchain-external-tester-packet.ps1"
    readinessScript = Join-Path $repoRoot "infra/scripts/flowchain-external-tester-readiness.ps1"
    packageJson = Join-Path $repoRoot "package.json"
    packetReport = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
    packetMarkdown = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/EXTERNAL_TESTER_PACKET.md"
    connectPack = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-connect-pack.json"
    testerNetworkReport = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json"
    publicTesterGatewayReport = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json"
    ownerInputsReport = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
}

function Get-ValidationProp {
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

function Test-ValidationTextHasAll {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string[]] $Tokens
    )

    foreach ($token in $Tokens) {
        if ($Text.IndexOf($token, [System.StringComparison]::Ordinal) -lt 0) {
            return $false
        }
    }
    return $true
}

function Test-ValidationArrayContainsAll {
    param(
        [AllowNull()][object[]] $Values,
        [Parameter(Mandatory = $true)][string[]] $Expected
    )

    $actual = @($Values | ForEach-Object { "$_" })
    foreach ($item in $Expected) {
        if ($actual -notcontains $item) {
            return $false
        }
    }
    return $true
}

function Test-PackageScript {
    param([Parameter(Mandatory = $true)][string] $Name)

    $packageJson = Get-Content -Raw -LiteralPath $paths.packageJson | ConvertFrom-Json
    return $packageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Test-AllChecksTrue {
    param(
        [AllowNull()][object] $Checks,
        [Parameter(Mandatory = $true)][string[]] $Names
    )

    foreach ($name in $Names) {
        if ((Get-ValidationProp -Object $Checks -Name $name -Default $false) -ne $true) {
            return $false
        }
    }
    return $true
}

$packetOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $paths.packetScript -AllowBlocked 2>&1
$packetExitCode = $LASTEXITCODE
$packetOutputText = @($packetOutput | ForEach-Object { "$_" }) -join "`n"

$packetReport = Read-FlowChainJsonIfExists -Path $paths.packetReport
$connectPack = Read-FlowChainJsonIfExists -Path $paths.connectPack
$testerNetwork = Read-FlowChainJsonIfExists -Path $paths.testerNetworkReport
$publicTesterGateway = Read-FlowChainJsonIfExists -Path $paths.publicTesterGatewayReport
$ownerInputs = Read-FlowChainJsonIfExists -Path $paths.ownerInputsReport
$packetText = if (Test-Path -LiteralPath $paths.packetMarkdown) { Get-Content -Raw -LiteralPath $paths.packetMarkdown } else { "" }
$connectPackText = if (Test-Path -LiteralPath $paths.connectPack) { Get-Content -Raw -LiteralPath $paths.connectPack } else { "" }

$optionalMissingEnvNames = @(
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK"
)
$requiredReadOnlyRoutes = @(
    "/health",
    "/rpc/discover",
    "/rpc/readiness",
    "/chain/status",
    "/explorer/summary",
    "/wallets/balances",
    "/wallets/transfers",
    "/tester/status"
)
$requiredPacketSmokeReadOnlyRoutes = @(
    "/health",
    "/rpc/discover",
    "/rpc/readiness",
    "/chain/status",
    "/wallets/balances",
    "/wallets/transfers",
    "/tester/status"
)
$requiredTesterWriteRoutes = @(
    "/tester/wallets/create",
    "/tester/faucet",
    "/tester/wallets/send"
)
$requiredPacketSmokeChecks = @(
    "health",
    "rpcDiscover",
    "rpcReadiness",
    "chainStatus",
    "walletCreate",
    "walletBalances",
    "walletSend",
    "walletTransfers",
    "testerStatus",
    "testerWalletCreate",
    "testerFaucet",
    "testerWalletSend",
    "testerCapRejected"
)
$requiredConnectPackChecks = @(
    "connectPackWritten",
    "connectPackSchemaValid",
    "connectPackHasNetworkProfile",
    "connectPackHasRpcPlaceholder",
    "connectPackHasTesterTokenPlaceholder",
    "connectPackHasReadOnlyRoutes",
    "connectPackHasTesterWriteRoutes",
    "connectPackShareableMatchesPacket",
    "connectPackNoConcreteUrl",
    "connectPackNoSecrets",
    "connectPackBroadcastsFalse"
)

$packetStatus = [string](Get-ValidationProp -Object $packetReport -Name "status" -Default "missing")
$packetShareable = (Get-ValidationProp -Object $packetReport -Name "packetShareable" -Default $true) -eq $true
$connectPackShareable = (Get-ValidationProp -Object $packetReport -Name "connectPackShareable" -Default $true) -eq $true
$externalSharingReady = (Get-ValidationProp -Object $packetReport -Name "externalSharingReady" -Default $true) -eq $true
$packetExecutableSmokeValidated = (Get-ValidationProp -Object $packetReport -Name "packetExecutableSmokeValidated" -Default $false) -eq $true
$localTesterRehearsalReady = (Get-ValidationProp -Object $packetReport -Name "localTesterRehearsalReady" -Default $false) -eq $true
$packetSmokeChecks = Get-ValidationProp -Object $packetReport -Name "packetSmokeChecks"
$connectPackChecks = Get-ValidationProp -Object $packetReport -Name "connectPackChecks"
$packetSmokeRoutes = @((Get-ValidationProp -Object $packetReport -Name "packetSmokeRoutes" -Default @()))
$missingEnvNames = @((Get-ValidationProp -Object $packetReport -Name "missingEnvNames" -Default @()))
$currentOwnerMissingEnvNames = @((Get-ValidationProp -Object $ownerInputs -Name "missingEnvNames" -Default @()) | Where-Object { $_ -notin $optionalMissingEnvNames } | ForEach-Object { "$_" })
$connectPackNetwork = Get-ValidationProp -Object $connectPack -Name "network"
$connectPackEndpoints = Get-ValidationProp -Object $connectPack -Name "endpoints"
$connectPackBlockingEnvNames = @((Get-ValidationProp -Object $connectPack -Name "blockingEnvNames" -Default @()))
$readOnlyRoutes = @((Get-ValidationProp -Object $connectPackEndpoints -Name "readOnlyRoutes" -Default @()))
$testerWriteRoutes = @((Get-ValidationProp -Object $connectPackEndpoints -Name "testerWriteRoutes" -Default @()))
$testerGatewayRoutes = @((Get-ValidationProp -Object $publicTesterGateway -Name "routes" -Default @()))

$secretMarkerFindings = New-Object System.Collections.ArrayList
foreach ($entry in @(
        [ordered]@{ label = "packet output"; text = $packetOutputText },
        [ordered]@{ label = "packet markdown"; text = $packetText },
        [ordered]@{ label = "connect pack"; text = $connectPackText }
    )) {
    try {
        Assert-FlowChainNoSecretText -Text ([string] $entry.text) -Label ([string] $entry.label)
    }
    catch {
        [void] $secretMarkerFindings.Add([ordered]@{ label = $entry.label; reason = $_.Exception.Message })
    }
}

$checks = [ordered]@{
    packageScriptPacketPresent = Test-PackageScript -Name "flowchain:external-tester:packet"
    packageScriptValidationPresent = Test-PackageScript -Name "flowchain:external-tester:packet:validate"
    packetScriptExists = Test-Path -LiteralPath $paths.packetScript
    readinessScriptExists = Test-Path -LiteralPath $paths.readinessScript
    testerNetworkReportExists = Test-Path -LiteralPath $paths.testerNetworkReport
    publicTesterGatewayReportExists = Test-Path -LiteralPath $paths.publicTesterGatewayReport
    packetCommandAllowsBlocked = $packetExitCode -eq 0
    packetReportWritten = Test-Path -LiteralPath $paths.packetReport
    packetMarkdownWritten = Test-Path -LiteralPath $paths.packetMarkdown
    connectPackWritten = Test-Path -LiteralPath $paths.connectPack
    packetStatusBlockedUntilOwnerInputs = $packetStatus -eq "blocked"
    packetShareableFalseWithoutOwnerInputs = $packetShareable -eq $false
    connectPackShareableFalseWithoutOwnerInputs = $connectPackShareable -eq $false
    externalSharingReadyFalse = $externalSharingReady -eq $false
    localTesterRehearsalReady = $localTesterRehearsalReady -eq $true
    packetExecutableSmokeValidated = $packetExecutableSmokeValidated -eq $true
    testerNetworkReportPassed = (Get-ValidationProp -Object $testerNetwork -Name "status" -Default "missing") -eq "passed"
    publicTesterGatewayReportPassed = (Get-ValidationProp -Object $publicTesterGateway -Name "status" -Default "missing") -eq "passed"
    publicTesterGatewayRoutesCovered = Test-ValidationArrayContainsAll -Values $testerGatewayRoutes -Expected @("/tester/status", "/tester/wallets/create", "/tester/faucet", "/tester/wallets/send")
    publicTesterGatewayCapRejected = (Get-ValidationProp -Object $publicTesterGateway -Name "capRejected" -Default $false) -eq $true
    packetSmokeChecksAllTrue = Test-AllChecksTrue -Checks $packetSmokeChecks -Names $requiredPacketSmokeChecks
    packetSmokeRoutesCoverReadOnly = Test-ValidationArrayContainsAll -Values $packetSmokeRoutes -Expected $requiredPacketSmokeReadOnlyRoutes
    packetSmokeRoutesCoverTesterWrites = Test-ValidationArrayContainsAll -Values $packetSmokeRoutes -Expected $requiredTesterWriteRoutes
    connectPackChecksAllTrue = Test-AllChecksTrue -Checks $connectPackChecks -Names $requiredConnectPackChecks
    connectPackSchemaValid = (Get-ValidationProp -Object $connectPack -Name "schema" -Default "") -eq "flowchain.external_tester_connect_pack.v0"
    connectPackStatusMatchesReport = (Get-ValidationProp -Object $connectPack -Name "status" -Default "") -eq $packetStatus
    connectPackShareableMatchesReport = ((Get-ValidationProp -Object $connectPack -Name "shareable" -Default $null) -eq $packetShareable)
    connectPackHasChainId = -not [string]::IsNullOrWhiteSpace([string](Get-ValidationProp -Object $connectPackNetwork -Name "chainId" -Default ""))
    connectPackHasEndpointPlaceholders = Test-ValidationTextHasAll -Text $connectPackText -Tokens @("<OWNER_PUBLIC_ENDPOINT>/rpc", "<OWNER_TESTER_WRITE_TOKEN>")
    connectPackHasNoConcreteUrl = $connectPackText -notmatch 'https?://'
    connectPackReadOnlyRoutesCovered = Test-ValidationArrayContainsAll -Values $readOnlyRoutes -Expected $requiredReadOnlyRoutes
    connectPackTesterWriteRoutesCovered = Test-ValidationArrayContainsAll -Values $testerWriteRoutes -Expected $requiredTesterWriteRoutes
    packetMarkdownWarnsNotShareable = $packetText.Contains("Do not share this network externally yet.")
    packetMarkdownHasConnectionProfile = $packetText.Contains("external-tester-connect-pack.json")
    packetMarkdownHasEndpointChecks = Test-ValidationTextHasAll -Text $packetText -Tokens @("/health", "/rpc/discover", "/rpc/readiness", "/chain/status", "/tester/status")
    packetMarkdownHasWalletFlow = Test-ValidationTextHasAll -Text $packetText -Tokens @("/tester/wallets/create", "/tester/faucet", "/tester/wallets/send", "/wallets/transfers")
    packetMarkdownListsOwnerCommands = Test-ValidationTextHasAll -Text $packetText -Tokens @("flowchain:owner-inputs", "flowchain:owner-env:readiness", "flowchain:live-infra:check", "flowchain:completion:audit")
    requiredOwnerEnvNamesListed = $missingEnvNames.Count -gt 0 `
        -and (Test-ValidationArrayContainsAll -Values $missingEnvNames -Expected $currentOwnerMissingEnvNames) `
        -and (Test-ValidationArrayContainsAll -Values $currentOwnerMissingEnvNames -Expected $missingEnvNames) `
        -and (Test-ValidationArrayContainsAll -Values $connectPackBlockingEnvNames -Expected $missingEnvNames) `
        -and (Test-ValidationTextHasAll -Text $packetText -Tokens $missingEnvNames)
    envValuesPrintedFalse = (Get-ValidationProp -Object $packetReport -Name "envValuesPrinted" -Default $true) -eq $false
    noSecrets = (Get-ValidationProp -Object $packetReport -Name "noSecrets" -Default $false) -eq $true
    broadcastsFalse = (Get-ValidationProp -Object $packetReport -Name "broadcasts" -Default $true) -eq $false
    secretMarkerFindingsEmpty = $secretMarkerFindings.Count -eq 0
    packetReportInsideRepo = (Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path $paths.packetReport) -eq $paths.packetReport
    connectPackInsideRepo = (Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path $paths.connectPack) -eq $paths.connectPack
    packetMarkdownInsideRepo = (Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path $paths.packetMarkdown) -eq $paths.packetMarkdown
}

$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report = [ordered]@{
    schema = "flowchain.external_tester_packet_validation_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    packetStatus = $packetStatus
    packetShareable = $packetShareable
    connectPackShareable = $connectPackShareable
    externalSharingReady = $externalSharingReady
    packetExecutableSmokeValidated = $packetExecutableSmokeValidated
    checks = $checks
    failedChecks = @($failedChecks)
    secretMarkerFindings = @($secretMarkerFindings)
    missingEnvNames = @($missingEnvNames)
    reportPaths = $paths
    packetCommandExitCode = $packetExitCode
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 14
Assert-FlowChainNoSecretText -Text $reportText -Label "external tester packet validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 14

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain External Tester Packet Validation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This validation proves the friends-and-family tester packet and machine-readable connect pack are generated, no-secret, executable against the local tester gateway, and fail closed until owner public RPC and tester-write inputs exist.")
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): $($entry.Value)")
}
$markdownLines.Add("")
$markdownLines.Add("## Artifacts")
$markdownLines.Add("")
$markdownLines.Add("- Packet: docs/agent-runs/live-product-infra-rpc/EXTERNAL_TESTER_PACKET.md")
$markdownLines.Add("- Connect pack: docs/agent-runs/live-product-infra-rpc/external-tester-connect-pack.json")
$markdownLines.Add("- Report: docs/agent-runs/live-product-infra-rpc/external-tester-packet-validation-report.json")
$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "external tester packet validation markdown"
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain external tester packet validation status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($failedChecks.Count -gt 0) {
    throw "FlowChain external tester packet validation failed checks: $($failedChecks -join ', ')"
}
