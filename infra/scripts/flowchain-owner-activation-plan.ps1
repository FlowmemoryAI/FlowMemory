param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/owner-activation-plan-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OWNER_ACTIVATION_PLAN.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

$requiredOwnerEnvNames = @(
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
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS"
)
$optionalOwnerEnvNames = @(
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK"
)
$knownOwnerEnvNames = @($requiredOwnerEnvNames + $optionalOwnerEnvNames)

$paths = [ordered]@{
    serviceStatus = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
    ownerInputs = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
    ownerSignupChecklist = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-signup-checklist-report.json"
    ownerEnvReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-report.json"
    publicRpc = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    backup = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    bridgeLive = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    externalTester = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    externalTesterPacket = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
    publicDeploymentContract = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
    completionAudit = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json"
    truthTable = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json"
}

function Get-ActivationProp {
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

function Get-ActivationStatus {
    param([AllowNull()][object] $Report)

    if ($null -eq $Report) {
        return "missing"
    }
    return [string](Get-ActivationProp -Object $Report -Name "status" -Default "unknown")
}

function Add-ActivationUnique {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [AllowNull()][object] $Value
    )

    $text = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($text) -and -not $Target.Contains($text)) {
        [void] $Target.Add($text)
    }
}

function Get-ActivationSecretMarkerFindings {
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

function New-ActivationStage {
    param(
        [Parameter(Mandatory = $true)][string] $Id,
        [Parameter(Mandatory = $true)][string] $Title,
        [Parameter(Mandatory = $true)][string[]] $RequiredEnvNames,
        [string[]] $OptionalEnvNames = @(),
        [Parameter(Mandatory = $true)][string[]] $ValidationCommands,
        [Parameter(Mandatory = $true)][string[]] $OwnerMustDo,
        [Parameter(Mandatory = $true)][string[]] $OwnerMustNotSend,
        [Parameter(Mandatory = $true)][string[]] $SourceReports,
        [string[]] $ExternalAccountsOrResources = @(),
        [string[]] $ReadyStatuses = @("passed")
    )

    $stageMissing = @($RequiredEnvNames | Where-Object { $_ -in @($script:MissingEnvNames) })
    $stageInvalid = @($RequiredEnvNames | Where-Object { $_ -in @($script:InvalidEnvNames) })
    $reportStatuses = New-Object System.Collections.ArrayList
    foreach ($reportName in @($SourceReports)) {
        if ($script:Reports.Contains($reportName)) {
            [void] $reportStatuses.Add([ordered]@{
                name = $reportName
                status = Get-ActivationStatus -Report $script:Reports[$reportName]
                path = $script:Paths[$reportName]
            })
        }
    }

    $reportsReady = @($reportStatuses | Where-Object { $_.status -notin $ReadyStatuses }).Count -eq 0
    $stageStatus = if ($stageInvalid.Count -gt 0) {
        "invalid-owner-input"
    }
    elseif ($stageMissing.Count -gt 0) {
        "needs-owner-input"
    }
    elseif ($reportsReady) {
        "ready"
    }
    else {
        "needs-validation"
    }

    return [ordered]@{
        id = $Id
        title = $Title
        status = $stageStatus
        ready = $stageStatus -eq "ready"
        requiredEnvNames = @($RequiredEnvNames)
        optionalEnvNames = @($OptionalEnvNames)
        missingEnvNames = @($stageMissing)
        invalidEnvNames = @($stageInvalid)
        externalAccountsOrResources = @($ExternalAccountsOrResources)
        ownerMustDo = @($OwnerMustDo)
        ownerMustNotSend = @($OwnerMustNotSend)
        validationCommands = @($ValidationCommands)
        sourceReports = @($reportStatuses)
    }
}

$script:Paths = $paths
$script:Reports = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    $script:Reports[$entry.Key] = Read-FlowChainJsonIfExists -Path $entry.Value
}

