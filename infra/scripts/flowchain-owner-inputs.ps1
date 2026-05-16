param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OWNER_INPUTS.md",
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

$requiredAck = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"

$inputGroups = @(
    [ordered]@{
        group = "public-rpc"
        names = @(
            "FLOWCHAIN_RPC_PUBLIC_URL",
            "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
            "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
            "FLOWCHAIN_RPC_TLS_TERMINATED"
        )
    },
    [ordered]@{
        group = "backup"
        names = @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
    },
    [ordered]@{
        group = "base8453-bridge"
        names = @(
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
    }
)

function Add-OwnerInputProblem {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Problems,
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Reason,
        [ValidateSet("blocked", "failed")]
        [string] $Kind = "blocked"
    )

    [void] $Problems.Add([ordered]@{
        name = $Name
        kind = $Kind
        reason = $Reason
    })
}

function Test-OwnerInputAddress {
    param([AllowNull()][string] $Value)
    return -not [string]::IsNullOrWhiteSpace($Value) -and $Value -cmatch '^0x[0-9a-fA-F]{40}$'
}

function Test-OwnerInputUInt {
    param(
        [AllowNull()][string] $Value,
        [switch] $AllowZero
    )

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^(0|[1-9][0-9]*)$') {
        return $false
    }
    try {
        $parsed = [System.Numerics.BigInteger]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
        return $AllowZero -or $parsed -gt 0
    }
    catch {
        return $false
    }
}

function Get-OwnerInputStatus {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Group,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Problems
    )

    $value = Get-FlowChainEnvValue -Name $Name
    $present = -not [string]::IsNullOrWhiteSpace($value)
    $valid = $null
    $check = "required"

    if (-not $present) {
        Add-OwnerInputProblem -Problems $Problems -Name $Name -Reason "missing required owner input"
        return [ordered]@{
            name = $Name
            group = $Group
            present = $false
            valid = $false
            status = "missing"
            check = $check
        }
    }

    switch ($Name) {
        "FLOWCHAIN_RPC_PUBLIC_URL" {
            $uri = $null
            $valid = [System.Uri]::TryCreate($value, [System.UriKind]::Absolute, [ref] $uri) -and $null -ne $uri -and $uri.Scheme -eq "https" -and -not (Test-FlowChainLocalUri -Uri $uri)
            $check = "absolute public HTTPS endpoint"
            if (-not $valid) {
                Add-OwnerInputProblem -Problems $Problems -Name $Name -Reason "must be an absolute non-local HTTPS endpoint" -Kind "failed"
            }
        }
        "FLOWCHAIN_RPC_ALLOWED_ORIGINS" {
            $origins = @($value.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
            $valid = $origins.Count -gt 0
            $check = "one or more explicit HTTPS browser origins"
            foreach ($origin in $origins) {
                $originUri = $null
                if ($origin -in @("*", "null", "all", "ALL")) {
                    $valid = $false
                }
                elseif (-not [System.Uri]::TryCreate($origin, [System.UriKind]::Absolute, [ref] $originUri) -or $null -eq $originUri -or $originUri.Scheme -ne "https") {
                    $valid = $false
                }
            }
            if (-not $valid) {
                Add-OwnerInputProblem -Problems $Problems -Name $Name -Reason "must contain explicit HTTPS origins and no wildcard origin" -Kind "failed"
            }
        }
        "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE" {
            $valid = Test-OwnerInputUInt -Value $value
            $check = "positive decimal integer"
            if (-not $valid) {
                Add-OwnerInputProblem -Problems $Problems -Name $Name -Reason "must be a positive decimal integer" -Kind "failed"
            }
        }
        "FLOWCHAIN_RPC_TLS_TERMINATED" {
            $valid = $value.ToLowerInvariant() -eq "true"
            $check = "must equal true after TLS termination is configured"
            if (-not $valid) {
                Add-OwnerInputProblem -Problems $Problems -Name $Name -Reason "must equal true" -Kind "failed"
            }
        }
        "FLOWCHAIN_RPC_STATE_BACKUP_PATH" {
            $valid = $false
            $check = "existing writable directory"
            try {
                $backupPath = [System.IO.Path]::GetFullPath($value)
                if (Test-Path -LiteralPath $backupPath) {
                    $item = Get-Item -LiteralPath $backupPath
                    if ($item.PSIsContainer) {
                        $probePath = Join-Path $backupPath ".flowchain-owner-inputs-write-check-$PID.tmp"
                        "flowchain-owner-inputs-write-check" | Set-Content -LiteralPath $probePath -Encoding UTF8
                        $readBack = Get-Content -Raw -LiteralPath $probePath
                        Remove-Item -LiteralPath $probePath -Force
                        $valid = $readBack -like "flowchain-owner-inputs-write-check*"
                    }
                }
            }
            catch {
                $valid = $false
            }
            if (-not $valid) {
                Add-OwnerInputProblem -Problems $Problems -Name $Name -Reason "must point to an existing writable directory" -Kind "failed"
            }
        }
        "FLOWCHAIN_PILOT_OPERATOR_ACK" {
            $valid = $value -eq $requiredAck
            $check = "must equal the fixed capped-pilot acknowledgement"
            if (-not $valid) {
                Add-OwnerInputProblem -Problems $Problems -Name $Name -Reason "must match the capped-pilot acknowledgement" -Kind "failed"
            }
        }
        "FLOWCHAIN_BASE8453_RPC_URL" {
            $uri = $null
            $valid = [System.Uri]::TryCreate($value, [System.UriKind]::Absolute, [ref] $uri) -and $null -ne $uri -and $uri.Scheme -in @("http", "https")
            $check = "absolute HTTP(S) Base 8453 endpoint"
            if (-not $valid) {
                Add-OwnerInputProblem -Problems $Problems -Name $Name -Reason "must be an absolute HTTP(S) endpoint" -Kind "failed"
            }
        }
        { $_ -in @("FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN") } {
            $valid = Test-OwnerInputAddress -Value $value
            $check = "20-byte hex address"
            if (-not $valid) {
                Add-OwnerInputProblem -Problems $Problems -Name $Name -Reason "must be a 20-byte hex address" -Kind "failed"
            }
        }
        "FLOWCHAIN_BASE8453_ASSET_DECIMALS" {
            $valid = Test-OwnerInputUInt -Value $value -AllowZero
            if ($valid) {
                $decimals = [int64]$value
                $valid = $decimals -ge 0 -and $decimals -le 255
            }
            $check = "decimal integer from 0 through 255"
            if (-not $valid) {
                Add-OwnerInputProblem -Problems $Problems -Name $Name -Reason "must be an integer from 0 through 255" -Kind "failed"
            }
        }
        { $_ -in @("FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_BASE8453_TO_BLOCK") } {
            $valid = Test-OwnerInputUInt -Value $value -AllowZero
            $check = "non-negative decimal block number"
            if (-not $valid) {
                Add-OwnerInputProblem -Problems $Problems -Name $Name -Reason "must be a non-negative decimal block number" -Kind "failed"
            }
        }
        { $_ -in @("FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS") } {
            $valid = Test-OwnerInputUInt -Value $value
            $check = "positive decimal integer"
            if (-not $valid) {
                Add-OwnerInputProblem -Problems $Problems -Name $Name -Reason "must be a positive decimal integer" -Kind "failed"
            }
        }
        default {
            $valid = $true
        }
    }

    return [ordered]@{
        name = $Name
        group = $Group
        present = $present
        valid = $valid
        status = if ($valid) { "present-valid" } else { "present-invalid" }
        check = $check
    }
}

