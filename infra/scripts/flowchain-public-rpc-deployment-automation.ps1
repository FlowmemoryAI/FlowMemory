param(
    [ValidateSet("Plan", "Render", "Validate")]
    [string] $Action = "Validate",
    [string] $BundleDir = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_DEPLOYMENT_AUTOMATION.md",
    [string] $RenderReportSnapshotPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-render-report-snapshot.json",
    [string] $RenderDir = "",
    [string] $OwnerEnvFile = "",
    [string] $ServiceUser = "flowchain",
    [string] $ServiceGroup = "flowchain",
    [string] $CargoTargetDir = "",
    [string] $TlsCertificatePath = "",
    [string] $TlsCertificateKeyPath = "",
    [string] $NginxExe = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$bundleFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BundleDir)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$renderReportSnapshotFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $RenderReportSnapshotPath)
$bundleReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json"
$renderScriptPath = Join-Path $bundleFullDir "render-public-rpc-bundle.template.ps1"

function Get-DeployProp {
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

function Test-DeployPathInsideRoot {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $Root
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    return $fullPath.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $fullPath.StartsWith("$fullRoot$([System.IO.Path]::DirectorySeparatorChar)", [System.StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-DeploymentSafeLine {
    param([AllowNull()][object] $Line)

    $text = "$Line"
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "https?://[^\s,)]+", "<redacted-url>")
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "(?i)(FLOWCHAIN_[A-Z0-9_]+\s*=\s*)(.+)$", '${1}<redacted>')
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "(?i)(TOKEN_SHA256\s*[:=]\s*)([A-Fa-f0-9]{64})", '${1}<redacted>')
    return $text
}

function Get-DeploymentSecretMarkerFindings {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Label
    )

    $patterns = @(
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
    )

    $findings = New-Object System.Collections.ArrayList
    foreach ($pattern in $patterns) {
        if ($Text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            [void] $findings.Add([ordered]@{
                label = $Label
                marker = $pattern
            })
        }
    }
    return @($findings)
}

function Get-DeploymentChecksPassed {
    param([Parameter(Mandatory = $true)][System.Collections.Specialized.OrderedDictionary] $Checks)

    foreach ($value in $Checks.Values) {
        if ($value -ne $true) {
            return $false
        }
    }
    return $true
}

function Get-DeploymentFileSha256 {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }

    return ([string](Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash).ToLowerInvariant()
}

function New-DeploymentRenderReportSummary {
    param(
        [AllowNull()][object] $Report,
        [string[]] $RenderedFileNames = @()
    )

    if ($null -eq $Report) {
        return $null
    }

    $renderedFiles = @((Get-DeployProp -Object $Report -Name "renderedFiles" -Default @()) | ForEach-Object { "$_" })
    if ($renderedFiles.Count -eq 0) {
        $renderedFiles = @($RenderedFileNames | ForEach-Object { "$_" })
    }
    $requiredEnvNames = @((Get-DeployProp -Object $Report -Name "requiredEnvNames" -Default @()) | ForEach-Object { "$_" })

    return [ordered]@{
        schema = [string](Get-DeployProp -Object $Report -Name "schema" -Default "")
        status = [string](Get-DeployProp -Object $Report -Name "status" -Default "")
        renderedFileCount = $renderedFiles.Count
        renderedFiles = @($renderedFiles)
        requiredEnvNameCount = $requiredEnvNames.Count
        requiredEnvNames = @($requiredEnvNames)
        allowedOriginCount = [int](Get-DeployProp -Object $Report -Name "allowedOriginCount" -Default 0)
        renderDirInsideRepo = [bool](Get-DeployProp -Object $Report -Name "renderDirInsideRepo" -Default $true)
        ownerEnvFileInsideRepo = [bool](Get-DeployProp -Object $Report -Name "ownerEnvFileInsideRepo" -Default $true)
        envValuesPrinted = [bool](Get-DeployProp -Object $Report -Name "envValuesPrinted" -Default $true)
        noSecrets = [bool](Get-DeployProp -Object $Report -Name "noSecrets" -Default $false)
        broadcasts = [bool](Get-DeployProp -Object $Report -Name "broadcasts" -Default $true)
    }
}

function New-RenderedArtifactManifest {
    param([Parameter(Mandatory = $true)][string] $TargetRenderDir)

    $artifactDefinitions = @(
        [ordered]@{
            fileName = "nginx-flowchain-rpc.conf"
            role = "public-rpc-nginx-edge"
            installRequired = $true
            installTarget = "/etc/nginx/conf.d/flowchain-rpc.conf"
            installCommand = "install -m 0644 <FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-flowchain-rpc.conf /etc/nginx/conf.d/flowchain-rpc.conf"
            verifyCommand = "nginx -t"
            rollbackCommand = "cp <PREVIOUS_FLOWCHAIN_RPC_NGINX_CONF> /etc/nginx/conf.d/flowchain-rpc.conf"
        },
        [ordered]@{
            fileName = "flowchain-live.service"
            role = "block-producer-systemd-unit"
            installRequired = $true
            installTarget = "/etc/systemd/system/flowchain-live.service"
            installCommand = "npm run flowchain:service:install:systemd -- -Action Install -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>"
            verifyCommand = "systemd-analyze verify <FLOWCHAIN_DEPLOY_RENDER_DIR>/flowchain-live.service"
            rollbackCommand = "systemctl stop flowchain-live.service"
        },
        [ordered]@{
            fileName = "flowchain-supervisor.service"
            role = "autorecovery-supervisor-systemd-unit"
            installRequired = $true
            installTarget = "/etc/systemd/system/flowchain-supervisor.service"
            installCommand = "npm run flowchain:service:install:systemd -- -Action Install -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>"
            verifyCommand = "systemd-analyze verify <FLOWCHAIN_DEPLOY_RENDER_DIR>/flowchain-supervisor.service"
            rollbackCommand = "systemctl stop flowchain-supervisor.service"
        },
        [ordered]@{
            fileName = "nginx-preflight.sh"
            role = "linux-public-rpc-preflight"
            installRequired = $false
            installTarget = "<FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.sh"
            installCommand = "chmod 0750 <FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.sh"
            verifyCommand = "bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.sh"
            rollbackCommand = ""
        },
        [ordered]@{
            fileName = "nginx-preflight.ps1"
            role = "windows-public-rpc-preflight"
            installRequired = $false
            installTarget = "<FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.ps1"
            installCommand = ""
            verifyCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.ps1"
            rollbackCommand = ""
        },
        [ordered]@{
            fileName = "public-rpc-render-report.json"
            role = "render-evidence"
            installRequired = $false
            installTarget = "<FLOWCHAIN_DEPLOY_RENDER_DIR>/public-rpc-render-report.json"
            installCommand = "retain <FLOWCHAIN_DEPLOY_RENDER_DIR>/public-rpc-render-report.json as owner-host evidence"
            verifyCommand = "npm run flowchain:public-rpc:deployment:automation"
            rollbackCommand = ""
        },
        [ordered]@{
            fileName = "owner-host-apply.sh"
            role = "owner-host-apply-script"
            installRequired = $false
            installTarget = "<FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh"
            installCommand = "bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh plan"
            verifyCommand = "bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh plan"
            rollbackCommand = "bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh rollback"
        },
        [ordered]@{
            fileName = "owner-host-apply.ps1"
            role = "windows-owner-host-apply-script"
            installRequired = $false
            installTarget = "<FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1"
            installCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Plan"
            verifyCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Plan"
            rollbackCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Rollback"
        }
    )

    $manifest = New-Object System.Collections.ArrayList
    foreach ($definition in $artifactDefinitions) {
        $artifactPath = Join-Path $TargetRenderDir $definition.fileName
        $exists = Test-Path -LiteralPath $artifactPath
        $item = [ordered]@{
            fileName = $definition.fileName
            relativePath = $definition.fileName
            role = $definition.role
            installRequired = [bool]$definition.installRequired
            installTarget = $definition.installTarget
            installCommand = $definition.installCommand
            verifyCommand = $definition.verifyCommand
            rollbackCommand = $definition.rollbackCommand
            exists = $exists
            sizeBytes = if ($exists) { [int64](Get-Item -LiteralPath $artifactPath).Length } else { 0 }
            sha256 = Get-DeploymentFileSha256 -Path $artifactPath
        }
        [void]$manifest.Add($item)
    }
    return @($manifest)
}

