$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$script:FlowChainOwnerEnvFileImported = $false
$script:FlowChainOwnerEnvFileState = [ordered]@{
    configured = $false
    imported = $false
    importedEnvNames = @()
    ignoredEnvNames = @()
    problem = ""
}

function Import-FlowChainOwnerEnvFileIfConfigured {
    if ($script:FlowChainOwnerEnvFileImported) {
        return
    }

    $script:FlowChainOwnerEnvFileImported = $true
    $envFilePath = [Environment]::GetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", "Process")
    if ([string]::IsNullOrWhiteSpace($envFilePath)) {
        try {
            $defaultEnvFilePath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path "devnet/local/owner-inputs/flowchain-owner.local.env"))
            if (Test-Path -LiteralPath $defaultEnvFilePath) {
                $envFilePath = $defaultEnvFilePath
                [Environment]::SetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", $envFilePath, "Process")
            }
        }
        catch {
            $envFilePath = ""
        }
        if ([string]::IsNullOrWhiteSpace($envFilePath)) {
            return
        }
    }

    $allowedNames = @(
        "FLOWCHAIN_RPC_PUBLIC_URL",
        "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
        "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
        "FLOWCHAIN_RPC_TLS_TERMINATED",
        "FLOWCHAIN_RPC_STATE_BACKUP_PATH",
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
        "FLOWCHAIN_PILOT_CONFIRMATIONS",
        "FLOWCHAIN_BASE8453_TX_HASH",
        "FLOWCHAIN_BASE8453_OPERATOR_TX_HASH",
        "FLOWCHAIN_BRIDGE_TARGET_SETTLEMENT_SECONDS",
        "FLOWCHAIN_BASE8453_ESTIMATED_BLOCK_SECONDS",
        "FLOWCHAIN_BRIDGE_POLL_SECONDS",
        "FLOWCHAIN_TESTER_WRITE_ENABLED",
        "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
        "FLOWCHAIN_TESTER_MAX_SEND_UNITS"
    )

    try {
        $fullPath = [System.IO.Path]::GetFullPath($envFilePath)
    }
    catch {
        $script:FlowChainOwnerEnvFileState = [ordered]@{
            configured = $true
            imported = $false
            importedEnvNames = @()
            ignoredEnvNames = @()
            problem = "FLOWCHAIN_OWNER_ENV_FILE is not a valid path."
        }
        throw "FLOWCHAIN_OWNER_ENV_FILE is not a valid path."
    }

    if (-not (Test-Path -LiteralPath $fullPath)) {
        $script:FlowChainOwnerEnvFileState = [ordered]@{
            configured = $true
            imported = $false
            importedEnvNames = @()
            ignoredEnvNames = @()
            problem = "FLOWCHAIN_OWNER_ENV_FILE points to a missing file."
        }
        throw "FLOWCHAIN_OWNER_ENV_FILE points to a missing file."
    }

    $importedNames = New-Object System.Collections.ArrayList
    $ignoredNames = New-Object System.Collections.ArrayList
    $lineNumber = 0
    foreach ($line in @(Get-Content -LiteralPath $fullPath)) {
        $lineNumber += 1
        $trimmed = "$line".Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
            continue
        }
        if ($trimmed.StartsWith("export ")) {
            $trimmed = $trimmed.Substring(7).Trim()
        }
        if ($trimmed -notmatch '^([A-Z][A-Z0-9_]*)=(.*)$') {
            throw "FLOWCHAIN_OWNER_ENV_FILE line $lineNumber must be NAME=value."
        }

        $name = $Matches[1]
        $value = $Matches[2].Trim()
        if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        if ($name -notin $allowedNames) {
            if (-not $ignoredNames.Contains($name)) {
                [void] $ignoredNames.Add($name)
            }
            continue
        }

        [Environment]::SetEnvironmentVariable($name, $value, "Process")
        if (-not $importedNames.Contains($name)) {
            [void] $importedNames.Add($name)
        }
    }

    $script:FlowChainOwnerEnvFileState = [ordered]@{
        configured = $true
        imported = $true
        importedEnvNames = @($importedNames)
        ignoredEnvNames = @($ignoredNames)
        problem = ""
    }
}

function Get-FlowChainOwnerEnvFileState {
    Import-FlowChainOwnerEnvFileIfConfigured
    return $script:FlowChainOwnerEnvFileState
}

function Get-FlowChainEnvValue {
    param([Parameter(Mandatory = $true)][string] $Name)
    Import-FlowChainOwnerEnvFileIfConfigured
    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }
    return $value
}

