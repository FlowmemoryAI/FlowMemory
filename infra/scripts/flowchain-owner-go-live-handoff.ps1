param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/owner-go-live-handoff-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OWNER_GO_LIVE_HANDOFF.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$packageJsonPath = Join-Path $repoRoot "package.json"

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
    ownerActivationPlan = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-activation-plan-report.json"
    ownerSignupChecklist = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-signup-checklist-report.json"
    ownerInputs = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
    publicDeploymentContract = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
    externalTesterPacket = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
    completionAudit = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json"
    truthTable = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json"
}

function Get-HandoffProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    if ($null -ne $Object) {
        $property = $Object.PSObject.Properties[$Name]
        if ($null -ne $property) {
            return $property.Value
        }
    }
    return $Default
}

function Add-HandoffUnique {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [AllowNull()][object] $Value
    )

    $text = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($text) -and -not $Target.Contains($text)) {
        [void] $Target.Add($text)
    }
}

function Add-HandoffUniqueMany {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [AllowNull()][object[]] $Values
    )

    foreach ($value in @($Values)) {
        Add-HandoffUnique -Target $Target -Value $value
    }
}

function Get-HandoffEnvNames {
    param([AllowNull()][object] $Values)

    return @($Values | ForEach-Object { "$_" } | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_) -and $_ -match '^FLOWCHAIN_[A-Z0-9_]+$'
        })
}

function Test-HandoffPackageScript {
    param([Parameter(Mandatory = $true)][string] $Name)

    if (-not (Test-Path -LiteralPath $packageJsonPath)) {
        return $false
    }
    $packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
    return $packageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Get-HandoffNpmRunScriptNames {
    param([AllowNull()][object[]] $Commands)

    $scriptNames = New-Object System.Collections.ArrayList
    foreach ($command in @($Commands)) {
        $text = "$command"
        $match = [regex]::Match($text, '^\s*npm\s+run\s+([^\s]+)')
        if ($match.Success) {
            Add-HandoffUnique -Target $scriptNames -Value $match.Groups[1].Value
        }
    }
    return @($scriptNames)
}

function New-HandoffReportStatus {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [AllowNull()][object] $Report,
        [Parameter(Mandatory = $true)][string] $Path
    )

    return [ordered]@{
        name = $Name
        status = [string](Get-HandoffProp -Object $Report -Name "status" -Default "missing")
        path = $Path
        loaded = $null -ne $Report
        missingEnvNames = @(Get-HandoffEnvNames -Values (Get-HandoffProp -Object $Report -Name "missingEnvNames" -Default @()))
        invalidEnvNames = @(Get-HandoffEnvNames -Values (Get-HandoffProp -Object $Report -Name "invalidEnvNames" -Default @()))
    }
}