function New-OwnerHostApplyScript {
    param([Parameter(Mandatory = $true)][string] $TargetRenderDir)

    $artifactNamesToVerifyBeforeApply = @(
        "nginx-flowchain-rpc.conf",
        "flowchain-live.service",
        "flowchain-supervisor.service",
        "nginx-preflight.sh",
        "nginx-preflight.ps1",
        "public-rpc-render-report.json"
    )
    $hashCommands = New-Object System.Collections.ArrayList
    foreach ($name in $artifactNamesToVerifyBeforeApply) {
        $path = Join-Path $TargetRenderDir $name
        $hash = Get-DeploymentFileSha256 -Path $path
        [void]$hashCommands.Add("verify_file '$name' '$hash'")
    }

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($line in @(
            '#!/usr/bin/env bash',
            'set -euo pipefail',
            'ACTION="${1:-plan}"',
            'RENDER_DIR="${FLOWCHAIN_DEPLOY_RENDER_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"',
            'NGINX_TARGET="${FLOWCHAIN_NGINX_TARGET:-/etc/nginx/conf.d/flowchain-rpc.conf}"',
            'PREVIOUS_NGINX="${FLOWCHAIN_PREVIOUS_NGINX_CONF:-${RENDER_DIR}/previous-nginx-flowchain-rpc.conf}"',
            '',
            'need_root() {',
            '  if [ "$(id -u)" -ne 0 ]; then',
            '    echo "owner-host apply requires root for systemd and nginx install actions" >&2',
            '    exit 1',
            '  fi',
            '}',
            '',
            'verify_file() {',
            '  local name="$1"',
            '  local expected="$2"',
            '  if [ -z "${expected}" ]; then',
            '    echo "missing hash for ${name}" >&2',
            '    exit 1',
            '  fi',
            '  printf "%s  %s/%s\n" "${expected}" "${RENDER_DIR}" "${name}" | sha256sum -c -',
            '}',
            '',
            'verify_artifacts() {'
        )) {
        $lines.Add($line)
    }
    foreach ($command in @($hashCommands)) {
        $lines.Add("  $command")
    }
    foreach ($line in @(
            '}',
            '',
            'plan() {',
            '  echo "FlowChain owner-host apply plan"',
            '  echo "1. verify rendered artifact hashes"',
            '  echo "2. verify systemd unit files"',
            '  echo "3. install FlowChain systemd services"',
            '  echo "4. back up and publish nginx RPC edge config"',
            '  echo "5. run public RPC, tester gateway, cutover, truth-table, and no-secret proof commands"',
            '  echo "6. use rollback mode if nginx/systemd install needs to be reverted"',
            '}',
            '',
            'apply() {',
            '  need_root',
            '  verify_artifacts',
            '  systemd-analyze verify "${RENDER_DIR}/flowchain-live.service"',
            '  systemd-analyze verify "${RENDER_DIR}/flowchain-supervisor.service"',
            '  npm run flowchain:service:install:systemd -- -Action Install -RenderDir "${RENDER_DIR}"',
            '  npm run flowchain:service:install:systemd -- -Action Status',
            '  npm run flowchain:service:status',
            '  if [ -f "${NGINX_TARGET}" ]; then',
            '    cp "${NGINX_TARGET}" "${PREVIOUS_NGINX}"',
            '  fi',
            '  install -m 0644 "${RENDER_DIR}/nginx-flowchain-rpc.conf" "${NGINX_TARGET}"',
            '  nginx -t',
            '  systemctl reload nginx',
            '  bash "${RENDER_DIR}/nginx-preflight.sh"',
            '  npm run flowchain:public-rpc:validate',
            '  npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked',
            '  npm run flowchain:public-rpc:abuse-test',
            '  npm run flowchain:tester:gateway:e2e',
            '  npm run flowchain:wallet:live-tester:e2e',
            '  npm run flowchain:live:cutover:rehearsal -- -AllowBlocked',
            '  npm run flowchain:truth-table -- -AllowBlocked',
            '  npm run flowchain:no-secret:scan',
            '}',
            '',
            'rollback() {',
            '  need_root',
            '  systemctl stop flowchain-supervisor.service || true',
            '  systemctl stop flowchain-live.service || true',
            '  npm run flowchain:service:install:systemd -- -Action Uninstall || true',
            '  if [ -f "${PREVIOUS_NGINX}" ]; then',
            '    cp "${PREVIOUS_NGINX}" "${NGINX_TARGET}"',
            '    nginx -t',
            '    systemctl reload nginx',
            '  fi',
            '  npm run flowchain:ops:snapshot -- -AllowBlocked || true',
            '}',
            '',
            'case "${ACTION}" in',
            '  plan) plan ;;',
            '  apply) apply ;;',
            '  rollback) rollback ;;',
            '  *) echo "usage: owner-host-apply.sh [plan|apply|rollback]" >&2; exit 2 ;;',
            'esac'
        )) {
        $lines.Add($line)
    }

    $scriptPath = Join-Path $TargetRenderDir "owner-host-apply.sh"
    $scriptText = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
    Assert-FlowChainNoSecretText -Text $scriptText -Label "public RPC owner-host apply script"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($scriptPath, $scriptText, $utf8NoBom)
    return $scriptPath
}