function Add-FlowChainReadinessProblem {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Problems,
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Reason,
        [ValidateSet("blocked", "failed")]
        [string] $Kind = "blocked",
        [ValidateSet("env", "artifact", "endpoint", "process", "report")]
        [string] $Category = "env"
    )

    [void] $Problems.Add([ordered]@{
        name = $Name
        category = $Category
        kind = $Kind
        reason = $Reason
    })
}

function Convert-FlowChainUInt {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [AllowNull()][string] $Value,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Problems,
        [switch] $AllowZero
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    if ($Value -notmatch '^(0|[1-9][0-9]*)$') {
        Add-FlowChainReadinessProblem -Problems $Problems -Name $Name -Reason "must be a decimal integer" -Kind "failed"
        return $null
    }
    try {
        $parsed = [System.Numerics.BigInteger]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
        if (-not $AllowZero -and $parsed -eq 0) {
            Add-FlowChainReadinessProblem -Problems $Problems -Name $Name -Reason "must be nonzero" -Kind "failed"
        }
        return $parsed
    }
    catch {
        Add-FlowChainReadinessProblem -Problems $Problems -Name $Name -Reason "outside supported integer range" -Kind "failed"
        return $null
    }
}

function Test-FlowChainLocalUri {
    param([Parameter(Mandatory = $true)][System.Uri] $Uri)

    $hostName = $Uri.Host.ToLowerInvariant()
    return $hostName -in @("127.0.0.1", "localhost", "::1")
}

function Join-FlowChainEndpointUri {
    param(
        [Parameter(Mandatory = $true)][string] $PublicUrl,
        [Parameter(Mandatory = $true)][string] $EndpointPath
    )

    $uri = [System.Uri]::new($PublicUrl)
    $prefix = $uri.AbsolutePath
    if ($prefix -eq "/") {
        $prefix = ""
    }
    elseif ($prefix.EndsWith("/rpc", [System.StringComparison]::OrdinalIgnoreCase)) {
        $prefix = $prefix.Substring(0, $prefix.Length - 4).TrimEnd("/")
    }
    else {
        $prefix = $prefix.TrimEnd("/")
    }

    $builder = [System.UriBuilder]::new($uri)
    $builder.Path = ($prefix + "/" + $EndpointPath.TrimStart("/"))
    $builder.Query = ""
    return $builder.Uri.AbsoluteUri
}

function Invoke-FlowChainJsonGet {
    param(
        [Parameter(Mandatory = $true)][string] $PublicUrl,
        [Parameter(Mandatory = $true)][string] $EndpointPath,
        [int] $TimeoutSec = 10
    )

    $uri = Join-FlowChainEndpointUri -PublicUrl $PublicUrl -EndpointPath $EndpointPath
    return Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec $TimeoutSec
}

function Invoke-FlowChainJsonRpc {
    param(
        [Parameter(Mandatory = $true)][string] $PublicUrl,
        [Parameter(Mandatory = $true)][string] $Method,
        [AllowNull()][object] $Params = $null,
        [int] $TimeoutSec = 10
    )

    $uri = Join-FlowChainEndpointUri -PublicUrl $PublicUrl -EndpointPath "/rpc"
    $payload = [ordered]@{
        jsonrpc = "2.0"
        id = $Method
        method = $Method
    }
    if ($null -ne $Params) {
        $payload.params = $Params
    }
    $body = $payload | ConvertTo-Json -Depth 12 -Compress
    return Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json" -Body $body -TimeoutSec $TimeoutSec
}

function Read-FlowChainJsonIfExists {
    param([Parameter(Mandatory = $true)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Get-FlowChainJsonString {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string[]] $Names,
        [string] $Fallback = $null
    )

    if ($null -eq $Object) {
        return $Fallback
    }
    foreach ($name in $Names) {
        if ($Object.PSObject.Properties.Name -contains $name) {
            $value = $Object.$name
            if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace("$value")) {
                return "$value"
            }
        }
    }
    return $Fallback
}