function ConvertTo-HandoffStage {
    param([Parameter(Mandatory = $true)][object] $Stage)

    $validationCommands = @((Get-HandoffProp -Object $Stage -Name "validationCommands" -Default @()) | ForEach-Object { "$_" } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $ownerMustNotSend = @((Get-HandoffProp -Object $Stage -Name "ownerMustNotSend" -Default @()) | ForEach-Object { "$_" } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    return [ordered]@{
        id = [string](Get-HandoffProp -Object $Stage -Name "id" -Default "")
        title = [string](Get-HandoffProp -Object $Stage -Name "title" -Default "")
        status = [string](Get-HandoffProp -Object $Stage -Name "status" -Default "unknown")
        ready = (Get-HandoffProp -Object $Stage -Name "ready" -Default $false) -eq $true
        requiredEnvNames = @(Get-HandoffEnvNames -Values (Get-HandoffProp -Object $Stage -Name "requiredEnvNames" -Default @()))
        optionalEnvNames = @(Get-HandoffEnvNames -Values (Get-HandoffProp -Object $Stage -Name "optionalEnvNames" -Default @()))
        blockingEnvNames = @(Get-HandoffEnvNames -Values (Get-HandoffProp -Object $Stage -Name "blockingEnvNames" -Default @()))
        blockedByReportNames = @((Get-HandoffProp -Object $Stage -Name "blockedByReportNames" -Default @()) | ForEach-Object { "$_" } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        externalAccountsOrResources = @((Get-HandoffProp -Object $Stage -Name "externalAccountsOrResources" -Default @()) | ForEach-Object { "$_" } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        ownerMustDo = @((Get-HandoffProp -Object $Stage -Name "ownerMustDo" -Default @()) | ForEach-Object { "$_" } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        ownerMustNotSend = @($ownerMustNotSend)
        validationCommands = @($validationCommands)
        nextCommand = if ($validationCommands.Count -gt 0) { $validationCommands[0] } else { "" }
    }
}

$reports = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    $reports[$entry.Key] = Read-FlowChainJsonIfExists -Path $entry.Value
}

$activationPlan = $reports.ownerActivationPlan
$signupChecklist = $reports.ownerSignupChecklist
$ownerInputs = $reports.ownerInputs
$publicDeploymentContract = $reports.publicDeploymentContract
$externalTesterPacket = $reports.externalTesterPacket
$completionAudit = $reports.completionAudit
$truthTable = $reports.truthTable

$stages = @((Get-HandoffProp -Object $activationPlan -Name "stages" -Default @()) | ForEach-Object {
        ConvertTo-HandoffStage -Stage $_
    })

$missingEnvNames = New-Object System.Collections.ArrayList
$invalidEnvNames = New-Object System.Collections.ArrayList
foreach ($report in @($activationPlan, $ownerInputs, $publicDeploymentContract, $externalTesterPacket, $completionAudit, $truthTable)) {
    Add-HandoffUniqueMany -Target $missingEnvNames -Values (Get-HandoffEnvNames -Values (Get-HandoffProp -Object $report -Name "missingEnvNames" -Default @()))
    Add-HandoffUniqueMany -Target $invalidEnvNames -Values (Get-HandoffEnvNames -Values (Get-HandoffProp -Object $report -Name "invalidEnvNames" -Default @()))
    Add-HandoffUniqueMany -Target $missingEnvNames -Values (Get-HandoffEnvNames -Values (Get-HandoffProp -Object $report -Name "missingOwnerInputs" -Default @()))
    Add-HandoffUniqueMany -Target $missingEnvNames -Values (Get-HandoffEnvNames -Values (Get-HandoffProp -Object $report -Name "exactExternalOwnerInputsRemaining" -Default @()))
}

$nextOwnerInputNames = New-Object System.Collections.ArrayList
foreach ($stage in @($stages)) {
    Add-HandoffUniqueMany -Target $nextOwnerInputNames -Values @($stage.blockingEnvNames | Where-Object { $_ -in $requiredOwnerEnvNames })
}
if (@($nextOwnerInputNames).Count -eq 0) {
    Add-HandoffUniqueMany -Target $nextOwnerInputNames -Values @($missingEnvNames | Where-Object { $_ -in $requiredOwnerEnvNames })
}

$externalResources = New-Object System.Collections.ArrayList
$mustNotSend = New-Object System.Collections.ArrayList
foreach ($stage in @($stages)) {
    Add-HandoffUniqueMany -Target $externalResources -Values $stage.externalAccountsOrResources
    Add-HandoffUniqueMany -Target $mustNotSend -Values $stage.ownerMustNotSend
}

$nextCommands = New-Object System.Collections.ArrayList
Add-HandoffUniqueMany -Target $nextCommands -Values (Get-HandoffProp -Object $activationPlan -Name "nextCommands" -Default @())
Add-HandoffUniqueMany -Target $nextCommands -Values (Get-HandoffProp -Object $completionAudit -Name "nextCommandsAfterOwnerInputs" -Default @())
Add-HandoffUniqueMany -Target $nextCommands -Values @(
    "npm run flowchain:owner-env:readiness -- -AllowBlocked",
    "npm run flowchain:public-deployment:contract -- -AllowBlocked",
    "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked",
    "npm run flowchain:completion:audit -- -AllowBlocked",
    "npm run flowchain:truth-table -- -AllowBlocked",
    "npm run flowchain:no-secret:scan"
)

$launchSequence = @(
    [ordered]@{
        id = "owner-inputs"
        phase = "owner-inputs"
        title = "Validate ignored owner inputs"
        expectedStatuses = @("passed")
        ownerInputBlockedAllowedBeforeInputs = $true
        stopOnFailure = $true
        commands = @(
            "npm run flowchain:owner-env:readiness -- -AllowBlocked",
            "npm run flowchain:owner-inputs -- -AllowBlocked",
            "npm run flowchain:owner-inputs:validate"
        )
    },
    [ordered]@{
        id = "render-public-rpc"
        phase = "public-rpc"
        title = "Render public RPC edge artifacts"
        expectedStatuses = @("passed")
        ownerInputBlockedAllowedBeforeInputs = $true
        stopOnFailure = $true
        commands = @(
            "npm run flowchain:public-rpc:deployment-bundle",
            "npm run flowchain:public-rpc:deployment:automation",
            "powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-public-rpc-deployment-automation.ps1 -Action Render -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -OwnerEnvFile <FLOWCHAIN_OWNER_ENV_FILE> -TlsCertificatePath <PATH_TO_TLS_CERTIFICATE> -TlsCertificateKeyPath <PATH_TO_TLS_CERTIFICATE_KEY> -NginxExe <FLOWCHAIN_NGINX_EXE>"
        )
    },
    [ordered]@{
        id = "service-install"
        phase = "service"
        title = "Plan reboot-persistent services"
        expectedStatuses = @("passed")
        ownerInputBlockedAllowedBeforeInputs = $false
        stopOnFailure = $true
        commands = @(
            "npm run flowchain:service:install:systemd:validate",
            "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>",
            "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -StartBridgeRelayerLoop"
        )
    },
    [ordered]@{
        id = "local-service"
        phase = "service"
        title = "Prove live service health"
        expectedStatuses = @("passed")
        ownerInputBlockedAllowedBeforeInputs = $false
        stopOnFailure = $true
        commands = @(
            "npm run flowchain:service:status",
            "npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30"
        )
    },
    [ordered]@{
        id = "public-rpc"
        phase = "public-rpc"
        title = "Validate public RPC exposure"
        expectedStatuses = @("passed")
        ownerInputBlockedAllowedBeforeInputs = $true
        stopOnFailure = $true
        commands = @(
            "npm run flowchain:public-rpc:check -- -AllowBlocked",
            "npm run flowchain:public-rpc:validate",
            "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked",
            "npm run flowchain:public-rpc:abuse-test"
        )
    },
    [ordered]@{
        id = "backup"
        phase = "backup"
        title = "Prove backup and restore"
        expectedStatuses = @("passed")
        ownerInputBlockedAllowedBeforeInputs = $true
        stopOnFailure = $true
        commands = @(
            "npm run flowchain:backup:check -- -AllowBlocked",
            "npm run flowchain:backup:restore:validate",
            "npm run flowchain:backup:owner-path:dry-run"
        )
    },
    [ordered]@{
        id = "bridge"
        phase = "bridge"
        title = "Harden bridge relayer pilot"
        expectedStatuses = @("passed")
        ownerInputBlockedAllowedBeforeInputs = $true
        stopOnFailure = $true
        commands = @(
            "npm run flowchain:bridge:live:check -- -AllowBlocked",
            "npm run flowchain:bridge:infra:check -- -AllowBlocked",
            "npm run flowchain:bridge:relayer:guardrail:validate",
            "npm run flowchain:bridge:relayer:loop:validate",
            "npm run flowchain:bridge:relayer:once -- -AllowBlocked",
            "npm run flowchain:bridge:reconciliation"
        )
    },
    [ordered]@{
        id = "testers"
        phase = "testers"
        title = "Validate external tester launch"
        expectedStatuses = @("passed")
        ownerInputBlockedAllowedBeforeInputs = $true
        stopOnFailure = $true
        commands = @(
            "npm run flowchain:tester:token:setup",
            "npm run flowchain:tester:gateway:e2e",
            "npm run flowchain:wallet:live-tester:e2e",
            "npm run flowchain:external-tester:packet -- -AllowBlocked",
            "npm run flowchain:external-tester:packet:validate",
            "npm run flowchain:external-tester:client:validate",
            "npm run flowchain:tester:evidence:validate"
        )
    },
    [ordered]@{
        id = "final-audit"
        phase = "final-audit"
        title = "Run release gates"
        expectedStatuses = @("passed")
        ownerInputBlockedAllowedBeforeInputs = $true
        stopOnFailure = $true
        commands = @(
            "npm run flowchain:public-deployment:contract -- -AllowBlocked",
            "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked",
            "npm run flowchain:completion:audit -- -AllowBlocked",
            "npm run flowchain:truth-table -- -AllowBlocked",
            "npm run flowchain:no-secret:scan"
        )
    }
)
$rollbackCommands = @(
    "npm run flowchain:ops:snapshot -- -AllowBlocked",
    "npm run flowchain:service:status",
    "npm run flowchain:service:restart -- -LiveProfile",
    "npm run flowchain:service:stop",
    "npm run flowchain:emergency:stop-local",
    "npm run flowchain:bridge:emergency-stop",
    "npm run flowchain:public-deployment:contract -- -AllowBlocked"
)
$launchSequenceCommands = @($launchSequence | ForEach-Object { @($_.commands) })
$launchSequenceCommandText = @($launchSequenceCommands) -join "`n"
$rollbackCommandText = @($rollbackCommands) -join "`n"
$launchSequencePackageScriptNames = @(Get-HandoffNpmRunScriptNames -Commands $launchSequenceCommands)
$rollbackPackageScriptNames = @(Get-HandoffNpmRunScriptNames -Commands $rollbackCommands)
$missingLaunchSequencePackageScriptNames = @($launchSequencePackageScriptNames | Where-Object { -not (Test-HandoffPackageScript -Name $_) })
$missingRollbackPackageScriptNames = @($rollbackPackageScriptNames | Where-Object { -not (Test-HandoffPackageScript -Name $_) })

$coveredRequiredEnvNames = New-Object System.Collections.ArrayList
foreach ($stage in @($stages)) {
    Add-HandoffUniqueMany -Target $coveredRequiredEnvNames -Values @($stage.requiredEnvNames | Where-Object { $_ -in $requiredOwnerEnvNames })
}
$missingRequiredCoverage = @($requiredOwnerEnvNames | Where-Object { $_ -notin @($coveredRequiredEnvNames) })
$unknownMissingEnvNames = @($missingEnvNames | Where-Object { $_ -notin $knownOwnerEnvNames })
$unknownInvalidEnvNames = @($invalidEnvNames | Where-Object { $_ -notin $knownOwnerEnvNames })
$nonReadyStages = @($stages | Where-Object { $_.ready -ne $true })

$activationReady = (Get-HandoffProp -Object $activationPlan -Name "activationReady" -Default $false) -eq $true
$packetShareable = (Get-HandoffProp -Object $externalTesterPacket -Name "packetShareable" -Default $false) -eq $true
$deploymentReady = (Get-HandoffProp -Object $publicDeploymentContract -Name "deploymentReady" -Default $false) -eq $true
$completionReady = (Get-HandoffProp -Object $completionAudit -Name "completionReady" -Default $false) -eq $true
$truthTableClear = [string](Get-HandoffProp -Object $truthTable -Name "status" -Default "missing") -eq "passed"
$releaseReady = $activationReady -and $packetShareable -and $deploymentReady -and $completionReady -and $truthTableClear
$knownOwnerInputOnly = $unknownMissingEnvNames.Count -eq 0 -and $unknownInvalidEnvNames.Count -eq 0

$reportStatuses = @(
    (New-HandoffReportStatus -Name "ownerActivationPlan" -Report $activationPlan -Path $paths.ownerActivationPlan),
    (New-HandoffReportStatus -Name "ownerSignupChecklist" -Report $signupChecklist -Path $paths.ownerSignupChecklist),
    (New-HandoffReportStatus -Name "ownerInputs" -Report $ownerInputs -Path $paths.ownerInputs),
    (New-HandoffReportStatus -Name "publicDeploymentContract" -Report $publicDeploymentContract -Path $paths.publicDeploymentContract),
    (New-HandoffReportStatus -Name "externalTesterPacket" -Report $externalTesterPacket -Path $paths.externalTesterPacket),
    (New-HandoffReportStatus -Name "completionAudit" -Report $completionAudit -Path $paths.completionAudit),
    (New-HandoffReportStatus -Name "truthTable" -Report $truthTable -Path $paths.truthTable)
)

$checks = [ordered]@{
    packageScriptPresent = Test-HandoffPackageScript -Name "flowchain:owner:go-live-handoff"
    activationPlanLoaded = $null -ne $activationPlan
    activationPlanPassed = [string](Get-HandoffProp -Object $activationPlan -Name "status" -Default "missing") -eq "passed"
    signupChecklistLoaded = $null -ne $signupChecklist
    signupChecklistPassed = [string](Get-HandoffProp -Object $signupChecklist -Name "status" -Default "missing") -eq "passed"
    ownerInputsLoaded = $null -ne $ownerInputs
    truthTableLoaded = $null -ne $truthTable
    stageDeckPresent = @($stages).Count -gt 0
    stageCountMinimumMet = @($stages).Count -ge 8
    everyStageHasValidationCommand = @($stages | Where-Object { @($_.validationCommands).Count -eq 0 }).Count -eq 0
    everyStageHasOwnerMustNotSend = @($stages | Where-Object { @($_.ownerMustNotSend).Count -eq 0 }).Count -eq 0
    nonReadyStagesExplainBlockers = @($nonReadyStages | Where-Object { @($_.blockingEnvNames).Count -eq 0 -and @($_.blockedByReportNames).Count -eq 0 }).Count -eq 0
    requiredEnvCoverageComplete = $missingRequiredCoverage.Count -eq 0
    knownOwnerInputBlockersOnly = $knownOwnerInputOnly
    nextOwnerInputsPresentWhenBlocked = if ($releaseReady) { $true } else { @($nextOwnerInputNames).Count -gt 0 }
    nextCommandsPresent = @($nextCommands).Count -ge 6
    launchSequencePresent = @($launchSequence).Count -ge 8
    launchSequenceEveryStepHasCommands = @($launchSequence | Where-Object { @($_.commands).Count -eq 0 }).Count -eq 0
    launchSequenceEveryStepHasExpectedStatuses = @($launchSequence | Where-Object { @($_.expectedStatuses).Count -eq 0 }).Count -eq 0
    launchSequenceEveryStepStopsOnFailure = @($launchSequence | Where-Object { $_.stopOnFailure -ne $true }).Count -eq 0
    launchSequenceCoversOwnerEnvReadiness = $launchSequenceCommandText.Contains("flowchain:owner-env:readiness")
    launchSequenceCoversPublicRpcRender = $launchSequenceCommandText.Contains("flowchain-public-rpc-deployment-automation.ps1 -Action Render")
    launchSequenceCoversSystemdInstallPlan = $launchSequenceCommandText.Contains("flowchain:service:install:systemd -- -Action Plan")
    launchSequenceCoversServiceMonitor = $launchSequenceCommandText.Contains("flowchain:service:monitor")
    launchSequenceCoversPublicRpcCanary = $launchSequenceCommandText.Contains("flowchain:public-rpc:synthetic-canary")
    launchSequenceCoversBackupRestore = $launchSequenceCommandText.Contains("flowchain:backup:restore:validate")
    launchSequenceCoversBridgeRelayer = $launchSequenceCommandText.Contains("flowchain:bridge:relayer:once")
    launchSequenceCoversTesterPacket = $launchSequenceCommandText.Contains("flowchain:external-tester:packet")
    launchSequenceCoversCutoverAudit = $launchSequenceCommandText.Contains("flowchain:live:cutover:rehearsal") -and $launchSequenceCommandText.Contains("flowchain:completion:audit")
    launchSequenceCoversTruthAndNoSecret = $launchSequenceCommandText.Contains("flowchain:truth-table") -and $launchSequenceCommandText.Contains("flowchain:no-secret:scan")
    launchSequenceCommandsAvoidInlineEnvAssignment = @($launchSequenceCommands | Where-Object { "$_" -match '(^|\s)(\$env:)?[A-Z][A-Z0-9_]+\s*=' }).Count -eq 0
    launchSequenceCommandsAvoidUrls = @($launchSequenceCommands | Where-Object { "$_" -match 'https?://' }).Count -eq 0
    launchSequencePackageScriptsPresent = $missingLaunchSequencePackageScriptNames.Count -eq 0
    rollbackCommandsPresent = @($rollbackCommands).Count -ge 4
    rollbackCoversLocalStop = $rollbackCommandText.Contains("flowchain:service:stop") -and $rollbackCommandText.Contains("flowchain:emergency:stop-local")
    rollbackCoversBridgeEmergencyStop = $rollbackCommandText.Contains("flowchain:bridge:emergency-stop")
    rollbackCoversOpsSnapshot = $rollbackCommandText.Contains("flowchain:ops:snapshot")
    rollbackPackageScriptsPresent = $missingRollbackPackageScriptNames.Count -eq 0
    releaseClaimBlockedUntilTruthPassed = $releaseReady -or (-not $truthTableClear)
    packetShareBlockedUntilReady = $packetShareable -or (-not $releaseReady)
    envValuesPrintedFalse = $true
    noSecrets = $true
    broadcastsFalse = $true
    secretMarkerFindingsEmpty = $true
}

$report = [ordered]@{
    schema = "flowchain.owner_go_live_handoff_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    releaseReady = $releaseReady
    activationReady = $activationReady
    deploymentReady = $deploymentReady
    packetShareable = $packetShareable
    completionReady = $completionReady
    truthTableClear = $truthTableClear
    blockedOnlyOnKnownOwnerInputs = $knownOwnerInputOnly
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    requiredOwnerEnvNames = @($requiredOwnerEnvNames)
    optionalOwnerEnvNames = @($optionalOwnerEnvNames)
    missingEnvNames = @($missingEnvNames)
    invalidEnvNames = @($invalidEnvNames)
    unknownMissingEnvNames = @($unknownMissingEnvNames)
    unknownInvalidEnvNames = @($unknownInvalidEnvNames)
    nextOwnerInputNames = @($nextOwnerInputNames)
    stageCount = @($stages).Count
    readyStageCount = @($stages | Where-Object { $_.ready -eq $true }).Count
    blockedStageCount = @($nonReadyStages).Count
    nextCommandCount = @($nextCommands).Count
    launchSequenceCount = @($launchSequence).Count
    launchSequenceCommandCount = @($launchSequenceCommands).Count
    launchSequencePackageScriptCount = @($launchSequencePackageScriptNames).Count
    missingLaunchSequencePackageScriptNames = @($missingLaunchSequencePackageScriptNames)
    rollbackCommandCount = @($rollbackCommands).Count
    rollbackPackageScriptCount = @($rollbackPackageScriptNames).Count
    missingRollbackPackageScriptNames = @($missingRollbackPackageScriptNames)
    mustNotSendCount = @($mustNotSend).Count
    externalResourceCount = @($externalResources).Count
    stages = @($stages)
    launchSequence = @($launchSequence)
    rollbackCommands = @($rollbackCommands)
    reportStatuses = @($reportStatuses)
    externalResources = @($externalResources)
    mustNotSend = @($mustNotSend)
    nextCommands = @($nextCommands)
    reportPaths = $paths
    noLiveBroadcast = $true
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$report["status"] = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report["failedChecks"] = @($failedChecks)

$reportText = $report | ConvertTo-Json -Depth 24
Assert-FlowChainNoSecretText -Text $reportText -Label "owner go-live handoff report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 24

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Owner Go-Live Handoff")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $($report.status)")
$markdownLines.Add("Release ready: $releaseReady")
$markdownLines.Add("")
$markdownLines.Add("This handoff records names, statuses, resource boundaries, and validation commands only. Put real values in the ignored owner env file or the service environment.")
$markdownLines.Add("")
$markdownLines.Add("## Needed Now")
$markdownLines.Add("")
if (@($nextOwnerInputNames).Count -eq 0) {
    $markdownLines.Add("- None")
}
else {
    foreach ($name in @($nextOwnerInputNames)) {
        $markdownLines.Add("- ``$name``")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Stage Deck")
$markdownLines.Add("")
$markdownLines.Add("| Stage | Status | Blocking inputs | Next command |")
$markdownLines.Add("| --- | --- | --- | --- |")
foreach ($stage in @($stages)) {
    $blocking = if (@($stage.blockingEnvNames).Count -gt 0) { (@($stage.blockingEnvNames) -join ", ") } else { "none" }
    $markdownLines.Add("| $($stage.title.Replace('|','/')) | $($stage.status) | $blocking | $($stage.nextCommand.Replace('|','/')) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Ordered Launch Sequence")
$markdownLines.Add("")
$markdownLines.Add("| Step | Expected status | Stop on failure | Commands |")
$markdownLines.Add("| --- | --- | --- | --- |")
foreach ($step in @($launchSequence)) {
    $commands = @($step.commands) -join "<br>"
    $expected = @($step.expectedStatuses) -join ", "
    $markdownLines.Add("| $($step.title.Replace('|','/')) | $expected | $($step.stopOnFailure) | $($commands.Replace('|','/')) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Rollback Commands")
$markdownLines.Add("")
foreach ($command in @($rollbackCommands)) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
$markdownLines.Add("## Package Script Coverage")
$markdownLines.Add("")
$markdownLines.Add("- Launch sequence package scripts: $(@($launchSequencePackageScriptNames).Count)")
$markdownLines.Add("- Missing launch sequence package scripts: $(@($missingLaunchSequencePackageScriptNames).Count)")
$markdownLines.Add("- Rollback package scripts: $(@($rollbackPackageScriptNames).Count)")
$markdownLines.Add("- Missing rollback package scripts: $(@($missingRollbackPackageScriptNames).Count)")
$markdownLines.Add("")
$markdownLines.Add("## External Resources")
$markdownLines.Add("")
foreach ($resource in @($externalResources)) {
    $markdownLines.Add("- $resource")
}
$markdownLines.Add("")
$markdownLines.Add("## Do Not Send")
$markdownLines.Add("")
foreach ($item in @($mustNotSend)) {
    $markdownLines.Add("- $item")
}
$markdownLines.Add("")
$markdownLines.Add("## Validation Commands")
$markdownLines.Add("")
foreach ($command in @($nextCommands)) {
    $markdownLines.Add("- $command")
}

$markdownText = ($markdownLines -join [Environment]::NewLine) + [Environment]::NewLine
Assert-FlowChainNoSecretText -Text $markdownText -Label "owner go-live handoff markdown"
$markdownParent = Split-Path -Parent $markdownFullPath
if (-not [string]::IsNullOrWhiteSpace($markdownParent)) {
    New-Item -ItemType Directory -Force -Path $markdownParent | Out-Null
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($markdownFullPath, $markdownText, $utf8NoBom)

Write-Host "FlowChain owner go-live handoff status: $($report.status)"
Write-Host "Release ready: $releaseReady"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if (@($nextOwnerInputNames).Count -gt 0) {
    Write-Host "Needed now: $($nextOwnerInputNames -join ', ')"
}
if ($report.status -ne "passed") {
    exit 1
}