function New-OwnerHostApplyPowerShellScript {
    param([Parameter(Mandatory = $true)][string] $TargetRenderDir)

    $artifactNamesToVerifyBeforeApply = @(
        "nginx-flowchain-rpc.conf",
        "flowchain-live.service",
        "flowchain-supervisor.service",
        "nginx-preflight.sh",
        "nginx-preflight.ps1",
        "public-rpc-render-report.json"
    )
    $hashCommands = New-Object System.Collections.ArrayList
    foreach ($name in $artifactNamesToVerifyBeforeApply) {
        $path = Join-Path $TargetRenderDir $name
        $hash = Get-DeploymentFileSha256 -Path $path
        [void]$hashCommands.Add("    Verify-File -Name '$name' -ExpectedSha256 '$hash'")
    }

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($line in @(
            'param(',
            '    [ValidateSet("Plan", "Apply", "Rollback")]',
            '    [string] $Action = "Plan",',
            '    [string] $RenderDir = $(if ($env:FLOWCHAIN_DEPLOY_RENDER_DIR) { $env:FLOWCHAIN_DEPLOY_RENDER_DIR } else { $PSScriptRoot }),',
            '    [string] $NginxExe = $env:FLOWCHAIN_NGINX_EXE,',
            '    [string] $NginxTarget = $(if ($env:FLOWCHAIN_NGINX_TARGET) { $env:FLOWCHAIN_NGINX_TARGET } else { Join-Path $env:ProgramData "nginx\conf\conf.d\flowchain-rpc.conf" }),',
            '    [string] $PreviousNginx = $(if ($env:FLOWCHAIN_PREVIOUS_NGINX_CONF) { $env:FLOWCHAIN_PREVIOUS_NGINX_CONF } else { Join-Path $RenderDir "previous-nginx-flowchain-rpc.conf" })',
            ')',
            '',
            '$ErrorActionPreference = "Stop"',
            'Set-StrictMode -Version Latest',
            '',
            '$script:NpmCommand = Get-Command "npm.cmd" -ErrorAction SilentlyContinue',
            'if ($null -eq $script:NpmCommand) { $script:NpmCommand = Get-Command "npm" -ErrorAction Stop }',
            '',
            'function Require-Admin {',
            '    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()',
            '    $principal = [Security.Principal.WindowsPrincipal]::new($identity)',
            '    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {',
            '        throw "owner-host apply requires Administrator for Windows service and nginx install actions"',
            '    }',
            '}',
            '',
            'function Resolve-RenderedPath {',
            '    param([Parameter(Mandatory = $true)][string] $Name)',
            '    return Join-Path $RenderDir $Name',
            '}',
            '',
            'function Verify-File {',
            '    param(',
            '        [Parameter(Mandatory = $true)][string] $Name,',
            '        [Parameter(Mandatory = $true)][string] $ExpectedSha256',
            '    )',
            '    if ([string]::IsNullOrWhiteSpace($ExpectedSha256)) { throw "missing hash for $Name" }',
            '    $path = Resolve-RenderedPath -Name $Name',
            '    if (-not (Test-Path -LiteralPath $path)) { throw "missing rendered artifact $Name" }',
            '    $actual = ([string](Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash).ToLowerInvariant()',
            '    if ($actual -ne $ExpectedSha256.ToLowerInvariant()) { throw "hash mismatch for $Name" }',
            '    Write-Host "verified $Name"',
            '}',
            '',
            'function Verify-Artifacts {'
        )) {
        $lines.Add($line)
    }
    foreach ($command in @($hashCommands)) {
        $lines.Add($command)
    }
    foreach ($line in @(
            '}',
            '',
            'function Invoke-Npm {',
            '    param([Parameter(Mandatory = $true)][string[]] $Arguments)',
            '    & $script:NpmCommand.Source @Arguments',
            '    if ($LASTEXITCODE -ne 0) { throw "npm $($Arguments -join '' '') failed with exit $LASTEXITCODE" }',
            '}',
            '',
            'function Invoke-Nginx {',
            '    param([Parameter(Mandatory = $true)][string[]] $Arguments)',
            '    if ([string]::IsNullOrWhiteSpace($NginxExe)) { throw "NginxExe or FLOWCHAIN_NGINX_EXE is required." }',
            '    if (-not (Test-Path -LiteralPath $NginxExe)) { throw "nginx.exe was not found." }',
            '    & $NginxExe @Arguments',
            '    if ($LASTEXITCODE -ne 0) { throw "nginx $($Arguments -join '' '') failed with exit $LASTEXITCODE" }',
            '}',
            '',
            'function Plan {',
            '    Write-Host "FlowChain Windows owner-host apply plan"',
            '    Write-Host "1. verify rendered artifact hashes"',
            '    Write-Host "2. install or update the Windows autorecovery scheduled task"',
            '    Write-Host "3. back up and publish nginx RPC edge config"',
            '    Write-Host "4. run Windows nginx preflight, public RPC, tester gateway, cutover, truth-table, and no-secret proof commands"',
            '    Write-Host "5. use rollback mode if nginx or the scheduled task needs to be reverted"',
            '}',
            '',
            'function Apply {',
            '    Require-Admin',
            '    Verify-Artifacts',
            '    Invoke-Npm -Arguments @("run", "flowchain:service:install:windows", "--", "-Action", "Install")',
            '    Invoke-Npm -Arguments @("run", "flowchain:service:install:windows", "--", "-Action", "Status")',
            '    Invoke-Npm -Arguments @("run", "flowchain:service:status")',
            '    $targetParent = Split-Path -Parent $NginxTarget',
            '    if (-not [string]::IsNullOrWhiteSpace($targetParent)) { New-Item -ItemType Directory -Force -Path $targetParent | Out-Null }',
            '    if (Test-Path -LiteralPath $NginxTarget) { Copy-Item -LiteralPath $NginxTarget -Destination $PreviousNginx -Force }',
            '    Copy-Item -LiteralPath (Resolve-RenderedPath -Name "nginx-flowchain-rpc.conf") -Destination $NginxTarget -Force',
            '    Invoke-Nginx -Arguments @("-t")',
            '    Invoke-Nginx -Arguments @("-s", "reload")',
            '    & powershell -NoProfile -ExecutionPolicy Bypass -File (Resolve-RenderedPath -Name "nginx-preflight.ps1") -NginxExe $NginxExe',
            '    if ($LASTEXITCODE -ne 0) { throw "Windows nginx preflight failed with exit $LASTEXITCODE" }',
            '    Invoke-Npm -Arguments @("run", "flowchain:public-rpc:validate")',
            '    Invoke-Npm -Arguments @("run", "flowchain:public-rpc:synthetic-canary", "--", "-AllowBlocked")',
            '    Invoke-Npm -Arguments @("run", "flowchain:public-rpc:abuse-test")',
            '    Invoke-Npm -Arguments @("run", "flowchain:tester:gateway:e2e")',
            '    Invoke-Npm -Arguments @("run", "flowchain:wallet:live-tester:e2e")',
            '    Invoke-Npm -Arguments @("run", "flowchain:live:cutover:rehearsal", "--", "-AllowBlocked")',
            '    Invoke-Npm -Arguments @("run", "flowchain:truth-table", "--", "-AllowBlocked")',
            '    Invoke-Npm -Arguments @("run", "flowchain:no-secret:scan")',
            '}',
            '',
            'function Rollback {',
            '    Require-Admin',
            '    try { Invoke-Npm -Arguments @("run", "flowchain:service:install:windows", "--", "-Action", "Uninstall") } catch { Write-Warning $_.Exception.Message }',
            '    if (Test-Path -LiteralPath $PreviousNginx) {',
            '        Copy-Item -LiteralPath $PreviousNginx -Destination $NginxTarget -Force',
            '        Invoke-Nginx -Arguments @("-t")',
            '        Invoke-Nginx -Arguments @("-s", "reload")',
            '    }',
            '    try { Invoke-Npm -Arguments @("run", "flowchain:ops:snapshot", "--", "-AllowBlocked") } catch { Write-Warning $_.Exception.Message }',
            '}',
            '',
            'switch ($Action) {',
            '    "Plan" { Plan }',
            '    "Apply" { Apply }',
            '    "Rollback" { Rollback }',
            '}'
        )) {
        $lines.Add($line)
    }

    $scriptPath = Join-Path $TargetRenderDir "owner-host-apply.ps1"
    $scriptText = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
    Assert-FlowChainNoSecretText -Text $scriptText -Label "public RPC Windows owner-host apply script"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($scriptPath, $scriptText, $utf8NoBom)
    return $scriptPath
}

function New-OwnerHostApplyPlan {
    param(
        [AllowEmptyCollection()][object[]] $ArtifactManifest = @(),
        [AllowEmptyCollection()][string[]] $CommandPlan = @()
    )

    $expectedReportPaths = @(
        "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json",
        "docs/agent-runs/live-product-infra-rpc/public-rpc-render-report-snapshot.json",
        "docs/agent-runs/live-product-infra-rpc/systemd-service-install-report.json",
        "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json",
        "docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json",
        "docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json",
        "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json",
        "docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json",
        "docs/agent-runs/live-product-infra-rpc/live-cutover-rehearsal-report.json",
        "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json",
        "docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json",
        "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
    )
    $systemdInstallCommand = "npm run flowchain:service:install:systemd -- -Action Install -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>"
    $systemdStatusCommand = "npm run flowchain:service:install:systemd -- -Action Status"
    $systemdRollbackCommand = "npm run flowchain:service:install:systemd -- -Action Uninstall"
    $nginxReloadCommand = "systemctl reload nginx"
    $ownerHostApplyScriptPlanCommand = "bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh plan"
    $ownerHostApplyScriptRollbackCommand = "bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh rollback"
    $ownerHostApplyPowerShellPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Plan"
    $ownerHostApplyPowerShellRollbackCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Rollback"
    $rollbackCommands = @(
        "npm run flowchain:ops:snapshot -- -AllowBlocked",
        "npm run flowchain:service:status",
        "systemctl stop flowchain-supervisor.service",
        "systemctl stop flowchain-live.service",
        $systemdRollbackCommand,
        "cp <PREVIOUS_FLOWCHAIN_RPC_NGINX_CONF> /etc/nginx/conf.d/flowchain-rpc.conf",
        "nginx -t",
        $nginxReloadCommand,
        "systemctl restart flowchain-live.service",
        "systemctl restart flowchain-supervisor.service",
        $ownerHostApplyScriptRollbackCommand,
        $ownerHostApplyPowerShellRollbackCommand,
        "npm run flowchain:emergency:stop-local"
    )

    return [ordered]@{
        schema = "flowchain.public_rpc_owner_host_apply_plan.v1"
        flowChainRpcIsRepoOwned = $true
        privateOrigin = "127.0.0.1:8787"
        ownerSuppliedInputs = @(
            "FLOWCHAIN_RPC_PUBLIC_URL",
            "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
            "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
            "FLOWCHAIN_RPC_TLS_TERMINATED",
            "FLOWCHAIN_RPC_STATE_BACKUP_PATH",
            "FLOWCHAIN_TESTER_WRITE_ENABLED",
            "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
            "FLOWCHAIN_TESTER_MAX_SEND_UNITS"
        )
        artifactManifest = @($ArtifactManifest)
        installPhases = @(
            [ordered]@{
                id = "render-owner-files"
                mutatesHost = $false
                commands = @($CommandPlan | Where-Object { $_ -match "deployment-automation.ps1 -Action Render" })
                expectedArtifacts = @($ArtifactManifest | ForEach-Object { $_.fileName })
            },
            [ordered]@{
                id = "preflight-rendered-artifacts"
                mutatesHost = $false
                commands = @(
                    "npm run flowchain:service:install:systemd:validate",
                    "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>",
                    "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -StartBridgeRelayerLoop",
                    "systemd-analyze verify <FLOWCHAIN_DEPLOY_RENDER_DIR>/flowchain-live.service",
                    "systemd-analyze verify <FLOWCHAIN_DEPLOY_RENDER_DIR>/flowchain-supervisor.service",
                    "nginx -t",
                    "bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.sh",
                    "powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.ps1",
                    $ownerHostApplyScriptPlanCommand,
                    $ownerHostApplyPowerShellPlanCommand
                )
                expectedReportPaths = @("docs/agent-runs/live-product-infra-rpc/systemd-service-install-validation-report.json")
            },
            [ordered]@{
                id = "install-systemd-services"
                mutatesHost = $true
                commands = @(
                    $systemdInstallCommand,
                    $systemdStatusCommand,
                    "npm run flowchain:service:status",
                    "npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30"
                )
                rollbackCommands = @(
                    "systemctl stop flowchain-supervisor.service",
                    "systemctl stop flowchain-live.service",
                    $systemdRollbackCommand
                )
                expectedReportPaths = @("docs/agent-runs/live-product-infra-rpc/systemd-service-install-report.json")
            },
            [ordered]@{
                id = "publish-nginx-edge"
                mutatesHost = $true
                commands = @(
                    "install -m 0644 <FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-flowchain-rpc.conf /etc/nginx/conf.d/flowchain-rpc.conf",
                    "nginx -t",
                    $nginxReloadCommand,
                    "bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.sh"
                )
                rollbackCommands = @(
                    "cp <PREVIOUS_FLOWCHAIN_RPC_NGINX_CONF> /etc/nginx/conf.d/flowchain-rpc.conf",
                    "nginx -t",
                    $nginxReloadCommand
                )
            },
            [ordered]@{
                id = "post-deploy-proof"
                mutatesHost = $false
                commands = @(
                    "npm run flowchain:public-rpc:validate",
                    "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked",
                    "npm run flowchain:public-rpc:abuse-test",
                    "npm run flowchain:tester:gateway:e2e",
                    "npm run flowchain:wallet:live-tester:e2e",
                    "npm run flowchain:public-deployment:contract -- -AllowBlocked",
                    "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked",
                    "npm run flowchain:truth-table -- -AllowBlocked",
                    "npm run flowchain:no-secret:scan"
                )
                expectedReportPaths = @($expectedReportPaths)
            },
            [ordered]@{
                id = "rollback-ready"
                mutatesHost = $false
                commands = @("npm run flowchain:ops:snapshot -- -AllowBlocked")
                rollbackCommands = @($rollbackCommands)
            }
        )
        expectedReportPaths = @($expectedReportPaths)
        rollbackCommands = @($rollbackCommands)
        valuesPrinted = $false
        envValuesPrinted = $false
        noSecrets = $true
        broadcasts = $false
    }
}