function Get-FlowChainStateFacts {
    param([Parameter(Mandatory = $true)][string] $StatePath)

    $facts = [ordered]@{
        readable = $false
        statePathConfigured = $true
        chainId = $null
        latestHeight = $null
        latestHash = $null
        latestRoot = $null
        latestBlockTimestamp = $null
        latestBlockAgeSeconds = $null
        stateFileLastWriteAgeSeconds = $null
        finalizedHeight = $null
        finalizedHash = $null
        mempoolDepth = $null
        peerCount = $null
        blockCount = 0
    }

    if (-not (Test-Path -LiteralPath $StatePath)) {
        return $facts
    }

    try {
        $stateItem = Get-Item -LiteralPath $StatePath
        $facts.stateFileLastWriteAgeSeconds = [Math]::Max(0, [int64](([DateTimeOffset]::UtcNow - $stateItem.LastWriteTimeUtc).TotalSeconds))
    }
    catch {
        $facts.stateFileLastWriteAgeSeconds = $null
    }

    try {
        $state = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json
    }
    catch {
        return $facts
    }

    $facts.readable = $true
    $facts.chainId = Get-FlowChainJsonString -Object $state -Names @("chainId")
    $blocks = @()
    if ($state.PSObject.Properties.Name -contains "blocks" -and $null -ne $state.blocks) {
        $blocks = @($state.blocks)
    }
    $facts.blockCount = $blocks.Count
    if ($blocks.Count -gt 0) {
        $latest = $blocks[$blocks.Count - 1]
        $facts.latestHeight = Get-FlowChainJsonString -Object $latest -Names @("blockNumber", "height", "number")
        $facts.latestHash = Get-FlowChainJsonString -Object $latest -Names @("blockHash", "hash")
        $facts.latestRoot = Get-FlowChainJsonString -Object $latest -Names @("stateRoot", "root")
        $timestamp = Get-FlowChainJsonString -Object $latest -Names @("logicalTime", "timestamp", "createdAt", "producedAt")
        $facts.latestBlockTimestamp = $timestamp
        if ($timestamp -match '^[0-9]+$') {
            $nowUnix = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
            $facts.latestBlockAgeSeconds = [Math]::Max(0, $nowUnix - [int64]$timestamp)
        }
        elseif (-not [string]::IsNullOrWhiteSpace($timestamp)) {
            try {
                $parsed = [DateTimeOffset]::Parse($timestamp, [System.Globalization.CultureInfo]::InvariantCulture)
                $facts.latestBlockAgeSeconds = [Math]::Max(0, [int64](([DateTimeOffset]::UtcNow - $parsed).TotalSeconds))
            }
            catch {
                $facts.latestBlockAgeSeconds = $null
            }
        }
        if ($null -ne $facts.stateFileLastWriteAgeSeconds) {
            if ($null -eq $facts.latestBlockAgeSeconds) {
                $facts.latestBlockAgeSeconds = $facts.stateFileLastWriteAgeSeconds
            }
            else {
                $facts.latestBlockAgeSeconds = [Math]::Min([int64]$facts.latestBlockAgeSeconds, [int64]$facts.stateFileLastWriteAgeSeconds)
            }
        }
    }
    if ([string]::IsNullOrWhiteSpace($facts.latestRoot)) {
        $facts.latestRoot = Get-FlowChainJsonString -Object $state -Names @("stateRoot", "root", "parentHash")
    }

    $facts.finalizedHeight = Get-FlowChainJsonString -Object $state -Names @("finalizedHeight", "finalizedBlock")
    if ([string]::IsNullOrWhiteSpace($facts.finalizedHeight)) {
        $facts.finalizedHeight = $facts.latestHeight
    }
    if (-not [string]::IsNullOrWhiteSpace($facts.finalizedHeight)) {
        foreach ($block in $blocks) {
            $height = Get-FlowChainJsonString -Object $block -Names @("blockNumber", "height", "number")
            if ($height -eq $facts.finalizedHeight) {
                $facts.finalizedHash = Get-FlowChainJsonString -Object $block -Names @("blockHash", "hash")
                break
            }
        }
    }

    if ($state.PSObject.Properties.Name -contains "pendingTxs" -and $null -ne $state.pendingTxs) {
        $facts.mempoolDepth = @($state.pendingTxs).Count
    }
    if ($state.PSObject.Properties.Name -contains "peers" -and $null -ne $state.peers) {
        $facts.peerCount = @($state.peers).Count
    }

    return $facts
}

