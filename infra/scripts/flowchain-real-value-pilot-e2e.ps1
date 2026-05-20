param(
    [switch] $AllowIncomplete,
    [switch] $SkipBaseline,
    [int] $ChildTimeoutSeconds = 7200,
    [string] $ReportDir = "devnet/local/real-value-pilot"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportDir)

if ($ChildTimeoutSeconds -lt 1) {
    throw "ChildTimeoutSeconds must be at least 1."
}

if (Test-Path -LiteralPath $reportDir) {
    Remove-Item -LiteralPath $reportDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$logDir = Join-Path $reportDir "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$packageJson = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "package.json") | ConvertFrom-Json
$rootScripts = @($packageJson.scripts.PSObject.Properties.Name)
$checks = [ordered]@{}
$results = [ordered]@{}
$commandsRun = New-Object System.Collections.ArrayList
$missingProofs = New-Object System.Collections.ArrayList

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

function ConvertTo-PilotSafeLine {
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

function Stop-PilotProcessTree {
    param([Parameter(Mandatory = $true)][int] $ProcessId)

    $children = @()
    try {
        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue)
    }
    catch {
        $children = @()
    }

    foreach ($child in $children) {
        Stop-PilotProcessTree -ProcessId ([int] $child.ProcessId)
    }

    try {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    }
    catch {
    }
}

function Read-PilotOutputTail {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }
    return @(Get-Content -LiteralPath $Path -Tail 120 -ErrorAction SilentlyContinue | ForEach-Object { ConvertTo-PilotSafeLine -Line $_ })
}

function Write-PilotReport {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Status
    )

    $reportPath = Join-Path $reportDir "flowchain-real-value-pilot-e2e-report.json"
    $commandResults = @($results.GetEnumerator() | ForEach-Object { $_.Value })
    $timedOutCommands = @($commandResults | Where-Object { $_.timedOut -eq $true } | ForEach-Object { $_.command })
    $failedCommands = @($commandResults | Where-Object { "$($_.status)" -ne "passed" } | ForEach-Object { $_.command })
    $report = [ordered]@{
        schema = "flowchain.real_value_pilot.e2e_report.v0"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        commit = (& git rev-parse HEAD).Trim()
        status = $Status
        allowIncomplete = [bool] $AllowIncomplete
        skipBaseline = [bool] $SkipBaseline
        childTimeoutSeconds = $ChildTimeoutSeconds
        commandsRun = @($commandsRun)
        checks = $checks
        commandResults = $results
        timedOutCommands = @($timedOutCommands)
        failedCommands = @($failedCommands)
        missingProofs = @($missingProofs)
        ownerGoNoGo = [ordered]@{
            go = ($Status -eq "passed" -and $missingProofs.Count -eq 0 -and $timedOutCommands.Count -eq 0 -and $failedCommands.Count -eq 0)
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
    $startedAt = (Get-Date).ToUniversalTime()
    $stamp = $startedAt.ToString("yyyyMMddTHHmmssfffZ")
    $safeName = $Name -replace '[^A-Za-z0-9_.-]', '-'
    $stdoutPath = Join-Path $logDir "$stamp-$safeName.stdout.log"
    $stderrPath = Join-Path $logDir "$stamp-$safeName.stderr.log"
    $timedOut = $false
    $exitCode = 1
    $processId = $null
    $output = @()
    try {
        Write-Host ""
        Write-Host "== Run $Name ($Owner) =="
        Write-Host $display
        $process = Start-Process -FilePath "powershell" `
            -ArgumentList (Join-FlowChainProcessArguments -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $display)) `
            -WorkingDirectory $repoRoot `
            -PassThru `
            -WindowStyle Hidden `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
        $processId = $process.Id
        if (-not $process.WaitForExit($ChildTimeoutSeconds * 1000)) {
            $timedOut = $true
            Stop-PilotProcessTree -ProcessId $process.Id
            $exitCode = 124
        }
        else {
            $process.Refresh()
            $exitCode = [int] $process.ExitCode
        }
        $output = @(Read-PilotOutputTail -Path $stdoutPath) + @(Read-PilotOutputTail -Path $stderrPath)
        if ($timedOut) {
            $output = @("Timed out after $ChildTimeoutSeconds seconds; child process tree was stopped.") + $output
        }
        $finishedAt = (Get-Date).ToUniversalTime()
        $durationSeconds = [int][Math]::Max(0, [Math]::Floor(($finishedAt - $startedAt).TotalSeconds))
        $results[$Name] = [ordered]@{
            owner = $Owner
            status = if ($timedOut) { "timed-out" } elseif ($exitCode -eq 0) { "passed" } else { "failed" }
            command = $display
            startedAt = $startedAt.ToString("o")
            finishedAt = $finishedAt.ToString("o")
            durationSeconds = $durationSeconds
            timedOut = $timedOut
            timeoutSeconds = $ChildTimeoutSeconds
            processId = $processId
            exitCode = $exitCode
            stdout = ($stdoutPath.Substring($repoRoot.Length).TrimStart("\", "/") -replace '\\', '/')
            stderr = ($stderrPath.Substring($repoRoot.Length).TrimStart("\", "/") -replace '\\', '/')
            outputTailRedacted = @($output)
        }
        if ($timedOut) {
            Write-PilotReport -Status "failed" | Out-Null
            throw "$display timed out after $ChildTimeoutSeconds seconds."
        }
        if ($exitCode -ne 0) {
            Write-PilotReport -Status "failed" | Out-Null
            throw "$display failed with exit code $exitCode."
        }
    }
    catch {
        if (-not $results.Contains($Name)) {
            $finishedAt = (Get-Date).ToUniversalTime()
            $results[$Name] = [ordered]@{
                owner = $Owner
                status = "failed"
                command = $display
                startedAt = $startedAt.ToString("o")
                finishedAt = $finishedAt.ToString("o")
                durationSeconds = [int][Math]::Max(0, [Math]::Floor(($finishedAt - $startedAt).TotalSeconds))
                timedOut = $timedOut
                timeoutSeconds = $ChildTimeoutSeconds
                processId = $processId
                exitCode = $exitCode
                stdout = ($stdoutPath.Substring($repoRoot.Length).TrimStart("\", "/") -replace '\\', '/')
                stderr = ($stderrPath.Substring($repoRoot.Length).TrimStart("\", "/") -replace '\\', '/')
                outputTailRedacted = @($output)
                error = ConvertTo-PilotSafeLine -Line $_.Exception.Message
            }
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