function Test-OwnerHostApplyPlan {
    param([AllowNull()][object] $Plan)

    if ($null -eq $Plan) {
        return [ordered]@{
            ownerHostApplyPlanPresent = $false
        }
    }

    $artifacts = @((Get-DeployProp -Object $Plan -Name "artifactManifest" -Default @()))
    $phases = @((Get-DeployProp -Object $Plan -Name "installPhases" -Default @()))
    $commands = @($phases | ForEach-Object { @((Get-DeployProp -Object $_ -Name "commands" -Default @())) } | ForEach-Object { "$_" })
    $rollbackCommands = @((Get-DeployProp -Object $Plan -Name "rollbackCommands" -Default @()) | ForEach-Object { "$_" })
    $systemdInstallCommand = "npm run flowchain:service:install:systemd -- -Action Install -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>"
    $systemdStatusCommand = "npm run flowchain:service:install:systemd -- -Action Status"
    $systemdRollbackCommand = "npm run flowchain:service:install:systemd -- -Action Uninstall"
    $nginxReloadCommand = "systemctl reload nginx"
    $ownerHostApplyScriptPlanCommand = "bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh plan"
    $ownerHostApplyScriptRollbackCommand = "bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh rollback"
    $ownerHostApplyPowerShellPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Plan"
    $ownerHostApplyPowerShellRollbackCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Rollback"
    $expectedReports = @((Get-DeployProp -Object $Plan -Name "expectedReportPaths" -Default @()) | ForEach-Object { "$_" })
    $artifactNames = @($artifacts | ForEach-Object { "$($_.fileName)" })
    $artifactHashes = @($artifacts | ForEach-Object { "$($_.sha256)" })
    $installRequiredArtifacts = @($artifacts | Where-Object { $_.installRequired -eq $true })
    $requiredArtifactNames = @(
        "nginx-flowchain-rpc.conf",
        "flowchain-live.service",
        "flowchain-supervisor.service",
        "nginx-preflight.sh",
        "nginx-preflight.ps1",
        "public-rpc-render-report.json",
        "owner-host-apply.sh",
        "owner-host-apply.ps1"
    )
    $requiredPhaseIds = @(
        "render-owner-files",
        "preflight-rendered-artifacts",
        "install-systemd-services",
        "publish-nginx-edge",
        "post-deploy-proof",
        "rollback-ready"
    )
    $requiredEvidence = @(
        "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json",
        "docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json",
        "docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json",
        "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json",
        "docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json",
        "docs/agent-runs/live-product-infra-rpc/live-cutover-rehearsal-report.json",
        "docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json",
        "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
    )
    $mutatingPhaseIds = @($phases | Where-Object { $_.mutatesHost -eq $true } | ForEach-Object { "$($_.id)" })
    $readOnlyProofPhase = @($phases | Where-Object { "$($_.id)" -eq "post-deploy-proof" -and $_.mutatesHost -eq $false }).Count -eq 1

    return [ordered]@{
        ownerHostApplyPlanPresent = $true
        ownerHostApplyPlanSchema = [string](Get-DeployProp -Object $Plan -Name "schema" -Default "") -eq "flowchain.public_rpc_owner_host_apply_plan.v1"
        ownerHostApplyPlanRepoOwned = (Get-DeployProp -Object $Plan -Name "flowChainRpcIsRepoOwned" -Default $false) -eq $true
        ownerHostApplyPlanPrivateOrigin = [string](Get-DeployProp -Object $Plan -Name "privateOrigin" -Default "") -eq "127.0.0.1:8787"
        ownerHostApplyPlanArtifactManifestCount = $artifacts.Count -eq 8
        ownerHostApplyPlanAllArtifactsListed = @($requiredArtifactNames | Where-Object { $_ -notin $artifactNames }).Count -eq 0
        ownerHostApplyPlanArtifactsExist = @($artifacts | Where-Object { $_.exists -ne $true }).Count -eq 0
        ownerHostApplyPlanArtifactsHaveSha256 = @($artifactHashes | Where-Object { $_ -notmatch '^[a-f0-9]{64}$' }).Count -eq 0
        ownerHostApplyPlanInstallTargetsMapped = @($installRequiredArtifacts | Where-Object { [string]::IsNullOrWhiteSpace("$($_.installTarget)") -or [string]::IsNullOrWhiteSpace("$($_.installCommand)") }).Count -eq 0
        ownerHostApplyPlanPhaseCount = $phases.Count -eq 6
        ownerHostApplyPlanAllPhasesPresent = @($requiredPhaseIds | Where-Object { $phaseId = $_; @($phases | Where-Object { "$($_.id)" -eq $phaseId }).Count -eq 0 }).Count -eq 0
        ownerHostApplyPlanHasMutatingInstallPhase = "install-systemd-services" -in $mutatingPhaseIds
        ownerHostApplyPlanHasMutatingEdgePhase = "publish-nginx-edge" -in $mutatingPhaseIds
        ownerHostApplyPlanHasReadOnlyProofPhase = $readOnlyProofPhase
        ownerHostApplyPlanIncludesSystemdInstallCommand = $systemdInstallCommand -in $commands
        ownerHostApplyPlanIncludesSystemdStatusCommand = $systemdStatusCommand -in $commands
        ownerHostApplyPlanIncludesSystemdUninstallRollback = $systemdRollbackCommand -in $rollbackCommands
        ownerHostApplyPlanIncludesNginxReload = $nginxReloadCommand -in $commands -and $nginxReloadCommand -in $rollbackCommands
        ownerHostApplyPlanIncludesOwnerApplyScript = "owner-host-apply.sh" -in $artifactNames -and $ownerHostApplyScriptPlanCommand -in $commands -and $ownerHostApplyScriptRollbackCommand -in $rollbackCommands
        ownerHostApplyPlanIncludesWindowsOwnerApplyScript = "owner-host-apply.ps1" -in $artifactNames -and $ownerHostApplyPowerShellPlanCommand -in $commands -and $ownerHostApplyPowerShellRollbackCommand -in $rollbackCommands
        ownerHostApplyPlanIncludesPostDeployEvidence = @($requiredEvidence | Where-Object { $_ -notin $expectedReports }).Count -eq 0
        ownerHostApplyPlanValuesPrintedFalse = (Get-DeployProp -Object $Plan -Name "valuesPrinted" -Default $true) -eq $false
        ownerHostApplyPlanEnvValuesPrintedFalse = (Get-DeployProp -Object $Plan -Name "envValuesPrinted" -Default $true) -eq $false
        ownerHostApplyPlanNoSecrets = (Get-DeployProp -Object $Plan -Name "noSecrets" -Default $false) -eq $true
        ownerHostApplyPlanBroadcastsFalse = (Get-DeployProp -Object $Plan -Name "broadcasts" -Default $true) -eq $false
    }
}

