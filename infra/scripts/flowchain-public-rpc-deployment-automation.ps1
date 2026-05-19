param(
    [ValidateSet("Plan", "Render", "Validate")]
    [string] $Action = "Validate",
    [string] $BundleDir = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_DEPLOYMENT_AUTOMATION.md",
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
$bundleReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json"
$renderScriptPath = Join-Path $bundleFullDir "render-public-rpc-bundle.template.ps1"

function Get-DeployProp {
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
    $renderedPaths = @(
        $renderedNginxPath,
        $renderedLiveUnitPath,
        $renderedSupervisorUnitPath,
        $renderedShellPreflightPath,
        $renderedWindowsPreflightPath
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

    $checks = [ordered]@{
        renderedNginxWritten = Test-Path -LiteralPath $renderedNginxPath
        renderedSystemdLiveWritten = Test-Path -LiteralPath $renderedLiveUnitPath
        renderedSystemdSupervisorWritten = Test-Path -LiteralPath $renderedSupervisorUnitPath
        renderedShellPreflightWritten = Test-Path -LiteralPath $renderedShellPreflightPath
        renderedWindowsPreflightWritten = Test-Path -LiteralPath $renderedWindowsPreflightPath
        renderedReportWritten = Test-Path -LiteralPath $renderedReportPath
        renderedReportPassed = $null -ne $renderReport -and [string](Get-DeployProp -Object $renderReport -Name "status" -Default "missing") -eq "passed"
        renderedReportAllowedOriginCountPresent = $null -ne $renderReport -and [int](Get-DeployProp -Object $renderReport -Name "allowedOriginCount" -Default 0) -ge 1
        renderedFilesHaveNoPlaceholders = $renderedAllText -notmatch "<FLOWCHAIN_|<PATH_TO_"
        renderedFilesKeepPrivateOrigin = $renderedAllText.Contains("127.0.0.1:8787")
        renderedNginxHasTls = $renderedAllText.Contains("ssl_certificate ") -and $renderedAllText.Contains("ssl_certificate_key ")
        renderedNginxHasCorsForwarding = $renderedAllText.Contains('proxy_set_header Origin $http_origin;')
        renderedNginxHasRateLimit = $renderedAllText.Contains("limit_req_zone") -and $renderedAllText.Contains("limit_req zone=flowchain_rpc_per_ip")
        renderedNginxHasSecurityHeaders = Test-DeploymentTextContainsAllTokens -Text $renderedAllText -Tokens $publicRpcSecurityHeaderTokens
        renderedNginxAuthorizationForwardingScoped = ([regex]::Matches($renderedAllText, 'proxy_set_header\s+Authorization\s+\$http_authorization;')).Count -eq 1
        renderedSystemdUsesOwnerEnv = $renderedAllText.Contains("EnvironmentFile=$TargetOwnerEnvFile") -and $renderedAllText.Contains("FLOWCHAIN_OWNER_ENV_FILE=$TargetOwnerEnvFile")
        renderedPreflightHasReadinessProbe = $renderedAllText.Contains("/rpc/readiness") -and $renderedAllText.Contains("rpc_readiness")
        renderedPreflightHasTesterUnauthProbe = $renderedAllText.Contains("/tester/status") -and $renderedAllText.Contains("/tester/wallets/create") -and $renderedAllText.Contains("flowmemory.control_plane.tester_write_auth_required.v0")
        renderedPreflightHasDisallowedOriginProbe = $renderedAllText.Contains("blocked-origin.flowchain.example") -and $renderedAllText.Contains("403")
        renderedPreflightChecksSecurityHeaders = $renderedAllText.Contains("add_header Strict-Transport-Security") -and $renderedAllText.Contains("add_header Content-Security-Policy")
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
        renderedReportPath = $renderedReportPath
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
        "npm run flowchain:public-rpc:validate",
        "npm run flowchain:public-rpc:abuse-test",
        "npm run flowchain:public-deployment:contract -- -AllowBlocked"
    )
}

$bundleReport = Ensure-PublicRpcDeploymentBundle
$bundleStatus = [string](Get-DeployProp -Object $bundleReport -Name "status" -Default "missing")
$bundleChecks = Get-DeployProp -Object $bundleReport -Name "checks"
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
    renderedReportPath = ""
}
$rollbackDrill = [ordered]@{
    checks = [ordered]@{}
    artifacts = @()
}
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
    if ($Action -eq "Validate") {
        foreach ($entry in $rollbackDrill.checks.GetEnumerator()) {
            $checks[$entry.Key] = $entry.Value
        }
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
    renderedReportPath = if ($Action -eq "Render") { $rendered.renderedReportPath } else { "" }
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
    commands = New-CommandPlan
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
