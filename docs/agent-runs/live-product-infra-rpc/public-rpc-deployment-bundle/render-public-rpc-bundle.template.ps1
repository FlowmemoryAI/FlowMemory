param(
    [string] $BundleDir = ".",
    [string] $RenderDir = "<FLOWCHAIN_DEPLOY_RENDER_DIR>",
    [string] $OwnerEnvFile = "<FLOWCHAIN_OWNER_ENV_FILE>",
    [string] $RepoRoot = "<FLOWCHAIN_REPO_ABSOLUTE_PATH>",
    [string] $ServiceUser = "<FLOWCHAIN_SERVICE_USER>",
    [string] $ServiceGroup = "<FLOWCHAIN_SERVICE_GROUP>",
    [string] $CargoTargetDir = "<FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR>",
    [string] $TlsCertificatePath = "<PATH_TO_TLS_CERTIFICATE>",
    [string] $TlsCertificateKeyPath = "<PATH_TO_TLS_CERTIFICATE_KEY>",
    [string] $NginxExe = "<FLOWCHAIN_NGINX_EXE>"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Convert-ToFullPath {
    param([Parameter(Mandatory = $true)][string] $Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-IsInsidePath {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $Root
    )

    $fullPath = Convert-ToFullPath -Path $Path
    $fullRoot = (Convert-ToFullPath -Path $Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    return $fullPath.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $fullPath.StartsWith("$fullRoot$([System.IO.Path]::DirectorySeparatorChar)", [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-NotInsideRepo {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $Label
    )

    if (Test-IsInsidePath -Path $Path -Root $RepoRoot) {
        throw "$Label must be outside the FlowChain repository so rendered owner values are not committed."
    }
}

function Read-OwnerEnvFile {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Owner env file was not found."
    }
    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*(#|$)') {
            continue
        }
        if ($line -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            throw "Owner env file contains an invalid KEY=VALUE line."
        }
        $values[$matches[1]] = $matches[2].Trim()
    }
    return $values
}

function Get-FlowChainEnvValue {
    param(
        [Parameter(Mandatory = $true)][hashtable] $OwnerValues,
        [Parameter(Mandatory = $true)][string] $Name
    )

    $processValue = [Environment]::GetEnvironmentVariable($Name, "Process")
    if (-not [string]::IsNullOrWhiteSpace($processValue)) {
        return $processValue.Trim()
    }
    if ($OwnerValues.ContainsKey($Name) -and -not [string]::IsNullOrWhiteSpace([string]$OwnerValues[$Name])) {
        return [string]$OwnerValues[$Name]
    }
    throw "$Name is required in the owner env file or current process environment."
}

function Get-AllowedHttpsOrigins {
    param([Parameter(Mandatory = $true)][string] $Value)

    $origins = New-Object System.Collections.ArrayList
    foreach ($rawOrigin in @($Value.Split(","))) {
        $origin = $rawOrigin.Trim().TrimEnd("/")
        if ([string]::IsNullOrWhiteSpace($origin)) {
            continue
        }
        if ($origin -eq "*") {
            throw "FLOWCHAIN_RPC_ALLOWED_ORIGINS must contain only exact https origins, never wildcard origins."
        }
        [System.Uri] $uri = $null
        if (-not [System.Uri]::TryCreate($origin, [System.UriKind]::Absolute, [ref]$uri) `
            -or $uri.Scheme -ne "https" `
            -or [string]::IsNullOrWhiteSpace($uri.Host) `
            -or -not [string]::IsNullOrWhiteSpace($uri.Query) `
            -or -not [string]::IsNullOrWhiteSpace($uri.Fragment) `
            -or -not [string]::IsNullOrWhiteSpace($uri.UserInfo) `
            -or $uri.AbsolutePath -ne "/") {
            throw "FLOWCHAIN_RPC_ALLOWED_ORIGINS must contain only exact https origins without paths, query strings, fragments, or credentials."
        }
        if (-not $origins.Contains($origin)) {
            [void]$origins.Add($origin)
        }
    }
    if ($origins.Count -lt 1) {
        throw "FLOWCHAIN_RPC_ALLOWED_ORIGINS must contain at least one exact https origin."
    }
    return @($origins)
}

function Get-RequiredParameter {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Value
    )

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.StartsWith("<FLOWCHAIN_", [System.StringComparison]::Ordinal) -or $Value.StartsWith("<PATH_TO_", [System.StringComparison]::Ordinal)) {
        throw "$Name must be supplied by the owner host."
    }
    return $Value
}

function Render-Template {
    param(
        [Parameter(Mandatory = $true)][string] $TemplatePath,
        [Parameter(Mandatory = $true)][string] $OutPath,
        [Parameter(Mandatory = $true)][hashtable] $Replacements
    )

    $text = Get-Content -Raw -LiteralPath $TemplatePath
    foreach ($key in $Replacements.Keys) {
        $text = $text.Replace($key, [string]$Replacements[$key])
    }
    $remainingPlaceholders = @($Replacements.Keys | Where-Object { $text.Contains([string]$_) })
    if ($remainingPlaceholders.Count -gt 0) {
        throw "Rendered output still contains replacement placeholders: $(Split-Path -Leaf $OutPath)"
    }
    if ($text -match '<FLOWCHAIN_|<PATH_TO_') {
        throw "Rendered output still contains an unknown FlowChain placeholder: $(Split-Path -Leaf $OutPath)"
    }
    Set-Content -LiteralPath $OutPath -Value $text -Encoding UTF8
}

$repoFullPath = Convert-ToFullPath -Path (Get-RequiredParameter -Name "RepoRoot" -Value $RepoRoot)
$bundleFullPath = Convert-ToFullPath -Path $BundleDir
$renderFullPath = Convert-ToFullPath -Path (Get-RequiredParameter -Name "RenderDir" -Value $RenderDir)
$ownerEnvFullPath = Convert-ToFullPath -Path (Get-RequiredParameter -Name "OwnerEnvFile" -Value $OwnerEnvFile)
Assert-NotInsideRepo -Path $renderFullPath -Label "RenderDir"
Assert-NotInsideRepo -Path $ownerEnvFullPath -Label "OwnerEnvFile"
New-Item -ItemType Directory -Force -Path $renderFullPath | Out-Null

$ownerValues = Read-OwnerEnvFile -Path $ownerEnvFullPath
$requiredEnvNames = @(
    "FLOWCHAIN_RPC_PUBLIC_URL",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_RPC_TLS_TERMINATED",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH",
    "FLOWCHAIN_TESTER_WRITE_ENABLED",
    "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
    "FLOWCHAIN_TESTER_MAX_SEND_UNITS"
)
foreach ($name in $requiredEnvNames) {
    [void](Get-FlowChainEnvValue -OwnerValues $ownerValues -Name $name)
}

$publicUrl = Get-FlowChainEnvValue -OwnerValues $ownerValues -Name "FLOWCHAIN_RPC_PUBLIC_URL"
[System.Uri] $publicUri = $null
if (-not [System.Uri]::TryCreate($publicUrl, [System.UriKind]::Absolute, [ref]$publicUri) `
    -or $publicUri.Scheme -ne "https" `
    -or [string]::IsNullOrWhiteSpace($publicUri.Host) `
    -or -not [string]::IsNullOrWhiteSpace($publicUri.Query) `
    -or -not [string]::IsNullOrWhiteSpace($publicUri.Fragment) `
    -or -not [string]::IsNullOrWhiteSpace($publicUri.UserInfo) `
    -or $publicUri.AbsolutePath -ne "/") {
    throw "FLOWCHAIN_RPC_PUBLIC_URL must be an exact https origin without paths, query strings, fragments, or credentials before rendering public RPC files."
}
$publicUrl = $publicUrl.TrimEnd("/")
$allowedOrigins = @(Get-AllowedHttpsOrigins -Value (Get-FlowChainEnvValue -OwnerValues $ownerValues -Name "FLOWCHAIN_RPC_ALLOWED_ORIGINS"))
$rateLimit = Get-FlowChainEnvValue -OwnerValues $ownerValues -Name "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE"
if ($rateLimit -notmatch '^[1-9][0-9]*$') {
    throw "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE must be a positive integer."
}
if ((Get-FlowChainEnvValue -OwnerValues $ownerValues -Name "FLOWCHAIN_RPC_TLS_TERMINATED").ToLowerInvariant() -ne "true") {
    throw "FLOWCHAIN_RPC_TLS_TERMINATED must be true before rendering public RPC files."
}
if ((Get-FlowChainEnvValue -OwnerValues $ownerValues -Name "FLOWCHAIN_TESTER_WRITE_ENABLED").ToLowerInvariant() -ne "true") {
    throw "FLOWCHAIN_TESTER_WRITE_ENABLED must be true before rendering external tester gateway files."
}
$testerTokenHash = Get-FlowChainEnvValue -OwnerValues $ownerValues -Name "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256"
if ($testerTokenHash -notmatch '^[A-Fa-f0-9]{64}$') {
    throw "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256 must be a SHA-256 hex digest before rendering external tester gateway files."
}
$testerMaxSendUnits = Get-FlowChainEnvValue -OwnerValues $ownerValues -Name "FLOWCHAIN_TESTER_MAX_SEND_UNITS"
if ($testerMaxSendUnits -notmatch '^[1-9][0-9]*$') {
    throw "FLOWCHAIN_TESTER_MAX_SEND_UNITS must be a positive integer before rendering external tester gateway files."
}
[void](Get-FlowChainEnvValue -OwnerValues $ownerValues -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH")

$renderedNginxConf = Join-Path $renderFullPath "nginx-flowchain-rpc.conf"
$renderedLiveUnit = Join-Path $renderFullPath "flowchain-live.service"
$renderedSupervisorUnit = Join-Path $renderFullPath "flowchain-supervisor.service"
$renderedShellPreflight = Join-Path $renderFullPath "nginx-preflight.sh"
$renderedWindowsPreflight = Join-Path $renderFullPath "nginx-preflight.ps1"
$renderedReport = Join-Path $renderFullPath "public-rpc-render-report.json"
$cargoTarget = if ([string]::IsNullOrWhiteSpace($CargoTargetDir) -or $CargoTargetDir.StartsWith("<FLOWCHAIN_", [System.StringComparison]::Ordinal)) {
    Join-Path $repoFullPath "devnet/local/cargo-target-control-plane"
}
else {
    Convert-ToFullPath -Path $CargoTargetDir
}

$replacements = @{
    "<FLOWCHAIN_RPC_PUBLIC_HOST>" = $publicUri.Host
    "<FLOWCHAIN_RPC_PUBLIC_URL>" = $publicUrl.TrimEnd("/")
    "<FLOWCHAIN_RPC_ALLOWED_ORIGIN>" = $allowedOrigins[0]
    "<FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>" = $rateLimit
    "<PATH_TO_TLS_CERTIFICATE>" = (Get-RequiredParameter -Name "TlsCertificatePath" -Value $TlsCertificatePath)
    "<PATH_TO_TLS_CERTIFICATE_KEY>" = (Get-RequiredParameter -Name "TlsCertificateKeyPath" -Value $TlsCertificateKeyPath)
    "<FLOWCHAIN_REPO_ABSOLUTE_PATH>" = $repoFullPath
    "<FLOWCHAIN_SERVICE_USER>" = (Get-RequiredParameter -Name "ServiceUser" -Value $ServiceUser)
    "<FLOWCHAIN_SERVICE_GROUP>" = (Get-RequiredParameter -Name "ServiceGroup" -Value $ServiceGroup)
    "<FLOWCHAIN_OWNER_ENV_FILE>" = $ownerEnvFullPath
    "<FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR>" = $cargoTarget
    "<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>" = $renderedNginxConf
    "<FLOWCHAIN_NGINX_EXE>" = (Get-RequiredParameter -Name "NginxExe" -Value $NginxExe)
    "<FLOWCHAIN_NGINX_PREFLIGHT_SCRIPT>" = $renderedShellPreflight
    "<FLOWCHAIN_NGINX_WINDOWS_PREFLIGHT_SCRIPT>" = $renderedWindowsPreflight
    "<FLOWCHAIN_SYSTEMD_RENDERED_UNIT>" = $renderedLiveUnit
    "<FLOWCHAIN_SUPERVISOR_SYSTEMD_RENDERED_UNIT>" = $renderedSupervisorUnit
    "<PREVIOUS_FLOWCHAIN_RPC_NGINX_CONF>" = (Join-Path $renderFullPath "previous-nginx-flowchain-rpc.conf")
    "<FLOWCHAIN_DEPLOY_RENDER_DIR>" = $renderFullPath
}

Render-Template -TemplatePath (Join-Path $bundleFullPath "nginx-flowchain-rpc.template.conf") -OutPath $renderedNginxConf -Replacements $replacements
Render-Template -TemplatePath (Join-Path $bundleFullPath "flowchain-live.service.template") -OutPath $renderedLiveUnit -Replacements $replacements
Render-Template -TemplatePath (Join-Path $bundleFullPath "flowchain-supervisor.service.template") -OutPath $renderedSupervisorUnit -Replacements $replacements
Render-Template -TemplatePath (Join-Path $bundleFullPath "nginx-preflight.template.sh") -OutPath $renderedShellPreflight -Replacements $replacements
Render-Template -TemplatePath (Join-Path $bundleFullPath "nginx-preflight.template.ps1") -OutPath $renderedWindowsPreflight -Replacements $replacements

$report = [ordered]@{
    schema = "flowchain.public_rpc_owner_render_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "passed"
    renderedFiles = @(
        "nginx-flowchain-rpc.conf",
        "flowchain-live.service",
        "flowchain-supervisor.service",
        "nginx-preflight.sh",
        "nginx-preflight.ps1"
    )
    requiredEnvNames = $requiredEnvNames
    allowedOriginCount = $allowedOrigins.Count
    renderDirInsideRepo = $false
    ownerEnvFileInsideRepo = $false
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $renderedReport -Encoding UTF8
Write-Host "FlowChain public RPC bundle rendered. Report: $renderedReport"