$publicRpcSecurityHeaderTokens = @(
    "server_tokens off;",
    'add_header Strict-Transport-Security "max-age=31536000" always;',
    'add_header X-Content-Type-Options "nosniff" always;',
    'add_header Cache-Control "no-store" always;',
    'add_header Referrer-Policy "no-referrer" always;',
    'add_header X-Frame-Options "DENY" always;',
    "add_header Content-Security-Policy `"default-src 'none'; frame-ancestors 'none'; base-uri 'none'`" always;"
)

function Test-DeploymentTextContainsAllTokens {
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

function Ensure-PublicRpcDeploymentBundle {
    $bundleReport = Read-FlowChainJsonIfExists -Path $bundleReportPath
    if ($null -eq $bundleReport -or [string](Get-DeployProp -Object $bundleReport -Name "status" -Default "missing") -ne "passed") {
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-public-rpc-deployment-bundle.ps1") | Out-Null
        $bundleReport = Read-FlowChainJsonIfExists -Path $bundleReportPath
    }
    return $bundleReport
}

function Invoke-OwnerRender {
    param(
        [Parameter(Mandatory = $true)][string] $TargetRenderDir,
        [Parameter(Mandatory = $true)][string] $TargetOwnerEnvFile,
        [Parameter(Mandatory = $true)][string] $TargetTlsCertificatePath,
        [Parameter(Mandatory = $true)][string] $TargetTlsCertificateKeyPath,
        [Parameter(Mandatory = $true)][string] $TargetNginxExe,
        [string] $TargetServiceUser = "flowchain",
        [string] $TargetServiceGroup = "flowchain",
        [string] $TargetCargoTargetDir = ""
    )

    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $renderScriptPath,
        "-BundleDir",
        $bundleFullDir,
        "-RenderDir",
        $TargetRenderDir,
        "-OwnerEnvFile",
        $TargetOwnerEnvFile,
        "-RepoRoot",
        $repoRoot,
        "-ServiceUser",
        $TargetServiceUser,
        "-ServiceGroup",
        $TargetServiceGroup,
        "-TlsCertificatePath",
        $TargetTlsCertificatePath,
        "-TlsCertificateKeyPath",
        $TargetTlsCertificateKeyPath,
        "-NginxExe",
        $TargetNginxExe
    )
    if (-not [string]::IsNullOrWhiteSpace($TargetCargoTargetDir)) {
        $arguments += @("-CargoTargetDir", $TargetCargoTargetDir)
    }

    $output = @(& powershell @arguments 2>&1 | ForEach-Object { ConvertTo-DeploymentSafeLine -Line $_ })
    return [ordered]@{
        exitCode = [int]$LASTEXITCODE
        outputRedacted = @($output)
        reportPath = Join-Path $TargetRenderDir "public-rpc-render-report.json"
    }
}

function Test-RenderedDeployment {
    param(
        [Parameter(Mandatory = $true)][string] $TargetRenderDir,
        [Parameter(Mandatory = $true)][string] $TargetOwnerEnvFile,
        [Parameter(Mandatory = $true)][string] $TokenHashSentinel
    )

    $renderedNginxPath = Join-Path $TargetRenderDir "nginx-flowchain-rpc.conf"
    $renderedLiveUnitPath = Join-Path $TargetRenderDir "flowchain-live.service"
    $renderedSupervisorUnitPath = Join-Path $TargetRenderDir "flowchain-supervisor.service"
    $renderedShellPreflightPath = Join-Path $TargetRenderDir "nginx-preflight.sh"
    $renderedWindowsPreflightPath = Join-Path $TargetRenderDir "nginx-preflight.ps1"
    $renderedReportPath = Join-Path $TargetRenderDir "public-rpc-render-report.json"
    $renderedOwnerHostApplyScriptPath = New-OwnerHostApplyScript -TargetRenderDir $TargetRenderDir
    $renderedOwnerHostApplyPowerShellPath = New-OwnerHostApplyPowerShellScript -TargetRenderDir $TargetRenderDir
    $renderedPaths = @(
        $renderedNginxPath,
        $renderedLiveUnitPath,
        $renderedSupervisorUnitPath,
        $renderedShellPreflightPath,
        $renderedWindowsPreflightPath,
        $renderedOwnerHostApplyScriptPath,
        $renderedOwnerHostApplyPowerShellPath
    )

    $renderedTexts = @()
    foreach ($path in $renderedPaths) {
        if (Test-Path -LiteralPath $path) {
            $renderedTexts += Get-Content -Raw -LiteralPath $path
        }
    }
    $renderedAllText = $renderedTexts -join "`n"
    $renderReport = Read-FlowChainJsonIfExists -Path $renderedReportPath
    $renderReportText = if ($null -ne $renderReport) { $renderReport | ConvertTo-Json -Depth 12 } else { "" }

    if (-not [string]::IsNullOrWhiteSpace($renderedAllText)) {
        Assert-FlowChainNoSecretText -Text $renderedAllText -Label "rendered public RPC deployment files"
    }
    if (-not [string]::IsNullOrWhiteSpace($renderReportText)) {
        Assert-FlowChainNoSecretText -Text $renderReportText -Label "rendered public RPC deployment report"
    }

    $ownerHostApplyPowerShellParseErrors = @()
    if (Test-Path -LiteralPath $renderedOwnerHostApplyPowerShellPath) {
        $ownerHostApplyPowerShellParseTokens = $null
        $rawOwnerHostApplyPowerShellParseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $renderedOwnerHostApplyPowerShellPath,
            [ref]$ownerHostApplyPowerShellParseTokens,
            [ref]$rawOwnerHostApplyPowerShellParseErrors
        )
        $ownerHostApplyPowerShellParseErrors = @($rawOwnerHostApplyPowerShellParseErrors)
    }

    $checks = [ordered]@{
        renderedNginxWritten = Test-Path -LiteralPath $renderedNginxPath
        renderedSystemdLiveWritten = Test-Path -LiteralPath $renderedLiveUnitPath
        renderedSystemdSupervisorWritten = Test-Path -LiteralPath $renderedSupervisorUnitPath
        renderedShellPreflightWritten = Test-Path -LiteralPath $renderedShellPreflightPath
        renderedWindowsPreflightWritten = Test-Path -LiteralPath $renderedWindowsPreflightPath
        renderedOwnerHostApplyScriptWritten = Test-Path -LiteralPath $renderedOwnerHostApplyScriptPath
        renderedOwnerHostApplyPowerShellWritten = Test-Path -LiteralPath $renderedOwnerHostApplyPowerShellPath
        renderedOwnerHostApplyScriptHasPlanApplyRollback = $renderedAllText.Contains('owner-host-apply.sh [plan|apply|rollback]') -and $renderedAllText.Contains('apply() {') -and $renderedAllText.Contains('rollback() {')
        renderedOwnerHostApplyPowerShellHasPlanApplyRollback = $renderedAllText.Contains('ValidateSet("Plan", "Apply", "Rollback")') -and $renderedAllText.Contains('function Apply {') -and $renderedAllText.Contains('function Rollback {')
        renderedOwnerHostApplyPowerShellParses = (Test-Path -LiteralPath $renderedOwnerHostApplyPowerShellPath) -and $ownerHostApplyPowerShellParseErrors.Count -eq 0
        renderedOwnerHostApplyScriptVerifiesHashes = $renderedAllText.Contains('sha256sum -c -') -and $renderedAllText.Contains("verify_file 'nginx-flowchain-rpc.conf'") -and $renderedAllText.Contains("verify_file 'flowchain-live.service'") -and $renderedAllText.Contains("verify_file 'public-rpc-render-report.json'")
        renderedOwnerHostApplyPowerShellVerifiesHashes = $renderedAllText.Contains('Get-FileHash -LiteralPath $path -Algorithm SHA256') -and $renderedAllText.Contains("Verify-File -Name 'nginx-flowchain-rpc.conf'") -and $renderedAllText.Contains("Verify-File -Name 'public-rpc-render-report.json'")
        renderedOwnerHostApplyScriptRunsPostDeployProof = $renderedAllText.Contains('flowchain:public-rpc:synthetic-canary') -and $renderedAllText.Contains('flowchain:live:cutover:rehearsal') -and $renderedAllText.Contains('flowchain:truth-table') -and $renderedAllText.Contains('flowchain:no-secret:scan')
        renderedOwnerHostApplyPowerShellRunsPostDeployProof = $renderedAllText.Contains('flowchain:public-rpc:synthetic-canary') -and $renderedAllText.Contains('flowchain:live:cutover:rehearsal') -and $renderedAllText.Contains('flowchain:truth-table') -and $renderedAllText.Contains('flowchain:no-secret:scan')
        renderedReportWritten = Test-Path -LiteralPath $renderedReportPath
        renderedReportPassed = $null -ne $renderReport -and [string](Get-DeployProp -Object $renderReport -Name "status" -Default "missing") -eq "passed"
        renderedReportAllowedOriginCountPresent = $null -ne $renderReport -and [int](Get-DeployProp -Object $renderReport -Name "allowedOriginCount" -Default 0) -ge 1
        renderedFilesHaveNoPlaceholders = $renderedAllText -notmatch "<FLOWCHAIN_|<PATH_TO_"
        renderedFilesKeepPrivateOrigin = $renderedAllText.Contains("127.0.0.1:8787")
        renderedNginxHasTls = $renderedAllText.Contains("ssl_certificate ") -and $renderedAllText.Contains("ssl_certificate_key ")
        renderedNginxHasCorsForwarding = $renderedAllText.Contains('proxy_set_header Origin $http_origin;')
        renderedNginxHasRateLimit = $renderedAllText.Contains("limit_req_zone") -and $renderedAllText.Contains("limit_req zone=flowchain_rpc_per_ip")
        renderedNginxHasSecurityHeaders = Test-DeploymentTextContainsAllTokens -Text $renderedAllText -Tokens $publicRpcSecurityHeaderTokens
        renderedNginxHasTimeoutGuardrails = Test-DeploymentTextContainsAllTokens -Text $renderedAllText -Tokens @("client_max_body_size 256k;", "client_body_timeout 10s;", "proxy_connect_timeout 5s;", "proxy_send_timeout 30s;", "proxy_read_timeout 60s;", "send_timeout 30s;")
        renderedNginxAuthorizationForwardingScoped = ([regex]::Matches($renderedAllText, 'proxy_set_header\s+Authorization\s+\$http_authorization;')).Count -eq 1
        renderedSystemdUsesOwnerEnv = $renderedAllText.Contains("EnvironmentFile=$TargetOwnerEnvFile") -and $renderedAllText.Contains("FLOWCHAIN_OWNER_ENV_FILE=$TargetOwnerEnvFile")
        renderedPreflightHasReadinessProbe = $renderedAllText.Contains("/rpc/readiness") -and $renderedAllText.Contains("rpc_readiness")
        renderedPreflightHasTesterUnauthProbe = $renderedAllText.Contains("/tester/status") -and $renderedAllText.Contains("/tester/wallets/create") -and $renderedAllText.Contains("flowmemory.control_plane.tester_write_auth_required.v0")
        renderedPreflightHasDisallowedOriginProbe = $renderedAllText.Contains("blocked-origin.flowchain.example") -and $renderedAllText.Contains("403")
        renderedPreflightChecksSecurityHeaders = $renderedAllText.Contains("add_header Strict-Transport-Security") -and $renderedAllText.Contains("add_header Content-Security-Policy")
        renderedPreflightChecksTimeoutGuardrails = $renderedAllText.Contains("client_body_timeout 10s") -and $renderedAllText.Contains("proxy_connect_timeout 5s")
        renderedPreflightHasMethodRejectionProbes = $renderedAllText.Contains('test "${rpc_get_status}" = "405"') -and $renderedAllText.Contains('test "${readonly_post_status}" = "405"') -and $renderedAllText.Contains("RPC endpoint GET preflight did not return HTTP 405.") -and $renderedAllText.Contains("Read-only RPC readiness POST preflight did not return HTTP 405.")
        renderedPreflightBlocksBroadStatePath = $renderedAllText.Contains("/devnet/local/state.json") -and $renderedAllText.Contains("404")
        renderedPreflightBlocksPrivateWalletCreate = $renderedAllText.Contains("/wallets/create") -and $renderedAllText.Contains("404")
        renderedFilesDoNotContainTokenHash = -not $renderedAllText.Contains($TokenHashSentinel)
        renderedReportDoesNotContainTokenHash = -not $renderReportText.Contains($TokenHashSentinel)
        renderedReportKeepsOwnerPathsOutsideRepo = $null -ne $renderReport -and $renderReport.renderDirInsideRepo -eq $false -and $renderReport.ownerEnvFileInsideRepo -eq $false
        renderedReportNoSecrets = $null -ne $renderReport -and $renderReport.noSecrets -eq $true
        renderedReportBroadcastsFalse = $null -ne $renderReport -and $renderReport.broadcasts -eq $false
    }

    return [ordered]@{
        checks = $checks
        renderedFileNames = @($renderedPaths | ForEach-Object { Split-Path -Leaf $_ })
        artifactManifest = @(New-RenderedArtifactManifest -TargetRenderDir $TargetRenderDir)
        renderedReportPath = $renderedReportPath
        renderedReport = $renderReport
        renderedReportSummary = New-DeploymentRenderReportSummary -Report $renderReport -RenderedFileNames @($renderedPaths | ForEach-Object { Split-Path -Leaf $_ })
    }
}

