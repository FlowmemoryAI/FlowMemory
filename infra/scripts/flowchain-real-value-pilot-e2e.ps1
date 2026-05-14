param(
    [switch] $AllowIncomplete,
    [switch] $SkipBaseline
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/real-value-pilot")

if (Test-Path -LiteralPath $reportDir) {
    Remove-Item -LiteralPath $reportDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$packageJson = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "package.json") | ConvertFrom-Json
$rootScripts = @($packageJson.scripts.PSObject.Properties.Name)
$checks = [ordered]@{}
$results = [ordered]@{}
$commandsRun = New-Object System.Collections.ArrayList
$missingProofs = New-Object System.Collections.ArrayList

function Test-RootScript {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    return ($rootScripts -contains $Name)
}

function Add-PilotCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [bool] $Passed,

        [Parameter(Mandatory = $true)]
        [string] $Owner,

        [Parameter(Mandatory = $true)]
        [string] $Command,

        [Parameter(Mandatory = $true)]
        [string] $Evidence,

        [Parameter(Mandatory = $true)]
        [string] $NextAction
    )

    $checks[$Name] = [ordered]@{
        passed = $Passed
        owner = $Owner
        command = $Command
        evidence = $Evidence
        nextAction = $NextAction
    }

    if (-not $Passed) {
        [void] $missingProofs.Add([ordered]@{
            proof = $Name
            owner = $Owner
            command = $Command
            evidence = $Evidence
            nextAction = $NextAction
        })
    }
}

function Write-PilotReport {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Status
    )

    $reportPath = Join-Path $reportDir "flowchain-real-value-pilot-e2e-report.json"
    $report = [ordered]@{
        schema = "flowchain.real_value_pilot.e2e_report.v0"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        commit = (& git rev-parse HEAD).Trim()
        status = $Status
        allowIncomplete = [bool] $AllowIncomplete
        skipBaseline = [bool] $SkipBaseline
        commandsRun = @($commandsRun)
        checks = $checks
        commandResults = $results
        missingProofs = @($missingProofs)
        ownerGoNoGo = [ordered]@{
            go = ($Status -eq "passed" -and $missingProofs.Count -eq 0)
            checklist = "docs/FLOWCHAIN_REAL_VALUE_PILOT.md#owner-gonogo-checklist"
        }
        boundary = @(
            "capped owner pilot only",
            "no public launch claim",
            "no open-validator readiness claim",
            "no tokenomics claim",
            "no broad bridge readiness claim",
            "no custody claim"
        )
    }

    Write-FlowChainJson -Path $reportPath -Value $report -Depth 16
    return $reportPath
}

function Invoke-RootNpmScript {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Owner
    )

    $display = "npm run $Name"
    [void] $commandsRun.Add($display)
    try {
        Invoke-FlowChainCommand -Label "Run $Name ($Owner)" -FilePath "npm" -ArgumentList @("run", $Name)
        $results[$Name] = [ordered]@{
            owner = $Owner
            status = "passed"
            command = $display
        }
    }
    catch {
        $results[$Name] = [ordered]@{
            owner = $Owner
            status = "failed"
            command = $display
            error = $_.Exception.Message
        }
        Write-PilotReport -Status "failed" | Out-Null
        throw
    }
}

$pilotDocPath = Join-Path $repoRoot "docs/FLOWCHAIN_REAL_VALUE_PILOT.md"
Add-PilotCheck `
    -Name "hq:pilot-spec" `
    -Passed (Test-Path -LiteralPath $pilotDocPath) `
    -Owner "hq" `
    -Command "docs/FLOWCHAIN_REAL_VALUE_PILOT.md" `
    -Evidence "pilot source-of-truth doc must exist" `
    -NextAction "HQ adds or restores docs/FLOWCHAIN_REAL_VALUE_PILOT.md."

$baselineCommands = @(
    [ordered]@{ command = "flowchain:product-e2e"; owner = "hq/ops"; proof = "baseline:product-e2e"; evidence = "existing product testnet gate must remain runnable"; nextAction = "Keep npm run flowchain:product-e2e passing or document owner and next action." },
    [ordered]@{ command = "flowchain:l1-e2e"; owner = "hq/ops"; proof = "baseline:l1-e2e"; evidence = "L1 baseline gate must exist before owner pilot"; nextAction = "Add or rebase the L1 E2E gate." }
)