function Get-FlowChainBlockFacts {
    param(
        [Parameter(Mandatory = $true)][string] $StatePath,
        [AllowNull()][string] $BlockNumber
    )

    $facts = [ordered]@{
        found = $false
        blockNumber = $BlockNumber
        blockHash = $null
        stateRoot = $null
    }

    if ([string]::IsNullOrWhiteSpace($BlockNumber) -or -not (Test-Path -LiteralPath $StatePath)) {
        return $facts
    }

    try {
        $state = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json
    }
    catch {
        return $facts
    }

    if (-not ($state.PSObject.Properties.Name -contains "blocks") -or $null -eq $state.blocks) {
        return $facts
    }

    foreach ($block in @($state.blocks)) {
        $height = Get-FlowChainJsonString -Object $block -Names @("blockNumber", "height", "number")
        if ($height -eq $BlockNumber) {
            $facts.found = $true
            $facts.blockHash = Get-FlowChainJsonString -Object $block -Names @("blockHash", "hash")
            $facts.stateRoot = Get-FlowChainJsonString -Object $block -Names @("stateRoot", "root")
            return $facts
        }
    }

    return $facts
}

function Test-FlowChainPid {
    param(
        [Parameter(Mandatory = $true)][string] $PidPath,
        [string[]] $CommandLineIncludes = @()
    )

    $result = [ordered]@{
        configured = Test-Path -LiteralPath $PidPath
        running = $false
        pid = $null
        commandLineMatched = $false
    }
    if (-not $result.configured) {
        return $result
    }
    $raw = (Get-Content -Raw -LiteralPath $PidPath).Trim()
    if ($raw -notmatch '^[0-9]+$') {
        return $result
    }
    $pidValue = [int]$raw
    $result.pid = $pidValue
    $process = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
    if (-not $process) {
        return $result
    }
    $result.running = $true
    if ($CommandLineIncludes.Count -eq 0) {
        $result.commandLineMatched = $true
        return $result
    }
    try {
        $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$pidValue").CommandLine
        $result.commandLineMatched = $true
        foreach ($needle in $CommandLineIncludes) {
            if ($commandLine -notlike "*$needle*") {
                $result.commandLineMatched = $false
            }
        }
    }
    catch {
        $result.commandLineMatched = $false
    }
    return $result
}

function Find-FlowChainNodeProcess {
    param(
        [Parameter(Mandatory = $true)][string] $StatePath,
        [Parameter(Mandatory = $true)][string] $NodeDir
    )

    $stateFullPath = [System.IO.Path]::GetFullPath($StatePath)
    $nodeFullDir = [System.IO.Path]::GetFullPath($NodeDir)
    $matches = New-Object System.Collections.ArrayList

    foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) {
        $commandLine = [string]$process.CommandLine
        if ([string]::IsNullOrWhiteSpace($commandLine)) {
            continue
        }
        if ($commandLine -notlike "*flowmemory-devnet*") {
            continue
        }
        if ($commandLine -notlike "*--state*" -or $commandLine -notlike "*$stateFullPath*") {
            continue
        }
        if ($commandLine -notlike "*--node-dir*" -or $commandLine -notlike "*$nodeFullDir*") {
            continue
        }
        if ($commandLine -notlike "* node *") {
            continue
        }

        [void]$matches.Add([ordered]@{
            pid = [int]$process.ProcessId
            name = [string]$process.Name
        })
    }

    return @($matches | Sort-Object { $_.pid })
}

function Get-FlowChainPackageScripts {
    param([Parameter(Mandatory = $true)][string] $RepoRoot)
    $package = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot "package.json") | ConvertFrom-Json
    return @($package.scripts.PSObject.Properties.Name)
}

function Test-FlowChainResponseHygiene {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]] $Responses,
        [string[]] $EnvNames = @()
    )

    $text = $Responses | ConvertTo-Json -Depth 32
    if ($null -eq $text) {
        $text = ""
    }
    $findings = New-Object System.Collections.ArrayList
    foreach ($envName in $EnvNames) {
        $value = Get-FlowChainEnvValue -Name $envName
        if ([string]::IsNullOrWhiteSpace($value) -or $value.Length -lt 8) {
            continue
        }
        if ($text.IndexOf($value, [System.StringComparison]::Ordinal) -ge 0) {
            [void] $findings.Add([ordered]@{
                envName = $envName
                reason = "response included a raw configured env value"
            })
        }
    }

    foreach ($pattern in @(
            "BEGIN RSA PRIVATE KEY",
            "BEGIN OPENSSH PRIVATE KEY",
            ("BEGIN " + "PRIVATE KEY"),
            "seedPhrase",
            "mnemonicPhrase",
            "privateKey",
            "private_key",
            "webhookUrl",
            "webhook_url"
        )) {
        if ($text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            [void] $findings.Add([ordered]@{
                envName = ""
                reason = "response included secret marker '$pattern'"
            })
        }
    }

    return [ordered]@{
        passed = $findings.Count -eq 0
        findings = @($findings)
    }
}