function Test-PublicRpcRollbackDrill {
    param([Parameter(Mandatory = $true)][string] $TargetRenderDir)

    $renderedNginxPath = Join-Path $TargetRenderDir "nginx-flowchain-rpc.conf"
    $previousNginxPath = Join-Path $TargetRenderDir "previous-nginx-flowchain-rpc.conf"
    $backupBeforeDrillPath = Join-Path $TargetRenderDir "rollback-drill-current-before.conf"
    $checks = [ordered]@{
        rollbackDrillPerformed = $false
        rollbackRenderedConfigExists = Test-Path -LiteralPath $renderedNginxPath
        rollbackPreviousConfigWritten = $false
        rollbackRenderedConfigRestoredFromPrevious = $false
        rollbackOriginalConfigRestoredAfterDrill = $false
        rollbackArtifactsStayedInsideRenderDir = $false
        rollbackDrillNoSecrets = $false
        rollbackDrillBroadcastsFalse = $true
    }

    if (-not $checks.rollbackRenderedConfigExists) {
        return [ordered]@{
            checks = $checks
            artifacts = @($previousNginxPath, $backupBeforeDrillPath)
        }
    }

    $originalText = Get-Content -Raw -LiteralPath $renderedNginxPath
    $previousText = "# FlowChain rollback drill previous config`n$originalText"
    Assert-FlowChainNoSecretText -Text $previousText -Label "public RPC rollback drill previous config"

    Set-Content -LiteralPath $previousNginxPath -Value $previousText -Encoding UTF8
    $actualPreviousText = Get-Content -Raw -LiteralPath $previousNginxPath
    Assert-FlowChainNoSecretText -Text $actualPreviousText -Label "public RPC rollback drill written previous config"
    Copy-Item -LiteralPath $renderedNginxPath -Destination $backupBeforeDrillPath -Force
    Copy-Item -LiteralPath $previousNginxPath -Destination $renderedNginxPath -Force
    $rolledBackText = Get-Content -Raw -LiteralPath $renderedNginxPath
    Copy-Item -LiteralPath $backupBeforeDrillPath -Destination $renderedNginxPath -Force
    $restoredOriginalText = Get-Content -Raw -LiteralPath $renderedNginxPath

    $checks.rollbackDrillPerformed = $true
    $checks.rollbackPreviousConfigWritten = Test-Path -LiteralPath $previousNginxPath
    $checks.rollbackRenderedConfigRestoredFromPrevious = $rolledBackText -eq $actualPreviousText
    $checks.rollbackOriginalConfigRestoredAfterDrill = $restoredOriginalText -eq $originalText
    $checks.rollbackArtifactsStayedInsideRenderDir = (Test-DeployPathInsideRoot -Path $previousNginxPath -Root $TargetRenderDir) -and (Test-DeployPathInsideRoot -Path $backupBeforeDrillPath -Root $TargetRenderDir)
    $checks.rollbackDrillNoSecrets = $true

    return [ordered]@{
        checks = $checks
        artifacts = @($previousNginxPath, $backupBeforeDrillPath)
    }
}

function New-ValidationOwnerInputs {
    param([Parameter(Mandatory = $true)][string] $TempRoot)

    $ownerEnvPath = Join-Path $TempRoot "owner-public-rpc.env"
    $backupDir = Join-Path $TempRoot "backup"
    $tlsCert = Join-Path $TempRoot "tls-cert.pem"
    $tlsKey = Join-Path $TempRoot "tls-key.pem"
    $nginxExe = Join-Path $TempRoot "nginx.exe"
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    Set-Content -LiteralPath $tlsCert -Value "dummy certificate validation sentinel" -Encoding UTF8
    Set-Content -LiteralPath $tlsKey -Value "dummy key validation sentinel" -Encoding UTF8
    Set-Content -LiteralPath $nginxExe -Value "dummy nginx validation sentinel" -Encoding UTF8
    $tokenHash = "0000000000000000000000000000000000000000000000000000000000000000"
    Set-Content -LiteralPath $ownerEnvPath -Value (@(
        "FLOWCHAIN_RPC_PUBLIC_URL=https://rpc.flowchain.example",
        "FLOWCHAIN_RPC_ALLOWED_ORIGINS=https://wallet.flowchain.example,https://dashboard.flowchain.example",
        "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE=60",
        "FLOWCHAIN_RPC_TLS_TERMINATED=true",
        "FLOWCHAIN_RPC_STATE_BACKUP_PATH=$backupDir",
        "FLOWCHAIN_TESTER_WRITE_ENABLED=true",
        "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256=$tokenHash",
        "FLOWCHAIN_TESTER_MAX_SEND_UNITS=10"
    ) -join "`r`n") -Encoding UTF8

    return [ordered]@{
        ownerEnvFile = $ownerEnvPath
        backupDir = $backupDir
        tlsCertificatePath = $tlsCert
        tlsCertificateKeyPath = $tlsKey
        nginxExe = $nginxExe
        tokenHash = $tokenHash
    }
}