$problems = New-Object System.Collections.ArrayList
$inputs = New-Object System.Collections.ArrayList
$ownerEnvFileState = $null
$ownerEnvFileProblem = ""

try {
    Import-FlowChainOwnerEnvFileIfConfigured
    $ownerEnvFileState = Get-FlowChainOwnerEnvFileState
}
catch {
    $ownerEnvFileProblem = "$($_.Exception.Message)"
    $ownerEnvFileState = $script:FlowChainOwnerEnvFileState
    if ($null -eq $ownerEnvFileState -or $ownerEnvFileState.configured -ne $true) {
        $ownerEnvFileState = [ordered]@{
            configured = $true
            imported = $false
            importedEnvNames = @()
            ignoredEnvNames = @()
            problem = $ownerEnvFileProblem
        }
    }
    Add-OwnerInputProblem -Problems $problems -Name "FLOWCHAIN_OWNER_ENV_FILE" -Reason $ownerEnvFileProblem -Kind "failed"
}

foreach ($groupEntry in $inputGroups) {
    foreach ($name in @($groupEntry.names)) {
        [void] $inputs.Add((Get-OwnerInputStatus -Name $name -Group $groupEntry.group -Problems $problems))
    }
}

$fromValue = Get-FlowChainEnvValue -Name "FLOWCHAIN_BASE8453_FROM_BLOCK"
$toValue = Get-FlowChainEnvValue -Name "FLOWCHAIN_BASE8453_TO_BLOCK"
if ((Test-OwnerInputUInt -Value $fromValue -AllowZero) -and (Test-OwnerInputUInt -Value $toValue -AllowZero)) {
    $fromBlock = [System.Numerics.BigInteger]::Parse($fromValue, [System.Globalization.CultureInfo]::InvariantCulture)
    $toBlock = [System.Numerics.BigInteger]::Parse($toValue, [System.Globalization.CultureInfo]::InvariantCulture)
    if ($toBlock -lt $fromBlock) {
        Add-OwnerInputProblem -Problems $problems -Name "FLOWCHAIN_BASE8453_TO_BLOCK" -Reason "must be greater than or equal to FLOWCHAIN_BASE8453_FROM_BLOCK" -Kind "failed"
        foreach ($input in @($inputs | Where-Object { $_.name -eq "FLOWCHAIN_BASE8453_TO_BLOCK" })) {
            $input.valid = $false
            $input.status = "present-invalid"
        }
    }
}