foreach ($entry in $baselineCommands) {
    Add-PilotCheck `
        -Name $entry.proof `
        -Passed (Test-RootScript -Name $entry.command) `
        -Owner $entry.owner `
        -Command "npm run $($entry.command)" `
        -Evidence $entry.evidence `
        -NextAction $entry.nextAction
}

$requiredProofs = @(
    [ordered]@{ proof = "contracts:chain-id-lockbox-caps-pause-replay"; owner = "contracts"; command = "flowchain:real-value-pilot:contracts"; evidence = "chain ID 8453, ignored lockbox config, caps, allowlist, pause, release/recovery, and replay protections need contract evidence"; nextAction = "Contracts agent adds the dedicated pilot contracts gate." },
    [ordered]@{ proof = "bridge:observe-credit-replay-withdrawal"; owner = "bridge-relayer"; command = "flowchain:real-value-pilot:bridge"; evidence = "Base observation, deterministic credit, duplicate handling, and withdrawal/release evidence need relayer evidence"; nextAction = "Bridge relayer agent adds the dedicated pilot bridge gate." },
    [ordered]@{ proof = "runtime:credit-once-restart-export"; owner = "chain-runtime"; command = "flowchain:real-value-pilot:runtime"; evidence = "local runtime must apply pilot credits exactly once and preserve state across restart/export/import"; nextAction = "Chain runtime agent adds the dedicated pilot runtime gate." },
    [ordered]@{ proof = "wallet:operator-signing-and-negative-vectors"; owner = "wallet-operator"; command = "flowchain:real-value-pilot:wallet"; evidence = "operator wallet must sign pilot messages and reject wrong chain, wrong contract, replay, expiry, and missing cap fields"; nextAction = "Wallet/operator agent adds the dedicated pilot wallet gate." },
    [ordered]@{ proof = "control-dashboard:api-and-owner-views"; owner = "control-plane/dashboard"; command = "flowchain:real-value-pilot:control-dashboard"; evidence = "API and dashboard must expose pilot status, credits, withdrawal, emergency state, redaction, labels, and next commands"; nextAction = "Control-plane/dashboard agent adds the dedicated pilot evidence gate." },
    [ordered]@{ proof = "ops:env-ack-emergency-export-restart"; owner = "ops-installer"; command = "flowchain:real-value-pilot:ops"; evidence = "ops path must verify env, tiny caps, explicit owner ack, emergency stop, no-secret export, and restart recovery"; nextAction = "Ops/installer agent adds the dedicated pilot ops gate." }
)

foreach ($entry in $requiredProofs) {
    Add-PilotCheck `
        -Name $entry.proof `
        -Passed (Test-RootScript -Name $entry.command) `
        -Owner $entry.owner `
        -Command "npm run $($entry.command)" `
        -Evidence $entry.evidence `
        -NextAction $entry.nextAction
}

if ($missingProofs.Count -gt 0) {
    $reportPath = Write-PilotReport -Status "incomplete"
    Write-Host ""
    Write-Host "FlowChain real-value pilot E2E is incomplete. Missing proofs:"
    foreach ($missing in $missingProofs) {
        Write-Host "- $($missing.proof) [$($missing.owner)] via $($missing.command): $($missing.evidence)"
        Write-Host "  Next: $($missing.nextAction)"
    }
    Write-Host ""
    Write-Host "Report: $reportPath"
    if (-not $AllowIncomplete) {
        throw "FlowChain real-value pilot E2E is incomplete. Rerun with -AllowIncomplete only for coordination reports."
    }
    return
}

if (-not $SkipBaseline) {
    foreach ($entry in $baselineCommands) {
        Invoke-RootNpmScript -Name $entry.command -Owner $entry.owner
    }
}

$uniqueProofCommands = [ordered]@{}
foreach ($entry in $requiredProofs) {
    if (-not $uniqueProofCommands.Contains($entry.command)) {
        $uniqueProofCommands[$entry.command] = $entry.owner
    }
}

foreach ($commandName in $uniqueProofCommands.Keys) {
    Invoke-RootNpmScript -Name $commandName -Owner $uniqueProofCommands[$commandName]
}

$finalReportPath = Write-PilotReport -Status "passed"
Write-Host ""
Write-Host "FlowChain real-value pilot E2E passed."
Write-Host "Report: $finalReportPath"