function New-CommandPlan {
    return @(
        "npm run flowchain:public-rpc:deployment-bundle",
        "npm run flowchain:public-rpc:deployment:automation",
        "powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-public-rpc-deployment-automation.ps1 -Action Render -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -OwnerEnvFile <FLOWCHAIN_OWNER_ENV_FILE> -TlsCertificatePath <PATH_TO_TLS_CERTIFICATE> -TlsCertificateKeyPath <PATH_TO_TLS_CERTIFICATE_KEY> -NginxExe <FLOWCHAIN_NGINX_EXE>",
        "npm run flowchain:service:install:systemd:validate",
        "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>",
        "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -StartBridgeRelayerLoop",
        "systemd-analyze verify <FLOWCHAIN_SYSTEMD_RENDERED_UNIT>",
        "systemd-analyze verify <FLOWCHAIN_SUPERVISOR_SYSTEMD_RENDERED_UNIT>",
        "nginx -t",
        "bash <FLOWCHAIN_NGINX_PREFLIGHT_SCRIPT>",
        "powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_NGINX_WINDOWS_PREFLIGHT_SCRIPT>",
        "npm run flowchain:service:install:windows -- -Action Plan",
        "powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Plan",
        "npm run flowchain:public-rpc:validate",
        "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked",
        "npm run flowchain:public-rpc:abuse-test",
        "npm run flowchain:tester:gateway:e2e",
        "npm run flowchain:wallet:live-tester:e2e",
        "npm run flowchain:public-deployment:contract -- -AllowBlocked",
        "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked",
        "npm run flowchain:truth-table -- -AllowBlocked",
        "npm run flowchain:no-secret:scan"
    )
}

$bundleReport = Ensure-PublicRpcDeploymentBundle
$bundleStatus = [string](Get-DeployProp -Object $bundleReport -Name "status" -Default "missing")
$bundleChecks = Get-DeployProp -Object $bundleReport -Name "checks"
$commandPlan = New-CommandPlan
$packageJson = Get-Content -Raw -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "package.json") | ConvertFrom-Json
$hasPackageScript = $packageJson.PSObject.Properties.Name -contains "scripts" -and $packageJson.scripts.PSObject.Properties.Name -contains "flowchain:public-rpc:deployment:automation"
$baseChecks = [ordered]@{
    bundleReportPassed = $bundleStatus -eq "passed"
    renderScriptExists = Test-Path -LiteralPath $renderScriptPath
    packageScriptPresent = $hasPackageScript
    bundleHasOwnerRenderValidation = (Get-DeployProp -Object $bundleChecks -Name "ownerRenderValidationPassed" -Default $false) -eq $true
    bundleHasShellPreflight = (Get-DeployProp -Object $bundleChecks -Name "nginxPreflightScriptWritten" -Default $false) -eq $true
    bundleHasWindowsPreflight = (Get-DeployProp -Object $bundleChecks -Name "windowsNginxPreflightScriptWritten" -Default $false) -eq $true
    bundleHasRollbackRunbook = (Get-DeployProp -Object $bundleChecks -Name "rollbackRunbookWritten" -Default $false) -eq $true
    bundleHasSecurityHeaders = (Get-DeployProp -Object $bundleChecks -Name "includesSecurityHeaders" -Default $false) -eq $true
    bundlePreflightsCheckSecurityHeaders = (Get-DeployProp -Object $bundleChecks -Name "preflightsCheckSecurityHeaders" -Default $false) -eq $true
    bundlePreflightsCheckMethodRejection = (Get-DeployProp -Object $bundleChecks -Name "includesMethodRejectionPreflight" -Default $false) -eq $true
}

$scenario = [ordered]@{
    performed = $false
    exitCode = $null
    outputRedacted = @()
    failedChecks = @()
}
$rendered = [ordered]@{
    checks = [ordered]@{}
    renderedFileNames = @()
    artifactManifest = @()
    renderedReportPath = ""
    renderedReport = $null
    renderedReportSummary = $null
}
$rollbackDrill = [ordered]@{
    checks = [ordered]@{}
    artifacts = @()
}
$ownerHostApplyPlan = $null
$problem = ""
$cleanupAttempted = $false
$ownerPathsOutsideRepo = $true
$hostMutationPerformed = $false
$tokenHashSentinel = "0000000000000000000000000000000000000000000000000000000000000000"