$script:MissingEnvNames = New-Object System.Collections.ArrayList
$script:InvalidEnvNames = New-Object System.Collections.ArrayList
foreach ($report in $script:Reports.Values) {
    foreach ($name in @((Get-ActivationProp -Object $report -Name "missingEnvNames" -Default @()))) {
        Add-ActivationUnique -Target $script:MissingEnvNames -Value $name
    }
    foreach ($name in @((Get-ActivationProp -Object $report -Name "invalidEnvNames" -Default @()))) {
        Add-ActivationUnique -Target $script:InvalidEnvNames -Value $name
    }
}
$ownerInputValidNames = @((Get-ActivationProp -Object $script:Reports.ownerInputs -Name "inputs" -Default @()) | Where-Object {
        (Get-ActivationProp -Object $_ -Name "present" -Default $false) -eq $true `
            -and (Get-ActivationProp -Object $_ -Name "valid" -Default $false) -eq $true
    } | ForEach-Object {
        [string](Get-ActivationProp -Object $_ -Name "name" -Default "")
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$filteredMissingEnvNames = New-Object System.Collections.ArrayList
foreach ($name in @($script:MissingEnvNames)) {
    if ($name -notin $ownerInputValidNames) {
        Add-ActivationUnique -Target $filteredMissingEnvNames -Value $name
    }
}
$filteredInvalidEnvNames = New-Object System.Collections.ArrayList
foreach ($name in @($script:InvalidEnvNames)) {
    if ($name -notin $ownerInputValidNames) {
        Add-ActivationUnique -Target $filteredInvalidEnvNames -Value $name
    }
}
$script:MissingEnvNames = $filteredMissingEnvNames
$script:InvalidEnvNames = $filteredInvalidEnvNames

$serviceReady = (Get-ActivationStatus -Report $script:Reports.serviceStatus) -eq "passed"
$ownerEnvFile = Get-ActivationProp -Object $script:Reports.ownerEnvReadiness -Name "ownerEnvFile"
$ownerEnvFileUsable = ((Get-ActivationProp -Object $ownerEnvFile -Name "exists" -Default $false) -eq $true) `
    -and ((Get-ActivationProp -Object $ownerEnvFile -Name "isFile" -Default $false) -eq $true) `
    -and ((Get-ActivationProp -Object $ownerEnvFile -Name "gitIgnored" -Default $false) -eq $true)

$stages = @(
    [ordered]@{
        id = "always-on-service-host"
        title = "Keep the chain and private RPC running"
        status = if ($serviceReady) { "ready" } else { "needs-validation" }
        ready = $serviceReady
        requiredEnvNames = @()
        optionalEnvNames = @()
        missingEnvNames = @()
        invalidEnvNames = @()
        externalAccountsOrResources = @("Always-on Windows host, Linux host, or VPS")
        ownerMustDo = @("Choose the host that will stay online and keep the FlowChain node/control-plane running.")
        ownerMustNotSend = @("Host login password", "SSH private key")
        validationCommands = @("npm run flowchain:service:status -- -AllowBlocked", "npm run flowchain:service:monitor")
        sourceReports = @([ordered]@{ name = "serviceStatus"; status = Get-ActivationStatus -Report $script:Reports.serviceStatus; path = $paths.serviceStatus })
    },
    [ordered]@{
        id = "owner-env-file"
        title = "Fill the ignored local owner env file"
        status = if ($ownerEnvFileUsable) { "ready" } else { "needs-validation" }
        ready = $ownerEnvFileUsable
        requiredEnvNames = @("FLOWCHAIN_OWNER_ENV_FILE")
        optionalEnvNames = @()
        missingEnvNames = @()
        invalidEnvNames = @()
        externalAccountsOrResources = @("Local ignored env file or service environment")
        ownerMustDo = @("Run the template command, fill real values only on the launch host, and point FLOWCHAIN_OWNER_ENV_FILE at that file.")
        ownerMustNotSend = @("Owner env file contents", "Provider URLs that carry account tokens")
        validationCommands = @("npm run flowchain:owner-env:template", "npm run flowchain:owner-env:readiness:validate", "npm run flowchain:owner-env:readiness -- -AllowBlocked")
        sourceReports = @([ordered]@{ name = "ownerEnvReadiness"; status = Get-ActivationStatus -Report $script:Reports.ownerEnvReadiness; path = $paths.ownerEnvReadiness })
    },
    (New-ActivationStage `
        -Id "public-rpc-edge" `
        -Title "Expose repo-owned FlowChain RPC through a public HTTPS edge" `
        -RequiredEnvNames @("FLOWCHAIN_RPC_PUBLIC_URL", "FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "FLOWCHAIN_RPC_TLS_TERMINATED") `
        -ValidationCommands @("npm run flowchain:public-rpc:check -- -AllowBlocked", "npm run flowchain:public-rpc:validate", "npm run flowchain:public-rpc:abuse-test") `
        -OwnerMustDo @("Create DNS or a tunnel hostname for the FlowChain RPC edge.", "Terminate TLS at the edge.", "Set exact allowed browser origins and a positive per-minute rate limit.") `
        -OwnerMustNotSend @("Registrar password", "tunnel token", "TLS private key") `
        -ExternalAccountsOrResources @("DNS provider or existing domain", "TLS edge, reverse proxy, or tunnel") `
        -SourceReports @("publicRpc", "publicDeploymentContract") `
        -ReadyStatuses @("passed")),
    (New-ActivationStage `
        -Id "state-backup-storage" `
        -Title "Provision durable state backup storage" `
        -RequiredEnvNames @("FLOWCHAIN_RPC_STATE_BACKUP_PATH") `
        -ValidationCommands @("npm run flowchain:backup:check -- -AllowBlocked", "npm run flowchain:backup:restore:validate", "npm run flowchain:backup:owner-path:dry-run") `
        -OwnerMustDo @("Create a writable persistent directory available to the FlowChain service process.", "Keep the path local to the launch host or mounted as durable storage.") `
        -OwnerMustNotSend @("Storage account secret", "cloud backup credentials") `
        -ExternalAccountsOrResources @("Persistent local disk, mounted volume, or owner-managed backup directory") `
        -SourceReports @("backup") `
        -ReadyStatuses @("passed")),
    (New-ActivationStage `
        -Id "tester-write-gateway" `
        -Title "Enable capped friends-and-family tester writes" `
        -RequiredEnvNames @("FLOWCHAIN_TESTER_WRITE_ENABLED", "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256", "FLOWCHAIN_TESTER_MAX_SEND_UNITS") `
        -ValidationCommands @("npm run flowchain:tester:token:setup", "npm run flowchain:tester:gateway:e2e", "npm run flowchain:external-tester:packet -- -AllowBlocked", "npm run flowchain:external-tester:packet:validate") `
        -OwnerMustDo @("Run the tester token setup command to create or preserve the raw bearer token in ignored local storage.", "Store only its SHA-256 digest in the owner env file.", "Choose a small positive per-send test-unit cap.") `
        -OwnerMustNotSend @("Raw tester bearer token", "token hash together with the raw token") `
        -ExternalAccountsOrResources @("Owner password manager or secret store") `
        -SourceReports @("externalTester", "externalTesterPacket", "publicDeploymentContract") `
        -ReadyStatuses @("passed")),
    (New-ActivationStage `
        -Id "base8453-bridge-pilot" `
        -Title "Configure capped Base 8453 bridge pilot observation" `
        -RequiredEnvNames @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS") `
        -OptionalEnvNames @("FLOWCHAIN_BASE8453_CURSOR_STATE", "FLOWCHAIN_BASE8453_TO_BLOCK") `
        -ValidationCommands @("npm run flowchain:bridge:live:check -- -AllowBlocked", "npm run flowchain:bridge:infra:check -- -AllowBlocked", "npm run flowchain:bridge:relayer:guardrail:validate", "npm run flowchain:bridge:relayer:loop:validate") `
        -OwnerMustDo @("Provide a Base chain 8453 HTTPS endpoint.", "Provide deployed lockbox and supported-token addresses.", "Choose the bootstrap from-block, confirmations, max deposit, total cap, and explicit capped-pilot acknowledgement.") `
        -OwnerMustNotSend @("Wallet private key", "wallet recovery words", "provider dashboard password") `
        -ExternalAccountsOrResources @("Base RPC provider or owner-operated Base node", "Deployed pilot bridge contract details") `
        -SourceReports @("bridgeLive", "bridgeInfra", "publicDeploymentContract") `
        -ReadyStatuses @("passed")),
    (New-ActivationStage `
        -Id "friends-and-family-launch" `
        -Title "Release the external tester packet only after public gates pass" `
        -RequiredEnvNames $requiredOwnerEnvNames `
        -ValidationCommands @("npm run flowchain:wallet:live-tester:e2e", "npm run flowchain:external-tester:packet -- -AllowBlocked", "npm run flowchain:external-tester:packet:validate", "npm run flowchain:dashboard:ui:readiness") `
        -OwnerMustDo @("Share wallet/tester instructions only after the packet report marks external sharing ready.", "Keep per-send caps low for the first pilot.") `
        -OwnerMustNotSend @("Raw tester token in GitHub or chat", "owner env file contents") `
        -ExternalAccountsOrResources @("Friends-and-family tester list") `
        -SourceReports @("externalTester", "externalTesterPacket", "publicDeploymentContract") `
        -ReadyStatuses @("passed")),
    (New-ActivationStage `
        -Id "final-go-live-audit" `
        -Title "Run final no-secret production audit before public use" `
        -RequiredEnvNames $requiredOwnerEnvNames `
        -ValidationCommands @("npm run flowchain:live:cutover:rehearsal -- -AllowBlocked", "npm run flowchain:completion:audit -- -AllowBlocked", "npm run flowchain:truth-table -- -AllowBlocked", "npm run flowchain:no-secret:scan") `
        -OwnerMustDo @("Run the aggregate gates after all owner values are configured.", "Do not announce public readiness until completionReady is true and the truth table has no owner blockers.") `
        -OwnerMustNotSend @("Any secret-bearing provider URL", "wallet recovery material") `
        -ExternalAccountsOrResources @("None beyond the configured launch resources") `
        -SourceReports @("completionAudit", "truthTable") `
        -ReadyStatuses @("passed"))
)

$coveredRequiredEnvNames = New-Object System.Collections.ArrayList
foreach ($stage in @($stages)) {
    foreach ($name in @($stage.requiredEnvNames)) {
        if ($name -in $requiredOwnerEnvNames) {
            Add-ActivationUnique -Target $coveredRequiredEnvNames -Value $name
        }
    }
}
$missingCoverage = @($requiredOwnerEnvNames | Where-Object { $_ -notin @($coveredRequiredEnvNames) })
$unknownMissingEnvNames = @($script:MissingEnvNames | Where-Object { $_ -notin $knownOwnerEnvNames })
$unknownInvalidEnvNames = @($script:InvalidEnvNames | Where-Object { $_ -notin $knownOwnerEnvNames })
$stagesNeedingOwnerInput = @($stages | Where-Object { $_.status -eq "needs-owner-input" })
$readyStages = @($stages | Where-Object { $_.ready -eq $true })
$activationReady = @($script:MissingEnvNames).Count -eq 0 -and @($script:InvalidEnvNames).Count -eq 0 -and @($stages | Where-Object { $_.ready -ne $true }).Count -eq 0

$checks = [ordered]@{
    stageCountMinimumMet = @($stages).Count -ge 8
    requiredEnvCoverageComplete = $missingCoverage.Count -eq 0
    knownMissingEnvNamesOnly = $unknownMissingEnvNames.Count -eq 0
    invalidEnvNamesEmpty = @($script:InvalidEnvNames).Count -eq 0
    knownInvalidEnvNamesOnly = $unknownInvalidEnvNames.Count -eq 0
    validationCommandsPresent = @($stages | Where-Object { @($_.validationCommands).Count -eq 0 }).Count -eq 0
    ownerMustNotSendPresent = @($stages | Where-Object { @($_.ownerMustNotSend).Count -eq 0 }).Count -eq 0
    externalResourceMappingPresent = @($stages | Where-Object { @($_.externalAccountsOrResources).Count -eq 0 }).Count -eq 0
    serviceStagePresent = @($stages | Where-Object { $_.id -eq "always-on-service-host" }).Count -eq 1
    publicRpcStagePresent = @($stages | Where-Object { $_.id -eq "public-rpc-edge" }).Count -eq 1
    backupStagePresent = @($stages | Where-Object { $_.id -eq "state-backup-storage" }).Count -eq 1
    testerStagePresent = @($stages | Where-Object { $_.id -eq "tester-write-gateway" }).Count -eq 1
    bridgeStagePresent = @($stages | Where-Object { $_.id -eq "base8453-bridge-pilot" }).Count -eq 1
    finalAuditStagePresent = @($stages | Where-Object { $_.id -eq "final-go-live-audit" }).Count -eq 1
    envValuesPrintedFalse = $true
    noSecrets = $true
    broadcastsFalse = $true
    secretMarkerFindingsEmpty = $true
}

$report = [ordered]@{
    schema = "flowchain.owner_activation_plan_report.v0"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    status = "pending"
    activationReady = $activationReady
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    requiredOwnerEnvNames = @($requiredOwnerEnvNames)
    optionalOwnerEnvNames = @($optionalOwnerEnvNames)
    missingEnvNames = @($script:MissingEnvNames)
    invalidEnvNames = @($script:InvalidEnvNames)
    unknownMissingEnvNames = @($unknownMissingEnvNames)
    unknownInvalidEnvNames = @($unknownInvalidEnvNames)
    missingCoverage = @($missingCoverage)
    stageCount = @($stages).Count
    readyStageCount = @($readyStages).Count
    stagesNeedingOwnerInputCount = @($stagesNeedingOwnerInput).Count
    stages = @($stages)
    reportPaths = $paths
    nextCommands = @(
        "npm run flowchain:owner-env:template",
        "npm run flowchain:owner-env:readiness -- -AllowBlocked",
        "npm run flowchain:owner-inputs -- -AllowBlocked",
        "npm run flowchain:public-rpc:check -- -AllowBlocked",
        "npm run flowchain:bridge:live:check -- -AllowBlocked",
        "npm run flowchain:wallet:live-tester:e2e",
        "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked",
        "npm run flowchain:completion:audit -- -AllowBlocked"
    )
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 24
$secretMarkerFindings = @(Get-ActivationSecretMarkerFindings -Text $preliminaryReportText -Label "owner activation plan report")
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $secretMarkerFindings.Count -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report["status"] = $status
$report["checks"] = $checks
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

$reportText = $report | ConvertTo-Json -Depth 24
Assert-FlowChainNoSecretText -Text $reportText -Label "owner activation plan report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 24

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Owner Activation Plan")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Activation ready: $activationReady")
$markdownLines.Add("")
$markdownLines.Add("This plan is the current launch handoff. It records names, statuses, and commands only. Put real values in the ignored owner env file or the service environment; do not paste secrets into chat, GitHub, or generated reports.")
$markdownLines.Add("")
$markdownLines.Add("## Current Missing Owner Inputs")
$markdownLines.Add("")
if (@($script:MissingEnvNames).Count -eq 0) {
    $markdownLines.Add("- None")
}
else {
    foreach ($name in @($script:MissingEnvNames)) {
        $markdownLines.Add("- ``$name``")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Activation Stages")
$markdownLines.Add("")
$markdownLines.Add("| Stage | Status | Missing inputs | Validate with |")
$markdownLines.Add("| --- | --- | --- | --- |")
foreach ($stage in @($stages)) {
    $missing = if (@($stage.missingEnvNames).Count -gt 0) { (@($stage.missingEnvNames) -join ", ") } else { "none" }
    $commands = (@($stage.validationCommands) -join "; ")
    $markdownLines.Add("| $($stage.title.Replace('|','/')) | $($stage.status) | $missing | $commands |")
}
$markdownLines.Add("")
$markdownLines.Add("## Owner Actions")
$markdownLines.Add("")
foreach ($stage in @($stages)) {
    $markdownLines.Add("### $($stage.title)")
    foreach ($action in @($stage.ownerMustDo)) {
        $markdownLines.Add("- $action")
    }
    if (@($stage.externalAccountsOrResources).Count -gt 0) {
        $markdownLines.Add("- Resources: $((@($stage.externalAccountsOrResources)) -join ', ')")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Do Not Send")
$markdownLines.Add("")
$forbidden = New-Object System.Collections.ArrayList
foreach ($stage in @($stages)) {
    foreach ($item in @($stage.ownerMustNotSend)) {
        Add-ActivationUnique -Target $forbidden -Value $item
    }
}
foreach ($item in @($forbidden)) {
    $markdownLines.Add("- $item")
}
$markdownLines.Add("")
$markdownLines.Add("## Next Commands")
$markdownLines.Add("")
foreach ($command in @($report.nextCommands)) {
    $markdownLines.Add("- $command")
}

$markdownText = ($markdownLines -join [Environment]::NewLine) + [Environment]::NewLine
Assert-FlowChainNoSecretText -Text $markdownText -Label "owner activation plan markdown"
$markdownParent = Split-Path -Parent $markdownFullPath
if (-not [string]::IsNullOrWhiteSpace($markdownParent)) {
    New-Item -ItemType Directory -Force -Path $markdownParent | Out-Null
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($markdownFullPath, $markdownText, $utf8NoBom)

Write-Host "FlowChain owner activation plan status: $status"
Write-Host "Activation ready: $activationReady"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if (@($script:MissingEnvNames).Count -gt 0) {
    Write-Host "Missing env names: $($script:MissingEnvNames -join ', ')"
}
if ($status -ne "passed") {
    exit 1
}