$missing = @($inputs | Where-Object { $_.present -ne $true } | ForEach-Object { $_.name })
$invalid = @($inputs | Where-Object { $_.present -eq $true -and $_.valid -ne $true } | ForEach-Object { $_.name })
if (-not [string]::IsNullOrWhiteSpace($ownerEnvFileProblem)) {
    $invalid = @($invalid + "FLOWCHAIN_OWNER_ENV_FILE" | Select-Object -Unique)
}
$status = if ($invalid.Count -gt 0) { "failed" } elseif ($missing.Count -gt 0) { "blocked" } else { "passed" }

$report = [ordered]@{
    schema = "flowchain.owner_inputs_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    ownerInputReady = $status -eq "passed"
    groups = @($inputGroups | ForEach-Object { $_.group })
    inputs = @($inputs)
    missingEnvNames = @($missing)
    invalidEnvNames = @($invalid)
    ownerEnvFileState = $ownerEnvFileState
    ownerEnvFileProblem = $ownerEnvFileProblem
    problems = @($problems)
    nextCommandsAfterOwnerInputs = @(
        "npm run flowchain:owner-env:template",
        "npm run flowchain:owner-env:readiness:validate",
        "npm run flowchain:owner-env:readiness -- -AllowBlocked",
        "npm run flowchain:owner:onboarding",
        "npm run flowchain:owner:signup-checklist",
        "npm run flowchain:service:monitor",
        "npm run flowchain:live-infra:check",
        "npm run flowchain:tester:readiness",
        "npm run flowchain:external-tester:packet",
        "npm run flowchain:live-product:e2e"
    )
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "owner inputs report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Owner Inputs")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Owner input ready: $($report.ownerInputReady)")
$markdownLines.Add("")
$markdownLines.Add("This file intentionally records env names, validation checks, and pass/block/fail status only. It does not contain owner-provided values.")
$markdownLines.Add("")
$markdownLines.Add("| Env name | Group | Status | Check |")
$markdownLines.Add("| --- | --- | --- | --- |")
foreach ($input in @($inputs)) {
    $markdownLines.Add("| $($input.name) | $($input.group) | $($input.status) | $($input.check) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Owner Env File")
$markdownLines.Add("")
if ($null -eq $ownerEnvFileState -or $ownerEnvFileState.configured -ne $true) {
    $markdownLines.Add("- FLOWCHAIN_OWNER_ENV_FILE configured: False")
}
else {
    $markdownLines.Add("- FLOWCHAIN_OWNER_ENV_FILE configured: True")
    $markdownLines.Add("- Imported known env names: $(@($ownerEnvFileState.importedEnvNames).Count)")
    $markdownLines.Add("- Ignored unknown env names: $(@($ownerEnvFileState.ignoredEnvNames).Count)")
    if (-not [string]::IsNullOrWhiteSpace($ownerEnvFileProblem)) {
        $markdownLines.Add("- Problem: $ownerEnvFileProblem")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Next Commands")
$markdownLines.Add("")
foreach ($command in @($report.nextCommandsAfterOwnerInputs)) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
if ($status -eq "passed") {
    $markdownLines.Add("All required owner input names are present and structurally valid. Continue with the live infrastructure and tester gates.")
}
else {
    $markdownLines.Add("Do not share the network externally yet. Resolve the missing or invalid env names above, then rerun the next commands.")
}

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "owner inputs markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain owner inputs status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($missing.Count -gt 0) {
    Write-Host "Missing env names: $($missing -join ', ')"
}
if ($invalid.Count -gt 0) {
    Write-Host "Invalid env names: $($invalid -join ', ')"
}

if ($status -eq "passed" -or ($status -eq "blocked" -and $AllowBlocked)) {
    exit 0
}
exit 1