try {
    if ($Action -eq "Validate") {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "flowchain-public-rpc-deployment-automation-$PID-$([Guid]::NewGuid().ToString("N"))"
        $renderDirForValidation = Join-Path $tempRoot "rendered"
        New-Item -ItemType Directory -Force -Path $renderDirForValidation | Out-Null
        $validationInputs = New-ValidationOwnerInputs -TempRoot $tempRoot
        $tokenHashSentinel = [string]$validationInputs.tokenHash
        $ownerPathsOutsideRepo = -not (Test-DeployPathInsideRoot -Path $validationInputs.ownerEnvFile -Root $repoRoot) -and -not (Test-DeployPathInsideRoot -Path $renderDirForValidation -Root $repoRoot)
        $scenario.performed = $true
        $renderResult = Invoke-OwnerRender `
            -TargetRenderDir $renderDirForValidation `
            -TargetOwnerEnvFile $validationInputs.ownerEnvFile `
            -TargetTlsCertificatePath $validationInputs.tlsCertificatePath `
            -TargetTlsCertificateKeyPath $validationInputs.tlsCertificateKeyPath `
            -TargetNginxExe $validationInputs.nginxExe `
            -TargetServiceUser $ServiceUser `
            -TargetServiceGroup $ServiceGroup
        $scenario.exitCode = [int]$renderResult.exitCode
        $scenario.outputRedacted = @($renderResult.outputRedacted)
        $rendered = Test-RenderedDeployment -TargetRenderDir $renderDirForValidation -TargetOwnerEnvFile $validationInputs.ownerEnvFile -TokenHashSentinel $tokenHashSentinel
        $rollbackDrill = Test-PublicRpcRollbackDrill -TargetRenderDir $renderDirForValidation
        $scenario.failedChecks = @($rendered.checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
    }
    elseif ($Action -eq "Render") {
        if ([string]::IsNullOrWhiteSpace($RenderDir) -or [string]::IsNullOrWhiteSpace($OwnerEnvFile) -or [string]::IsNullOrWhiteSpace($TlsCertificatePath) -or [string]::IsNullOrWhiteSpace($TlsCertificateKeyPath) -or [string]::IsNullOrWhiteSpace($NginxExe)) {
            throw "Render requires RenderDir, OwnerEnvFile, TlsCertificatePath, TlsCertificateKeyPath, and NginxExe."
        }
        $renderFullDir = [System.IO.Path]::GetFullPath($RenderDir)
        $ownerEnvFullPath = [System.IO.Path]::GetFullPath($OwnerEnvFile)
        $ownerPathsOutsideRepo = -not (Test-DeployPathInsideRoot -Path $renderFullDir -Root $repoRoot) -and -not (Test-DeployPathInsideRoot -Path $ownerEnvFullPath -Root $repoRoot)
        $scenario.performed = $true
        $renderResult = Invoke-OwnerRender `
            -TargetRenderDir $renderFullDir `
            -TargetOwnerEnvFile $ownerEnvFullPath `
            -TargetTlsCertificatePath ([System.IO.Path]::GetFullPath($TlsCertificatePath)) `
            -TargetTlsCertificateKeyPath ([System.IO.Path]::GetFullPath($TlsCertificateKeyPath)) `
            -TargetNginxExe ([System.IO.Path]::GetFullPath($NginxExe)) `
            -TargetServiceUser $ServiceUser `
            -TargetServiceGroup $ServiceGroup `
            -TargetCargoTargetDir $CargoTargetDir
        $scenario.exitCode = [int]$renderResult.exitCode
        $scenario.outputRedacted = @($renderResult.outputRedacted)
        $rendered = Test-RenderedDeployment -TargetRenderDir $renderFullDir -TargetOwnerEnvFile $ownerEnvFullPath -TokenHashSentinel $tokenHashSentinel
        $scenario.failedChecks = @($rendered.checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
    }
}
catch {
    $problem = $_.Exception.Message
}
finally {
    if ($Action -eq "Validate" -and $null -ne $tempRoot) {
        $tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
        $tempFull = [System.IO.Path]::GetFullPath($tempRoot)
        $tempLeaf = Split-Path -Leaf $tempFull
        if ($tempFull.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase) -and $tempLeaf.StartsWith("flowchain-public-rpc-deployment-automation-", [System.StringComparison]::Ordinal)) {
            $cleanupAttempted = $true
            Remove-Item -LiteralPath $tempFull -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

$checks = [ordered]@{}
foreach ($entry in $baseChecks.GetEnumerator()) {
    $checks[$entry.Key] = $entry.Value
}
$checks.commandPlanIncludesTesterGatewayE2e = @($commandPlan) -contains "npm run flowchain:tester:gateway:e2e"
$checks.commandPlanIncludesWalletTesterE2e = @($commandPlan) -contains "npm run flowchain:wallet:live-tester:e2e"
$checks.commandPlanIncludesSyntheticCanary = @($commandPlan) -contains "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked"
$checks.commandPlanIncludesCutoverRehearsal = @($commandPlan) -contains "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked"
$checks.commandPlanIncludesTruthTable = @($commandPlan) -contains "npm run flowchain:truth-table -- -AllowBlocked"
$checks.commandPlanIncludesNoSecretScan = @($commandPlan) -contains "npm run flowchain:no-secret:scan"
$checks.ownerPathsOutsideRepo = $ownerPathsOutsideRepo
$checks.hostMutationPerformedFalse = $hostMutationPerformed -eq $false
$checks.valuesPrintedFalse = $true
$checks.envValuesPrintedFalse = $true
$checks.noSecrets = $true
$checks.secretMarkerFindingsEmpty = $true
$checks.broadcastsFalse = $true
$checks.liveBroadcastsFalse = $true
if ($Action -eq "Validate" -or $Action -eq "Render") {
    $checks.renderCommandPassed = $scenario.performed -eq $true -and $scenario.exitCode -eq 0
    foreach ($entry in $rendered.checks.GetEnumerator()) {
        $checks[$entry.Key] = $entry.Value
    }
    $checks.renderedReportSummaryPresent = $null -ne $rendered.renderedReportSummary
    $checks.renderedReportSummaryPassed = $null -ne $rendered.renderedReportSummary -and $rendered.renderedReportSummary.status -eq "passed"
    $renderReportBackedFileCount = @($rendered.renderedFileNames | Where-Object { "$_" -notin @("owner-host-apply.sh", "owner-host-apply.ps1") }).Count
    $checks.renderedReportSummaryListsFiles = $null -ne $rendered.renderedReportSummary -and [int]$rendered.renderedReportSummary.renderedFileCount -eq $renderReportBackedFileCount
    $checks.renderedReportSummaryHasRequiredEnvNames = $null -ne $rendered.renderedReportSummary -and [int]$rendered.renderedReportSummary.requiredEnvNameCount -eq 8
    $checks.renderedReportSummaryNoSecrets = $null -ne $rendered.renderedReportSummary -and $rendered.renderedReportSummary.noSecrets -eq $true -and $rendered.renderedReportSummary.envValuesPrinted -eq $false
    $checks.renderedReportSummaryBroadcastsFalse = $null -ne $rendered.renderedReportSummary -and $rendered.renderedReportSummary.broadcasts -eq $false
    $checks.renderedReportSummaryOwnerPathsOutsideRepo = $null -ne $rendered.renderedReportSummary -and $rendered.renderedReportSummary.renderDirInsideRepo -eq $false -and $rendered.renderedReportSummary.ownerEnvFileInsideRepo -eq $false
    $ownerHostApplyPlan = New-OwnerHostApplyPlan -ArtifactManifest @($rendered.artifactManifest) -CommandPlan @($commandPlan)
    $ownerHostApplyPlanChecks = Test-OwnerHostApplyPlan -Plan $ownerHostApplyPlan
    foreach ($entry in $ownerHostApplyPlanChecks.GetEnumerator()) {
        $checks[$entry.Key] = $entry.Value
    }
    if ($Action -eq "Validate") {
        foreach ($entry in $rollbackDrill.checks.GetEnumerator()) {
            $checks[$entry.Key] = $entry.Value
        }
        if ($null -ne $rendered.renderedReportSummary) {
            $snapshot = [ordered]@{
                schema = "flowchain.public_rpc_render_report_snapshot.v1"
                generatedAt = (Get-Date).ToUniversalTime().ToString("o")
                source = "flowchain-public-rpc-deployment-automation Validate"
                renderReportSummary = $rendered.renderedReportSummary
                renderedFileNames = @($rendered.renderedFileNames)
                valuesPrinted = $false
                envValuesPrinted = $false
                noSecrets = $true
                broadcasts = $false
            }
            $snapshotText = $snapshot | ConvertTo-Json -Depth 12
            Assert-FlowChainNoSecretText -Text $snapshotText -Label "public RPC render report snapshot"
            Write-FlowChainJson -Path $renderReportSnapshotFullPath -Value $snapshot -Depth 12
        }
        $checks.renderedReportSnapshotWritten = Test-Path -LiteralPath $renderReportSnapshotFullPath
        $checks.renderedReportSnapshotNoSecrets = $checks.renderedReportSnapshotWritten -and (Read-FlowChainJsonIfExists -Path $renderReportSnapshotFullPath).noSecrets -eq $true
        $checks.cleanupAttempted = $cleanupAttempted
    }
}

$report = [ordered]@{
    schema = "flowchain.public_rpc_deployment_automation_report.v1"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    action = $Action
    flowChainRpcIsRepoOwned = $true
    thirdPartyFlowChainRpcProviderNeeded = $false
    bundleReportStatus = $bundleStatus
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    problem = $problem
    scenario = $scenario
    rollbackDrill = $rollbackDrill
    renderedFileNames = @($rendered.renderedFileNames)
    renderedArtifactManifest = @($rendered.artifactManifest)
    renderedReportPath = if ($Action -eq "Render") { $rendered.renderedReportPath } else { "" }
    renderedReportSnapshotPath = if ($Action -eq "Validate") { $renderReportSnapshotFullPath } else { "" }
    renderedReportSummary = $rendered.renderedReportSummary
    ownerHostApplyPlan = $ownerHostApplyPlan
    ownerInputsRequired = @(
        "FLOWCHAIN_RPC_PUBLIC_URL",
        "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
        "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
        "FLOWCHAIN_RPC_TLS_TERMINATED",
        "FLOWCHAIN_RPC_STATE_BACKUP_PATH",
        "FLOWCHAIN_TESTER_WRITE_ENABLED",
        "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
        "FLOWCHAIN_TESTER_MAX_SEND_UNITS"
    )
    deploymentPhases = @(
        "render-owner-files",
        "verify-systemd-units",
        "test-nginx-config",
        "run-public-rpc-preflight",
        "run-post-deploy-readiness-gates",
        "rollback-drill-no-host-mutation",
        "rollback-or-emergency-stop"
    )
    commands = @($commandPlan)
    valuesPrinted = $false
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
    liveBroadcasts = $false
    hostMutationPerformed = $hostMutationPerformed
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 18
$secretMarkerFindings = @(
    Get-DeploymentSecretMarkerFindings -Text $preliminaryReportText -Label "public RPC deployment automation report"
)
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $secretMarkerFindings.Count -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0 -and [string]::IsNullOrWhiteSpace($problem)) { "passed" } else { "failed" }
$report["status"] = $status
$report["checks"] = $checks
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "public RPC deployment automation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Public RPC Deployment Automation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Action: $Action")
$markdownLines.Add("")
$markdownLines.Add("This validator proves the owner-host public RPC deployment path can render concrete Nginx, systemd, shell preflight, Windows preflight, verification, and rollback artifacts without printing owner values or mutating the host.")
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): $($entry.Value)")
}
$markdownLines.Add("")
$markdownLines.Add("## Deployment Phases")
$markdownLines.Add("")
foreach ($phase in @($report.deploymentPhases)) {
    $markdownLines.Add("- $phase")
}
$markdownLines.Add("")
$markdownLines.Add("## Commands")
$markdownLines.Add("")
foreach ($command in @($report.commands)) {
    $markdownLines.Add("- $command")
}
if ($null -ne $ownerHostApplyPlan) {
    $markdownLines.Add("")
    $markdownLines.Add("## Rendered Artifact Manifest")
    $markdownLines.Add("")
    foreach ($artifact in @($ownerHostApplyPlan.artifactManifest)) {
        $markdownLines.Add("- $($artifact.fileName): role=$($artifact.role), target=$($artifact.installTarget), sha256=$($artifact.sha256)")
    }
    $markdownLines.Add("")
    $markdownLines.Add("## Owner Host Apply Phases")
    $markdownLines.Add("")
    foreach ($phase in @($ownerHostApplyPlan.installPhases)) {
        $markdownLines.Add("- $($phase.id): mutatesHost=$($phase.mutatesHost)")
    }
}
if (-not [string]::IsNullOrWhiteSpace($problem)) {
    $markdownLines.Add("")
    $markdownLines.Add("Problem: $problem")
}
$markdownText = $markdownLines -join "`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "public RPC deployment automation markdown"
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain public RPC deployment automation status: $status"
Write-Host "Action: $Action"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"

if ($status -ne "passed") {
    exit 1
}
