$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-FlowChainEnvValue {
    param([Parameter(Mandatory = $true)][string] $Name)
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
            ("BEGIN RSA " + "PRIVATE KEY"),
            ("BEGIN OPENSSH " + "PRIVATE KEY"),
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
