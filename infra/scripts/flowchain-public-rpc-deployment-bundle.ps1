param(
    [string] $BundleDir = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_DEPLOYMENT_BUNDLE.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

function Join-BundleLines {
    param([AllowEmptyCollection()][AllowEmptyString()][string[]] $Lines)
    return ($Lines -join "`n")
}

function Get-MissingTextTokens {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string[]] $Tokens
    )

    $missing = New-Object System.Collections.ArrayList
    foreach ($token in $Tokens) {
        if ($Text.IndexOf($token, [System.StringComparison]::Ordinal) -lt 0) {
            [void] $missing.Add($token)
        }
    }
    return @($missing)
}

function Test-TextContainsAllTokens {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string[]] $Tokens
    )

    return (@(Get-MissingTextTokens -Text $Text -Tokens $Tokens).Count -eq 0)
}

function Test-TextContainsNoTokens {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string[]] $Tokens
    )

    foreach ($token in $Tokens) {
        if ($Text.IndexOf($token, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $false
        }
    }
    return $true
}

function Get-FlowChainSecretMarkerFindings {
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

function Test-CheckMapPassed {
    param([Parameter(Mandatory = $true)][System.Collections.Specialized.OrderedDictionary] $Checks)

    foreach ($value in $Checks.Values) {
        if ($value -ne $true) {
            return $false
        }
    }
    return $true
}

function Test-BundlePathInsideRoot {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $Root
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    return $fullPath.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $fullPath.StartsWith("$fullRoot$([System.IO.Path]::DirectorySeparatorChar)", [System.StringComparison]::OrdinalIgnoreCase)
}

function Invoke-PublicRpcBundleRenderValidation {
    param(
        [Parameter(Mandatory = $true)][string] $RepoRoot,
        [Parameter(Mandatory = $true)][string] $BundleDir
    )

    $safeTokenHash = "0000000000000000000000000000000000000000000000000000000000000000"
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "flowchain-public-rpc-render-validation-$PID-$([Guid]::NewGuid().ToString("N"))"
    $ownerEnvFile = Join-Path $tempRoot "owner-public-rpc.env"
    $renderDir = Join-Path $tempRoot "rendered"
    $backupDir = Join-Path $tempRoot "backups"
    $tlsCertPath = Join-Path $tempRoot "tls-cert.pem"
    $tlsKeyPath = Join-Path $tempRoot "tls-key.pem"
    $nginxExe = Join-Path $tempRoot "nginx.exe"
    $renderScriptPath = Join-Path $BundleDir "render-public-rpc-bundle.template.ps1"
    $renderedReportPath = Join-Path $renderDir "public-rpc-render-report.json"
    $renderOutput = @()
    $renderExitCode = 1
    $problem = ""

    $checks = [ordered]@{
        renderScriptExists = $false
        tempRootOutsideRepo = $false
        ownerEnvOutsideRepo = $false
        renderDirOutsideRepo = $false
        renderCommandPassed = $false
        renderedReportWritten = $false
        renderedNginxWritten = $false
        renderedSystemdServiceWritten = $false
        renderedSystemdSupervisorWritten = $false
        renderedShellPreflightWritten = $false
        renderedWindowsPreflightWritten = $false
        renderedFilesHaveNoPlaceholders = $false
        renderedNginxHasHttpsHost = $false
        renderedNginxHasRateLimit = $false
        renderedSystemdUsesOwnerEnv = $false
        renderedPreflightsUsePublicUrl = $false
        renderedReportPassed = $false
        renderedReportAllowedOriginCount = $false
        renderedReportKeepsOwnerPathsOutsideRepo = $false
        renderOutputDoesNotPrintTokenHash = $false
        renderedFilesDoNotContainTokenHash = $false
        renderedReportDoesNotContainTokenHash = $false
        renderedReportNoSecrets = $false
        wildcardOriginRenderRejected = $false
        wildcardOriginRenderOutputNoSecrets = $false
        cleanupAttempted = $false
        broadcastsFalse = $true
    }

    try {
        New-Item -ItemType Directory -Force -Path $tempRoot, $renderDir, $backupDir | Out-Null
        Set-Content -LiteralPath $tlsCertPath -Value "dummy certificate path sentinel" -Encoding UTF8
        Set-Content -LiteralPath $tlsKeyPath -Value "dummy key path sentinel" -Encoding UTF8
        Set-Content -LiteralPath $nginxExe -Value "dummy nginx path sentinel" -Encoding UTF8
        Set-Content -LiteralPath $ownerEnvFile -Value (@(
            "FLOWCHAIN_RPC_PUBLIC_URL=https://rpc.flowchain.example",
            "FLOWCHAIN_RPC_ALLOWED_ORIGINS=https://wallet.flowchain.example,https://dashboard.flowchain.example",
            "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE=60",
            "FLOWCHAIN_RPC_TLS_TERMINATED=true",
            "FLOWCHAIN_RPC_STATE_BACKUP_PATH=$backupDir",
            "FLOWCHAIN_TESTER_WRITE_ENABLED=true",
            "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256=$safeTokenHash",
            "FLOWCHAIN_TESTER_MAX_SEND_UNITS=10"
        ) -join "`r`n") -Encoding UTF8

        $checks.renderScriptExists = Test-Path -LiteralPath $renderScriptPath
        $checks.tempRootOutsideRepo = -not (Test-BundlePathInsideRoot -Path $tempRoot -Root $RepoRoot)
        $checks.ownerEnvOutsideRepo = -not (Test-BundlePathInsideRoot -Path $ownerEnvFile -Root $RepoRoot)
        $checks.renderDirOutsideRepo = -not (Test-BundlePathInsideRoot -Path $renderDir -Root $RepoRoot)

        if (-not $checks.renderScriptExists) {
            throw "Owner render script was not generated."
        }

        $renderOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $renderScriptPath `
            -BundleDir $BundleDir `
            -RenderDir $renderDir `
            -OwnerEnvFile $ownerEnvFile `
            -RepoRoot $RepoRoot `
            -ServiceUser "flowchain" `
            -ServiceGroup "flowchain" `
            -TlsCertificatePath $tlsCertPath `
            -TlsCertificateKeyPath $tlsKeyPath `
            -NginxExe $nginxExe 2>&1 | ForEach-Object { "$_" })
        $renderExitCode = $LASTEXITCODE
        $checks.renderCommandPassed = $renderExitCode -eq 0

        $renderedNginxPath = Join-Path $renderDir "nginx-flowchain-rpc.conf"
        $renderedSystemdPath = Join-Path $renderDir "flowchain-live.service"
        $renderedSupervisorPath = Join-Path $renderDir "flowchain-supervisor.service"
        $renderedShellPreflightPath = Join-Path $renderDir "nginx-preflight.sh"
        $renderedWindowsPreflightPath = Join-Path $renderDir "nginx-preflight.ps1"
        $renderedPaths = @(
            $renderedNginxPath,
            $renderedSystemdPath,
            $renderedSupervisorPath,
            $renderedShellPreflightPath,
            $renderedWindowsPreflightPath
        )

        $checks.renderedReportWritten = Test-Path -LiteralPath $renderedReportPath
        $checks.renderedNginxWritten = Test-Path -LiteralPath $renderedNginxPath
        $checks.renderedSystemdServiceWritten = Test-Path -LiteralPath $renderedSystemdPath
        $checks.renderedSystemdSupervisorWritten = Test-Path -LiteralPath $renderedSupervisorPath
        $checks.renderedShellPreflightWritten = Test-Path -LiteralPath $renderedShellPreflightPath
        $checks.renderedWindowsPreflightWritten = Test-Path -LiteralPath $renderedWindowsPreflightPath

        $renderedTexts = @()
        foreach ($path in $renderedPaths) {
            if (Test-Path -LiteralPath $path) {
                $renderedTexts += Get-Content -Raw -LiteralPath $path
            }
        }
        $renderedAllText = $renderedTexts -join "`n"
        $renderOutputText = @($renderOutput) -join "`n"
        $checks.renderedFilesHaveNoPlaceholders = $renderedAllText -notmatch "<FLOWCHAIN_|<PATH_TO_"
        $checks.renderedNginxHasHttpsHost = $renderedAllText.Contains("server_name rpc.flowchain.example;") -and $renderedAllText.Contains("https://rpc.flowchain.example")
        $checks.renderedNginxHasRateLimit = $renderedAllText.Contains("rate=60r/m") -and $renderedAllText.Contains("limit_req zone=flowchain_rpc_per_ip")
        $checks.renderedSystemdUsesOwnerEnv = $renderedAllText.Contains("EnvironmentFile=$ownerEnvFile") -and $renderedAllText.Contains("FLOWCHAIN_OWNER_ENV_FILE=$ownerEnvFile")
        $checks.renderedPreflightsUsePublicUrl = $renderedAllText.Contains("https://rpc.flowchain.example") -and $renderedAllText.Contains("https://wallet.flowchain.example")
        $checks.renderOutputDoesNotPrintTokenHash = -not $renderOutputText.Contains($safeTokenHash)
        $checks.renderedFilesDoNotContainTokenHash = -not $renderedAllText.Contains($safeTokenHash)

        $renderReport = Read-FlowChainJsonIfExists -Path $renderedReportPath
        if ($null -ne $renderReport) {
            $renderReportText = $renderReport | ConvertTo-Json -Depth 12
            $checks.renderedReportPassed = "$($renderReport.status)" -eq "passed"
            $checks.renderedReportAllowedOriginCount = [int]$renderReport.allowedOriginCount -eq 2
            $checks.renderedReportKeepsOwnerPathsOutsideRepo = $renderReport.renderDirInsideRepo -eq $false -and $renderReport.ownerEnvFileInsideRepo -eq $false
            $checks.renderedReportDoesNotContainTokenHash = -not $renderReportText.Contains($safeTokenHash)
            Assert-FlowChainNoSecretText -Text $renderReportText -Label "public RPC owner render validation report"
            $checks.renderedReportNoSecrets = $true
        }

        $wildcardOwnerEnvFile = Join-Path $tempRoot "owner-public-rpc-wildcard.env"
        $wildcardRenderDir = Join-Path $tempRoot "wildcard-rendered"
        New-Item -ItemType Directory -Force -Path $wildcardRenderDir | Out-Null
        Set-Content -LiteralPath $wildcardOwnerEnvFile -Value (@(
            "FLOWCHAIN_RPC_PUBLIC_URL=https://rpc.flowchain.example",
            "FLOWCHAIN_RPC_ALLOWED_ORIGINS=https://wallet.flowchain.example,*",
            "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE=60",
            "FLOWCHAIN_RPC_TLS_TERMINATED=true",
            "FLOWCHAIN_RPC_STATE_BACKUP_PATH=$backupDir",
            "FLOWCHAIN_TESTER_WRITE_ENABLED=true",
            "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256=$safeTokenHash",
            "FLOWCHAIN_TESTER_MAX_SEND_UNITS=10"
        ) -join "`r`n") -Encoding UTF8
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $wildcardRenderOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $renderScriptPath `
                -BundleDir $BundleDir `
                -RenderDir $wildcardRenderDir `
                -OwnerEnvFile $wildcardOwnerEnvFile `
                -RepoRoot $RepoRoot `
                -ServiceUser "flowchain" `
                -ServiceGroup "flowchain" `
                -TlsCertificatePath $tlsCertPath `
                -TlsCertificateKeyPath $tlsKeyPath `
                -NginxExe $nginxExe 2>&1 | ForEach-Object { "$_" })
            $wildcardRenderExitCode = $LASTEXITCODE
            if ($null -eq $wildcardRenderExitCode) {
                $wildcardRenderExitCode = 0
            }
        }
        catch {
            $wildcardRenderOutput = @($_.Exception.Message)
            $wildcardRenderExitCode = 1
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        $wildcardRenderOutputText = @($wildcardRenderOutput) -join "`n"
        Assert-FlowChainNoSecretText -Text $wildcardRenderOutputText -Label "public RPC wildcard origin render output"
        $checks.wildcardOriginRenderRejected = $wildcardRenderExitCode -ne 0
        $checks.wildcardOriginRenderOutputNoSecrets = -not $wildcardRenderOutputText.Contains($safeTokenHash)

        Assert-FlowChainNoSecretText -Text $renderOutputText -Label "public RPC owner render output"
        Assert-FlowChainNoSecretText -Text $renderedAllText -Label "public RPC rendered owner files"
    }
    catch {
        $problem = $_.Exception.Message
    }
    finally {
        $tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
        $tempFull = [System.IO.Path]::GetFullPath($tempRoot)
        $tempLeaf = Split-Path -Leaf $tempFull
        if ($tempFull.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase) -and $tempLeaf.StartsWith("flowchain-public-rpc-render-validation-", [System.StringComparison]::Ordinal)) {
            $checks.cleanupAttempted = $true
            Remove-Item -LiteralPath $tempFull -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
    return [ordered]@{
        schema = "flowchain.public_rpc_owner_render_validation.v0"
        status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
        checks = $checks
        failedChecks = @($failedChecks)
        renderExitCode = [int]$renderExitCode
        problem = $problem
        renderedFileNames = @(
            "nginx-flowchain-rpc.conf",
            "flowchain-live.service",
            "flowchain-supervisor.service",
            "nginx-preflight.sh",
            "nginx-preflight.ps1",
            "public-rpc-render-report.json"
        )
        envValuesPrinted = $false
        noSecrets = $failedChecks -notcontains "renderedReportNoSecrets"
        broadcasts = $false
    }
}

$repoRoot = Set-FlowChainRepoRoot
$bundleFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BundleDir)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

$edgeTemplateReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-edge-template-report.json"
$edgeTemplateReport = Read-FlowChainJsonIfExists -Path $edgeTemplateReportPath
if ($null -eq $edgeTemplateReport -or "$($edgeTemplateReport.status)" -ne "passed") {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-public-rpc-edge-template.ps1") | Out-Null
    $edgeTemplateReport = Read-FlowChainJsonIfExists -Path $edgeTemplateReportPath
}

if ($null -eq $edgeTemplateReport -or "$($edgeTemplateReport.status)" -ne "passed") {
    throw "Public RPC edge template report is not passed."
}

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

$requiredPlaceholders = @(
    "<FLOWCHAIN_RPC_PUBLIC_HOST>",
    "<FLOWCHAIN_RPC_PUBLIC_URL>",
    "<FLOWCHAIN_RPC_ALLOWED_ORIGIN>",
    "<FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>",
    "<PATH_TO_TLS_CERTIFICATE>",
    "<PATH_TO_TLS_CERTIFICATE_KEY>",
    "<FLOWCHAIN_REPO_ABSOLUTE_PATH>",
    "<FLOWCHAIN_SERVICE_USER>",
    "<FLOWCHAIN_SERVICE_GROUP>",
    "<FLOWCHAIN_OWNER_ENV_FILE>",
    "<FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR>",
    "<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>",
    "<FLOWCHAIN_NGINX_EXE>",
    "<FLOWCHAIN_NGINX_PREFLIGHT_SCRIPT>",
    "<FLOWCHAIN_NGINX_WINDOWS_PREFLIGHT_SCRIPT>",
    "<FLOWCHAIN_SYSTEMD_RENDERED_UNIT>",
    "<FLOWCHAIN_SUPERVISOR_SYSTEMD_RENDERED_UNIT>",
    "<PREVIOUS_FLOWCHAIN_RPC_NGINX_CONF>",
    "<FLOWCHAIN_DEPLOY_RENDER_DIR>"
)

$requiredCommands = @(
    "npm run flowchain:service:restart -- -LiveProfile",
    "npm run flowchain:service:supervisor -- -Once",
    "npm run flowchain:service:supervisor:validate",
    "npm run flowchain:service:install:systemd:validate",
    "npm run flowchain:service:status",
    "npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30",
    "npm run flowchain:ops:snapshot -- -AllowBlocked",
    "npm run flowchain:public-rpc:validate",
    "npm run flowchain:public-rpc:check",
    "npm run flowchain:backup:restore:validate",
    "npm run flowchain:backup:check",
    "npm run flowchain:public-deployment:contract -- -AllowBlocked",
    "npm run flowchain:external-tester:packet -- -AllowBlocked"
)

$ownerPreflightCommands = @(
    "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>",
    "systemd-analyze verify <FLOWCHAIN_SYSTEMD_RENDERED_UNIT>",
    "systemd-analyze verify <FLOWCHAIN_SUPERVISOR_SYSTEMD_RENDERED_UNIT>",
    "nginx -t",
    "bash <FLOWCHAIN_NGINX_PREFLIGHT_SCRIPT>",
    "powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_NGINX_WINDOWS_PREFLIGHT_SCRIPT>"
)

$ownerRenderCommands = @(
    "powershell -NoProfile -ExecutionPolicy Bypass -File render-public-rpc-bundle.template.ps1 -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -OwnerEnvFile <FLOWCHAIN_OWNER_ENV_FILE> -RepoRoot <FLOWCHAIN_REPO_ABSOLUTE_PATH> -ServiceUser <FLOWCHAIN_SERVICE_USER> -ServiceGroup <FLOWCHAIN_SERVICE_GROUP> -TlsCertificatePath <PATH_TO_TLS_CERTIFICATE> -TlsCertificateKeyPath <PATH_TO_TLS_CERTIFICATE_KEY> -NginxExe <FLOWCHAIN_NGINX_EXE>"
)

$localRollbackCommands = @(
    "npm run flowchain:ops:snapshot -- -AllowBlocked",
    "npm run flowchain:service:status",
    "npm run flowchain:service:restart -- -LiveProfile",
    "npm run flowchain:service:stop",
    "npm run flowchain:emergency:stop-local"
)

$ownerRollbackCommands = @(
    "systemctl stop flowchain-supervisor.service",
    "systemctl stop flowchain-live.service",
    "cp <PREVIOUS_FLOWCHAIN_RPC_NGINX_CONF> <FLOWCHAIN_RPC_NGINX_RENDERED_CONF>",
    "nginx -t",
    "systemctl reload nginx",
    "systemctl restart flowchain-live.service",
    "systemctl restart flowchain-supervisor.service"
)

$rollbackCommands = @($localRollbackCommands + $ownerRollbackCommands)

$nginxRequiredTokens = @(
    "server_name <FLOWCHAIN_RPC_PUBLIC_HOST>;",
    "ssl_certificate <PATH_TO_TLS_CERTIFICATE>;",
    "ssl_certificate_key <PATH_TO_TLS_CERTIFICATE_KEY>;",
    "limit_req_zone",
    "rate=<FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>r/m",
    "limit_req zone=flowchain_rpc_per_ip",
    "proxy_pass http://127.0.0.1:8787;",
    'proxy_set_header Origin $http_origin;',
    'proxy_set_header Authorization $http_authorization;',
    'proxy_set_header X-Forwarded-Proto https;',
    'proxy_set_header X-Forwarded-For $remote_addr;',
    '/tester/(faucet|wallets/(create|send))'
)

$systemdRequiredTokens = @(
    "[Unit]",
    "[Service]",
    "[Install]",
    "WorkingDirectory=<FLOWCHAIN_REPO_ABSOLUTE_PATH>",
    "User=<FLOWCHAIN_SERVICE_USER>",
    "Group=<FLOWCHAIN_SERVICE_GROUP>",
    "EnvironmentFile=<FLOWCHAIN_OWNER_ENV_FILE>",
    "Environment=FLOWCHAIN_OWNER_ENV_FILE=<FLOWCHAIN_OWNER_ENV_FILE>",
    "Environment=FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR=<FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR>",
    "ExecStart=/usr/bin/env npm run flowchain:service:start -- -LiveProfile",
    "ExecStartPost=/usr/bin/env npm run flowchain:service:status",
    "ExecReload=/usr/bin/env npm run flowchain:service:restart -- -LiveProfile",
    "ExecStop=/usr/bin/env npm run flowchain:service:stop",
    "NoNewPrivileges=true",
    "ReadWritePaths=<FLOWCHAIN_REPO_ABSOLUTE_PATH>/devnet"
)

$systemdSupervisorRequiredTokens = @(
    "[Unit]",
    "[Service]",
    "[Install]",
    "Description=FlowChain live service supervisor",
    "WorkingDirectory=<FLOWCHAIN_REPO_ABSOLUTE_PATH>",
    "User=<FLOWCHAIN_SERVICE_USER>",
    "Group=<FLOWCHAIN_SERVICE_GROUP>",
    "EnvironmentFile=<FLOWCHAIN_OWNER_ENV_FILE>",
    "Environment=FLOWCHAIN_OWNER_ENV_FILE=<FLOWCHAIN_OWNER_ENV_FILE>",
    "ExecStart=/usr/bin/env npm run flowchain:service:supervisor -- -IntervalSeconds 30 -MaxRestartAttempts 3",
    "Restart=always",
    "RestartSec=15",
    "NoNewPrivileges=true",
    "ReadWritePaths=<FLOWCHAIN_REPO_ABSOLUTE_PATH>/devnet"
)

$preflightRequiredTokens = @(
    'rendered_conf="<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>"',
    'public_host="<FLOWCHAIN_RPC_PUBLIC_HOST>"',
    'public_url="<FLOWCHAIN_RPC_PUBLIC_URL>"',
    'allowed_origin="<FLOWCHAIN_RPC_ALLOWED_ORIGIN>"',
    'grep -Fq "proxy_pass http://127.0.0.1:8787;" "${rendered_conf}"',
    "grep -Eq '<(FLOWCHAIN_|PATH_TO_TLS_)' `"`${rendered_conf}`"",
    "nginx -t",
    'curl -fsS --max-time 5 "http://127.0.0.1:8787/health" >/dev/null',
    'curl -fsS --max-time 10 -H "Origin: ${allowed_origin}" "${public_url%/}/rpc/readiness" >/dev/null',
    '${public_url%/}/tester/status',
    'tester_unauth_status=',
    '${public_url%/}/tester/wallets/create',
    'test "${tester_unauth_status}" = "401"',
    'flowmemory.control_plane.tester_write_auth_required.v0'
)

$windowsPreflightRequiredTokens = @(
    'param(',
    '[string] $RenderedConfig = "<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>"',
    '[string] $NginxExe = "<FLOWCHAIN_NGINX_EXE>"',
    '[string] $PublicUrl = "<FLOWCHAIN_RPC_PUBLIC_URL>"',
    '[string] $AllowedOrigin = "<FLOWCHAIN_RPC_ALLOWED_ORIGIN>"',
    'proxy_pass http://127.0.0.1:8787;',
    'proxy_set_header Origin $http_origin;',
    'proxy_set_header X-Forwarded-Proto https;',
    '& $NginxExe -t',
    'Invoke-RestMethod -Uri "http://127.0.0.1:8787/health"',
    '$publicBase = $PublicUrl.TrimEnd("/")',
    'Invoke-WebRequest -Uri "$publicBase/rpc/readiness"',
    '$testerStatus = Invoke-WebRequest -Uri "$publicBase/tester/status"',
    '$testerUnauthStatusCode -ne 401',
    'flowmemory.control_plane.tester_write_auth_required.v0',
    '$placeholderPattern = [regex]::Escape("<") + "(FLOWCHAIN_|PATH_TO_TLS_|FLOWCHAIN_NGINX_)"',
    '"method":"rpc_readiness"'
)

$renderScriptRequiredTokens = @(
    'param(',
    '[string] $RenderDir = "<FLOWCHAIN_DEPLOY_RENDER_DIR>"',
    '[string] $OwnerEnvFile = "<FLOWCHAIN_OWNER_ENV_FILE>"',
    '[string] $RepoRoot = "<FLOWCHAIN_REPO_ABSOLUTE_PATH>"',
    'function Assert-NotInsideRepo',
    'function Get-FlowChainEnvValue',
    'function Get-AllowedHttpsOrigins',
    'FLOWCHAIN_RPC_PUBLIC_URL',
    'FLOWCHAIN_RPC_ALLOWED_ORIGINS',
    'FLOWCHAIN_RPC_ALLOWED_ORIGINS must contain only exact https origins',
    'FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE',
    'FLOWCHAIN_RPC_TLS_TERMINATED',
    'FLOWCHAIN_TESTER_WRITE_ENABLED',
    'FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256',
    'FLOWCHAIN_TESTER_MAX_SEND_UNITS',
    'nginx-flowchain-rpc.template.conf',
    'flowchain-live.service.template',
    'flowchain-supervisor.service.template',
    'nginx-preflight.template.sh',
    'nginx-preflight.template.ps1',
    '<FLOWCHAIN_NGINX_WINDOWS_PREFLIGHT_SCRIPT>',
    'allowedOriginCount = $allowedOrigins.Count',
    'envValuesPrinted = $false',
    'noSecrets = $true'
)

$forbiddenLiveBroadcastCommandTokens = @(
    "transaction_submit",
    "bridge_observation_submit",
    "eth_sendRawTransaction",
    "sendRawTransaction",
    "cast send",
    "forge script --broadcast",
    "--broadcast",
    "out/broadcast"
)

Reset-FlowChainDirectory -Path $bundleFullDir | Out-Null

$nginxTemplateLines = @($edgeTemplateReport.nginxTemplate | ForEach-Object { "$_" })
if ($nginxTemplateLines.Count -eq 0) {
    throw "Public RPC edge template report did not include nginxTemplate lines."
}

$ownerEnvExampleLines = @(
    "# FlowChain owner public RPC env example.",
    "# Copy outside the repository and fill locally on the owner host only.",
    "# This committed example intentionally leaves every value blank.",
    "FLOWCHAIN_RPC_PUBLIC_URL=",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS=",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE=",
    "FLOWCHAIN_RPC_TLS_TERMINATED=",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH=",
    "FLOWCHAIN_TESTER_WRITE_ENABLED=",
    "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256=",
    "FLOWCHAIN_TESTER_MAX_SEND_UNITS="
)

$systemdServiceTemplateLines = @(
    "# FlowChain live service systemd template.",
    "# Render on the owner host only. Keep rendered unit files and env files out of the repository.",
    "[Unit]",
    "Description=FlowChain live service",
    "Wants=network-online.target",
    "After=network-online.target",
    "",
    "[Service]",
    "Type=oneshot",
    "WorkingDirectory=<FLOWCHAIN_REPO_ABSOLUTE_PATH>",
    "User=<FLOWCHAIN_SERVICE_USER>",
    "Group=<FLOWCHAIN_SERVICE_GROUP>",
    "EnvironmentFile=<FLOWCHAIN_OWNER_ENV_FILE>",
    "Environment=FLOWCHAIN_OWNER_ENV_FILE=<FLOWCHAIN_OWNER_ENV_FILE>",
    "Environment=FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR=<FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR>",
    "ExecStart=/usr/bin/env npm run flowchain:service:start -- -LiveProfile",
    "ExecStartPost=/usr/bin/env npm run flowchain:service:status",
    "ExecReload=/usr/bin/env npm run flowchain:service:restart -- -LiveProfile",
    "ExecStop=/usr/bin/env npm run flowchain:service:stop",
    "RemainAfterExit=yes",
    "TimeoutStartSec=900",
    "TimeoutStopSec=180",
    "KillMode=process",
    "Restart=on-failure",
    "RestartSec=30",
    "NoNewPrivileges=true",
    "PrivateTmp=true",
    "ProtectSystem=full",
    "ReadWritePaths=<FLOWCHAIN_REPO_ABSOLUTE_PATH>/devnet <FLOWCHAIN_REPO_ABSOLUTE_PATH>/docs/agent-runs <FLOWCHAIN_REPO_ABSOLUTE_PATH>/services/bridge-relayer/out",
    "",
    "[Install]",
    "WantedBy=multi-user.target"
)

$systemdSupervisorTemplateLines = @(
    "# FlowChain live service supervisor systemd template.",
    "# Render on the owner host only. Keep rendered unit files and env files out of the repository.",
    "[Unit]",
    "Description=FlowChain live service supervisor",
    "Wants=network-online.target",
    "After=network-online.target flowchain-live.service",
    "",
    "[Service]",
    "Type=simple",
    "WorkingDirectory=<FLOWCHAIN_REPO_ABSOLUTE_PATH>",
    "User=<FLOWCHAIN_SERVICE_USER>",
    "Group=<FLOWCHAIN_SERVICE_GROUP>",
    "EnvironmentFile=<FLOWCHAIN_OWNER_ENV_FILE>",
    "Environment=FLOWCHAIN_OWNER_ENV_FILE=<FLOWCHAIN_OWNER_ENV_FILE>",
    "Environment=FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR=<FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR>",
    "ExecStart=/usr/bin/env npm run flowchain:service:supervisor -- -IntervalSeconds 30 -MaxRestartAttempts 3",
    "Restart=always",
    "RestartSec=15",
    "TimeoutStartSec=120",
    "TimeoutStopSec=60",
    "KillMode=process",
    "NoNewPrivileges=true",
    "PrivateTmp=true",
    "ProtectSystem=full",
    "ReadWritePaths=<FLOWCHAIN_REPO_ABSOLUTE_PATH>/devnet <FLOWCHAIN_REPO_ABSOLUTE_PATH>/docs/agent-runs <FLOWCHAIN_REPO_ABSOLUTE_PATH>/services/bridge-relayer/out",
    "",
    "[Install]",
    "WantedBy=multi-user.target"
)

$nginxPreflightScriptLines = @(
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    "",
    'rendered_conf="<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>"',
    'public_host="<FLOWCHAIN_RPC_PUBLIC_HOST>"',
    'public_url="<FLOWCHAIN_RPC_PUBLIC_URL>"',
    'allowed_origin="<FLOWCHAIN_RPC_ALLOWED_ORIGIN>"',
    "",
    'test -n "${rendered_conf}"',
    'test -n "${public_host}"',
    'test -n "${public_url}"',
    'test -n "${allowed_origin}"',
    'test -f "${rendered_conf}"',
    "",
    'case "${public_url}" in',
    '  https://*) ;;',
    '  *) echo "FLOWCHAIN_RPC_PUBLIC_URL must be https"; exit 1 ;;',
    'esac',
    "",
    'if grep -Eq ''<(FLOWCHAIN_|PATH_TO_TLS_)'' "${rendered_conf}"; then',
    '  echo "Rendered Nginx config still contains placeholders."',
    '  exit 1',
    'fi',
    "",
    'grep -Fq "server_name ${public_host};" "${rendered_conf}"',
    'grep -Fq "proxy_pass http://127.0.0.1:8787;" "${rendered_conf}"',
    'grep -Fq "limit_req_zone" "${rendered_conf}"',
    'grep -Fq "limit_req zone=flowchain_rpc_per_ip" "${rendered_conf}"',
    'grep -Fq "ssl_certificate " "${rendered_conf}"',
    'grep -Fq "ssl_certificate_key " "${rendered_conf}"',
    'grep -Fq ''proxy_set_header Origin $http_origin;'' "${rendered_conf}"',
    'grep -Fq ''proxy_set_header X-Forwarded-Proto https;'' "${rendered_conf}"',
    'grep -Fq ''proxy_set_header X-Forwarded-For $remote_addr;'' "${rendered_conf}"',
    "",
    "nginx -t",
    'curl -fsS --max-time 5 "http://127.0.0.1:8787/health" >/dev/null',
    'curl -fsS --max-time 10 "${public_url%/}/health" >/dev/null',
    'curl -fsS --max-time 10 -H "Origin: ${allowed_origin}" "${public_url%/}/rpc/readiness" >/dev/null',
    'curl -fsS --max-time 10 -H "Origin: ${allowed_origin}" -H "Content-Type: application/json" --data ''{"jsonrpc":"2.0","id":1,"method":"rpc_readiness","params":{}}'' "${public_url%/}/rpc" >/dev/null',
    'tester_unauth_body="$(mktemp)"',
    'trap ''rm -f "${tester_unauth_body}"'' EXIT',
    'curl -fsS --max-time 10 -H "Origin: ${allowed_origin}" "${public_url%/}/tester/status" >/dev/null',
    'tester_unauth_status="$(curl -sS -o "${tester_unauth_body}" -w "%{http_code}" --max-time 10 -H "Origin: ${allowed_origin}" -H "Content-Type: application/json" --data ''{}'' "${public_url%/}/tester/wallets/create")"',
    'test "${tester_unauth_status}" = "401"',
    'grep -Fq "flowmemory.control_plane.tester_write_auth_required.v0" "${tester_unauth_body}"',
    "",
    'echo "FlowChain public RPC Nginx preflight passed."'
)

$nginxPreflightChecklistLines = @(
    "# Nginx Public RPC Preflight",
    "",
    'Run this on the owner host after rendering `nginx-flowchain-rpc.template.conf` outside the repository and before sharing the public URL.',
    "",
    "Checklist:",
    "",
    '- Render the Nginx template to `<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>`.',
    '- Replace `<FLOWCHAIN_RPC_PUBLIC_HOST>`, `<PATH_TO_TLS_CERTIFICATE>`, `<PATH_TO_TLS_CERTIFICATE_KEY>`, and `<FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>` only on the owner host.',
    '- Confirm the private origin remains `127.0.0.1:8787`.',
    "- Confirm TLS, rate limiting, Origin forwarding, and X-Forwarded headers are present.",
    '- Run `nginx -t` before every reload.',
    '- Run `bash <FLOWCHAIN_NGINX_PREFLIGHT_SCRIPT>` after installing the rendered config.',
    "",
    "The preflight script uses only local health and public read/readiness requests. It does not send live transactions."
)

$windowsNginxPreflightScriptLines = @(
    "param(",
    '    [string] $RenderedConfig = "<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>",',
    '    [string] $NginxExe = "<FLOWCHAIN_NGINX_EXE>",',
    '    [string] $PublicUrl = "<FLOWCHAIN_RPC_PUBLIC_URL>",',
    '    [string] $AllowedOrigin = "<FLOWCHAIN_RPC_ALLOWED_ORIGIN>"',
    ")",
    "",
    '$ErrorActionPreference = "Stop"',
    "Set-StrictMode -Version Latest",
    "",
    'if (-not (Test-Path -LiteralPath $RenderedConfig)) { throw "Rendered Nginx config was not found." }',
    'if (-not (Test-Path -LiteralPath $NginxExe)) { throw "nginx.exe was not found." }',
    'if (-not $PublicUrl.StartsWith("https://", [System.StringComparison]::OrdinalIgnoreCase)) { throw "FLOWCHAIN_RPC_PUBLIC_URL must be https." }',
    'if ([string]::IsNullOrWhiteSpace($AllowedOrigin) -or -not $AllowedOrigin.StartsWith("https://", [System.StringComparison]::OrdinalIgnoreCase)) { throw "FLOWCHAIN_RPC_ALLOWED_ORIGIN must be an exact https origin." }',
    "",
    '$rendered = Get-Content -Raw -LiteralPath $RenderedConfig',
    '$placeholderPattern = [regex]::Escape("<") + "(FLOWCHAIN_|PATH_TO_TLS_|FLOWCHAIN_NGINX_)"',
    'if ($rendered -match $placeholderPattern) { throw "Rendered Nginx config still contains placeholders." }',
    '@(',
    '    "proxy_pass http://127.0.0.1:8787;",',
    '    "limit_req_zone",',
    '    "limit_req zone=flowchain_rpc_per_ip",',
    '    "ssl_certificate ",',
    '    "ssl_certificate_key ",',
    '    ''proxy_set_header Origin $http_origin;'',',
    '    ''proxy_set_header X-Forwarded-Proto https;'',',
    '    ''proxy_set_header X-Forwarded-For $remote_addr;''',
    ') | ForEach-Object {',
    '    if ($rendered.IndexOf($_, [System.StringComparison]::Ordinal) -lt 0) {',
    '        throw "Rendered Nginx config missing required token: $_"',
    '    }',
    '}',
    "",
    '& $NginxExe -t',
    'Invoke-RestMethod -Uri "http://127.0.0.1:8787/health" -Method Get -TimeoutSec 5 | Out-Null',
    '$publicBase = $PublicUrl.TrimEnd("/")',
    '$headers = @{ Origin = $AllowedOrigin }',
    'Invoke-WebRequest -Uri "$publicBase/health" -Method Get -Headers $headers -TimeoutSec 10 | Out-Null',
    'Invoke-WebRequest -Uri "$publicBase/rpc/readiness" -Method Get -Headers $headers -TimeoutSec 10 | Out-Null',
    '$body = ''{"jsonrpc":"2.0","id":1,"method":"rpc_readiness","params":{}}''',
    'Invoke-WebRequest -Uri "$publicBase/rpc" -Method Post -ContentType "application/json" -Headers $headers -Body $body -TimeoutSec 10 | Out-Null',
    '$testerStatus = Invoke-WebRequest -Uri "$publicBase/tester/status" -Method Get -Headers $headers -TimeoutSec 10',
    'if ([int]$testerStatus.StatusCode -ne 200) { throw "Tester status preflight did not return HTTP 200." }',
    '$testerUnauthStatusCode = 0',
    '$testerUnauthBody = ""',
    'try {',
    '    Invoke-WebRequest -Uri "$publicBase/tester/wallets/create" -Method Post -ContentType "application/json" -Headers $headers -Body "{}" -TimeoutSec 10 | Out-Null',
    '    $testerUnauthStatusCode = 200',
    '}',
    'catch {',
    '    if ($_.Exception.PSObject.Properties.Name -contains "Response" -and $null -ne $_.Exception.Response) {',
    '        $testerUnauthStatusCode = [int]$_.Exception.Response.StatusCode',
    '        $stream = $_.Exception.Response.GetResponseStream()',
    '        if ($null -ne $stream) {',
    '            $reader = [System.IO.StreamReader]::new($stream)',
    '            try { $testerUnauthBody = $reader.ReadToEnd() } finally { $reader.Dispose() }',
    '        }',
    '    } else { throw }',
    '}',
    'if ($testerUnauthStatusCode -ne 401) { throw "Tester write unauthenticated preflight did not return HTTP 401." }',
    'if ($testerUnauthBody.IndexOf("flowmemory.control_plane.tester_write_auth_required.v0", [System.StringComparison]::Ordinal) -lt 0) { throw "Tester write unauthenticated preflight did not return auth-required schema." }',
    "",
    'Write-Host "FlowChain public RPC Windows Nginx preflight passed."'
)

$windowsNginxPreflightChecklistLines = @(
    "# Windows Nginx Public RPC Preflight",
    "",
    'Run this on the Windows owner host after rendering `nginx-flowchain-rpc.template.conf` outside the repository and before sharing the public URL.',
    "",
    "Checklist:",
    "",
    '- Render the Nginx template to `<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>`.',
    '- Replace `<FLOWCHAIN_RPC_PUBLIC_HOST>`, `<PATH_TO_TLS_CERTIFICATE>`, `<PATH_TO_TLS_CERTIFICATE_KEY>`, and `<FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>` only on the owner host.',
    '- Set `<FLOWCHAIN_NGINX_EXE>` to the local `nginx.exe` path.',
    '- Confirm the private origin remains `127.0.0.1:8787`.',
    '- Run `powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_NGINX_PREFLIGHT_SCRIPT>` after installing the rendered config.',
    "",
    "The PowerShell preflight uses local health and public read/readiness requests only. It does not send live transactions."
)

$renderScriptText = @'
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
if (-not $publicUrl.StartsWith("https://", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "FLOWCHAIN_RPC_PUBLIC_URL must be https before rendering public RPC files."
}
$publicUri = [System.Uri] $publicUrl
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
'@
$renderScriptLines = $renderScriptText -split "\r?\n"

$readmeLines = @(
    "# FlowChain Public RPC Deployment Bundle",
    "",
    "This bundle is placeholder-only. It is safe to commit because it contains env names, templates, and commands, not owner values.",
    "",
    "Files:",
    "",
    '- `nginx-flowchain-rpc.template.conf`: HTTPS reverse-proxy template for the private origin `127.0.0.1:8787`.',
    '- `flowchain-live.service.template`: systemd unit template for the owner-host live service.',
    '- `flowchain-supervisor.service.template`: systemd unit template for continuous service autorecovery.',
    '- `render-public-rpc-bundle.template.ps1`: owner-host renderer that writes concrete Nginx/systemd/preflight files outside the repository.',
    '- `nginx-preflight.template.sh`: Nginx config-test and public read preflight script template.',
    '- `NGINX_PREFLIGHT.md`: Nginx render, TLS, rate-limit, CORS, and reload checklist.',
    '- `nginx-preflight.template.ps1`: Windows Nginx config-test and public read preflight script template.',
    '- `WINDOWS_NGINX_PREFLIGHT.md`: Windows Nginx render, TLS, rate-limit, CORS, and reload checklist.',
    '- `owner-public-rpc.env.example`: local owner env-file shape with blank values.',
    '- `VERIFY.md`: pre-share verification commands.',
    '- `ROLLBACK.md`: rollback and emergency commands.',
    '- `bundle-checks.json`: machine-checkable proof that required placeholders and safety properties are present.'
)

$verifyLines = @(
    "# Verify Public RPC Before Sharing",
    "",
    "Run these on the owner host after DNS, TLS, allowed origins, rate limit, and backup path are configured locally.",
    "",
    "## Owner-Host Render Commands",
    ""
)
foreach ($command in $ownerRenderCommands) {
    $verifyLines += "- $command"
}
$verifyLines += @(
    "",
    "## Repository Checks",
    ""
)
foreach ($command in $requiredCommands) {
    $verifyLines += "- $command"
}
$verifyLines += @(
    "",
    "## Owner-Host Preflight Checks",
    ""
)
foreach ($command in $ownerPreflightCommands) {
    $verifyLines += "- $command"
}

$rollbackLines = @(
    "# Public RPC Rollback",
    "",
    "Use these commands if the public edge, RPC service, or tester sharing path behaves incorrectly.",
    "",
    "## Repository Rollback Commands",
    ""
)
foreach ($command in $localRollbackCommands) {
    $rollbackLines += "- $command"
}
$rollbackLines += @(
    "",
    "## Owner-Host Edge Rollback Commands",
    ""
)
foreach ($command in $ownerRollbackCommands) {
    $rollbackLines += "- $command"
}

$files = [ordered]@{
    readme = Join-Path $bundleFullDir "README.md"
    nginxTemplate = Join-Path $bundleFullDir "nginx-flowchain-rpc.template.conf"
    systemdServiceTemplate = Join-Path $bundleFullDir "flowchain-live.service.template"
    systemdSupervisorTemplate = Join-Path $bundleFullDir "flowchain-supervisor.service.template"
    renderScript = Join-Path $bundleFullDir "render-public-rpc-bundle.template.ps1"
    nginxPreflightScript = Join-Path $bundleFullDir "nginx-preflight.template.sh"
    nginxPreflightChecklist = Join-Path $bundleFullDir "NGINX_PREFLIGHT.md"
    windowsNginxPreflightScript = Join-Path $bundleFullDir "nginx-preflight.template.ps1"
    windowsNginxPreflightChecklist = Join-Path $bundleFullDir "WINDOWS_NGINX_PREFLIGHT.md"
    ownerEnvExample = Join-Path $bundleFullDir "owner-public-rpc.env.example"
    verify = Join-Path $bundleFullDir "VERIFY.md"
    rollback = Join-Path $bundleFullDir "ROLLBACK.md"
    bundleChecks = Join-Path $bundleFullDir "bundle-checks.json"
}

Set-Content -LiteralPath $files.readme -Value ($readmeLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.nginxTemplate -Value ($nginxTemplateLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.systemdServiceTemplate -Value ($systemdServiceTemplateLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.systemdSupervisorTemplate -Value ($systemdSupervisorTemplateLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.renderScript -Value ($renderScriptLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.nginxPreflightScript -Value ($nginxPreflightScriptLines -join "`n") -Encoding UTF8
Set-Content -LiteralPath $files.nginxPreflightChecklist -Value ($nginxPreflightChecklistLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.windowsNginxPreflightScript -Value ($windowsNginxPreflightScriptLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.windowsNginxPreflightChecklist -Value ($windowsNginxPreflightChecklistLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.ownerEnvExample -Value ($ownerEnvExampleLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.verify -Value ($verifyLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.rollback -Value ($rollbackLines -join "`r`n") -Encoding UTF8

$nginxText = Join-BundleLines -Lines $nginxTemplateLines
$ownerEnvText = Join-BundleLines -Lines $ownerEnvExampleLines
$systemdText = Join-BundleLines -Lines $systemdServiceTemplateLines
$systemdSupervisorText = Join-BundleLines -Lines $systemdSupervisorTemplateLines
$renderScriptText = Join-BundleLines -Lines $renderScriptLines
$nginxPreflightScriptText = Join-BundleLines -Lines $nginxPreflightScriptLines
$nginxPreflightChecklistText = Join-BundleLines -Lines $nginxPreflightChecklistLines
$windowsNginxPreflightScriptText = Join-BundleLines -Lines $windowsNginxPreflightScriptLines
$windowsNginxPreflightChecklistText = Join-BundleLines -Lines $windowsNginxPreflightChecklistLines
$verifyText = Join-BundleLines -Lines $verifyLines
$rollbackText = Join-BundleLines -Lines $rollbackLines
$readmeText = Join-BundleLines -Lines $readmeLines
$renderValidation = Invoke-PublicRpcBundleRenderValidation -RepoRoot $repoRoot -BundleDir $bundleFullDir
$allBundleText = @(
    $readmeText,
    $nginxText,
    $ownerEnvText,
    $systemdText,
    $systemdSupervisorText,
    $renderScriptText,
    $nginxPreflightScriptText,
    $nginxPreflightChecklistText,
    $windowsNginxPreflightScriptText,
    $windowsNginxPreflightChecklistText,
    $verifyText,
    $rollbackText
) -join "`n"
$allCommandsText = @($requiredCommands + $ownerRenderCommands + $ownerPreflightCommands + $rollbackCommands) -join "`n"
$missingRequiredPlaceholders = @(Get-MissingTextTokens -Text $allBundleText -Tokens $requiredPlaceholders)
$ownerEnvAssignmentsWithValues = @($ownerEnvExampleLines | Where-Object { $_ -match '^[A-Z][A-Z0-9_]*=.+$' })

$checks = [ordered]@{
    edgeTemplatePassed = "$($edgeTemplateReport.status)" -eq "passed"
    readmeWritten = Test-Path -LiteralPath $files.readme
    nginxTemplateWritten = Test-Path -LiteralPath $files.nginxTemplate
    systemdServiceTemplateWritten = Test-Path -LiteralPath $files.systemdServiceTemplate
    systemdSupervisorTemplateWritten = Test-Path -LiteralPath $files.systemdSupervisorTemplate
    renderScriptWritten = Test-Path -LiteralPath $files.renderScript
    nginxPreflightScriptWritten = Test-Path -LiteralPath $files.nginxPreflightScript
    nginxPreflightChecklistWritten = Test-Path -LiteralPath $files.nginxPreflightChecklist
    windowsNginxPreflightScriptWritten = Test-Path -LiteralPath $files.windowsNginxPreflightScript
    windowsNginxPreflightChecklistWritten = Test-Path -LiteralPath $files.windowsNginxPreflightChecklist
    ownerEnvExampleWritten = Test-Path -LiteralPath $files.ownerEnvExample
    verifyRunbookWritten = Test-Path -LiteralPath $files.verify
    rollbackRunbookWritten = Test-Path -LiteralPath $files.rollback
    bundleChecksJsonWritten = $false
    requiredPlaceholdersPresent = ($missingRequiredPlaceholders.Count -eq 0)
    nginxRequiredTokensPresent = Test-TextContainsAllTokens -Text $nginxText -Tokens $nginxRequiredTokens
    systemdLiveServiceTemplatePresent = Test-TextContainsAllTokens -Text $systemdText -Tokens $systemdRequiredTokens
    systemdSupervisorTemplatePresent = Test-TextContainsAllTokens -Text $systemdSupervisorText -Tokens $systemdSupervisorRequiredTokens
    renderScriptTokensPresent = Test-TextContainsAllTokens -Text $renderScriptText -Tokens $renderScriptRequiredTokens
    nginxPreflightTokensPresent = Test-TextContainsAllTokens -Text $nginxPreflightScriptText -Tokens $preflightRequiredTokens
    windowsNginxPreflightTokensPresent = Test-TextContainsAllTokens -Text $windowsNginxPreflightScriptText -Tokens $windowsPreflightRequiredTokens
    ownerRenderValidationPassed = "$($renderValidation.status)" -eq "passed"
    ownerRenderCommandPassed = ($renderValidation.checks.renderCommandPassed -eq $true)
    ownerRenderFilesHaveNoPlaceholders = ($renderValidation.checks.renderedFilesHaveNoPlaceholders -eq $true)
    ownerRenderWritesShellPreflight = ($renderValidation.checks.renderedShellPreflightWritten -eq $true)
    ownerRenderWritesWindowsPreflight = ($renderValidation.checks.renderedWindowsPreflightWritten -eq $true)
    ownerRenderDoesNotPrintTokenHash = ($renderValidation.checks.renderOutputDoesNotPrintTokenHash -eq $true)
    ownerRenderFilesDoNotContainTokenHash = ($renderValidation.checks.renderedFilesDoNotContainTokenHash -eq $true)
    includesPrivateOrigin = ($nginxText.Contains("127.0.0.1:8787") -and $nginxPreflightScriptText.Contains("127.0.0.1:8787") -and $windowsNginxPreflightScriptText.Contains("127.0.0.1:8787"))
    includesRateLimitPlaceholder = $nginxText.Contains("<FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>")
    includesTlsPlaceholders = ($nginxText.Contains("<PATH_TO_TLS_CERTIFICATE>") -and $nginxText.Contains("<PATH_TO_TLS_CERTIFICATE_KEY>"))
    includesCorsOriginForwarding = ($nginxText.Contains('proxy_set_header Origin $http_origin;') -and $nginxPreflightScriptText.Contains('Origin: ${allowed_origin}'))
    publicStateMirrorExcluded = (-not $nginxText.Contains("|state|")) -and (-not $nginxText.Contains("/state")) -and (-not @($edgeTemplateReport.publicReadMirrorPaths).Contains("/state"))
    devnetStatePublicRpcExcluded = (-not @($edgeTemplateReport.publicSafeJsonRpcMethods).Contains("devnet_state"))
    includesNginxConfigTest = ($nginxPreflightScriptText.Contains("nginx -t") -and $nginxPreflightChecklistText.Contains("nginx -t"))
    includesWindowsNginxConfigTest = ($windowsNginxPreflightScriptText.Contains('& $NginxExe -t') -and $windowsNginxPreflightChecklistText.Contains("<FLOWCHAIN_NGINX_EXE>"))
    includesTesterWritePreflight = ($nginxPreflightScriptText.Contains('/tester/status') -and $nginxPreflightScriptText.Contains('/tester/wallets/create') -and $nginxPreflightScriptText.Contains('flowmemory.control_plane.tester_write_auth_required.v0') -and $windowsNginxPreflightScriptText.Contains('/tester/status') -and $windowsNginxPreflightScriptText.Contains('/tester/wallets/create') -and $windowsNginxPreflightScriptText.Contains('flowmemory.control_plane.tester_write_auth_required.v0'))
    includesVerificationCommands = ((@(Get-MissingTextTokens -Text $verifyText -Tokens $requiredCommands).Count -eq 0) -and (@(Get-MissingTextTokens -Text $verifyText -Tokens $ownerRenderCommands).Count -eq 0) -and (@(Get-MissingTextTokens -Text $verifyText -Tokens $ownerPreflightCommands).Count -eq 0))
    includesRollbackCommands = (@(Get-MissingTextTokens -Text $rollbackText -Tokens $rollbackCommands).Count -eq 0)
    envExampleHasAllRequiredNames = (@(Get-MissingTextTokens -Text $ownerEnvText -Tokens $requiredEnvNames).Count -eq 0)
    ownerEnvExampleValuesBlank = ($ownerEnvAssignmentsWithValues.Count -eq 0)
    noLiveBroadcastCommands = (Test-TextContainsNoTokens -Text $allCommandsText -Tokens $forbiddenLiveBroadcastCommandTokens)
    noLiveBroadcastArtifacts = (Test-TextContainsNoTokens -Text $allBundleText -Tokens $forbiddenLiveBroadcastCommandTokens)
    valuesNotPrinted = $true
    envValuesNotPrinted = $true
    noSecrets = $true
    secretMarkerFindingsEmpty = $false
    liveBroadcastsDisabled = $true
}

$bundleChecksPayload = [ordered]@{
    schema = "flowchain.public_rpc_deployment_bundle_checks.v2"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    requiredPlaceholders = $requiredPlaceholders
    missingRequiredPlaceholders = $missingRequiredPlaceholders
    requiredEnvNames = $requiredEnvNames
    privateOrigin = "127.0.0.1:8787"
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    valuesPrinted = $false
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
    liveBroadcasts = $false
}

$checks["bundleChecksJsonWritten"] = $true
$preliminaryPassed = Test-CheckMapPassed -Checks $checks
$bundleChecksPayload["status"] = if ($preliminaryPassed) { "passed" } else { "failed" }
$bundleChecksPayload["checks"] = $checks
$bundleChecksText = $bundleChecksPayload | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $bundleChecksText -Label "public RPC deployment bundle checks"
Write-FlowChainJson -Path $files.bundleChecks -Value $bundleChecksPayload -Depth 16
$checks["bundleChecksJsonWritten"] = Test-Path -LiteralPath $files.bundleChecks

$secretMarkerFindings = @(
    Get-FlowChainSecretMarkerFindings -Text $allBundleText -Label "public RPC deployment bundle artifacts"
)
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $secretMarkerFindings.Count -eq 0
$passed = Test-CheckMapPassed -Checks $checks
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$bundleChecksPayload["status"] = if ($passed) { "passed" } else { "failed" }
$bundleChecksPayload["checks"] = $checks
$bundleChecksPayload["failedChecks"] = @($failedChecks)
$bundleChecksPayload["secretMarkerFindings"] = @($secretMarkerFindings)
$bundleChecksPayload["noSecrets"] = $secretMarkerFindings.Count -eq 0
$bundleChecksText = $bundleChecksPayload | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $bundleChecksText -Label "public RPC deployment bundle checks"
Write-FlowChainJson -Path $files.bundleChecks -Value $bundleChecksPayload -Depth 16

$report = [ordered]@{
    schema = "flowchain.public_rpc_deployment_bundle_report.v3"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = if ($passed) { "passed" } else { "failed" }
    bundleDir = $BundleDir
    flowChainRpcIsRepoOwned = $true
    thirdPartyFlowChainRpcProviderNeeded = $false
    privateOrigin = "127.0.0.1:8787"
    requiredEnvNames = $requiredEnvNames
    requiredPlaceholders = $requiredPlaceholders
    missingRequiredPlaceholders = $missingRequiredPlaceholders
    requiredCommands = $requiredCommands
    ownerRenderCommands = $ownerRenderCommands
    ownerPreflightCommands = $ownerPreflightCommands
    rollbackCommands = $rollbackCommands
    renderValidation = $renderValidation
    files = [ordered]@{
        readme = "README.md"
        nginxTemplate = "nginx-flowchain-rpc.template.conf"
        systemdServiceTemplate = "flowchain-live.service.template"
        systemdSupervisorTemplate = "flowchain-supervisor.service.template"
        renderScript = "render-public-rpc-bundle.template.ps1"
        nginxPreflightScript = "nginx-preflight.template.sh"
        nginxPreflightChecklist = "NGINX_PREFLIGHT.md"
        windowsNginxPreflightScript = "nginx-preflight.template.ps1"
        windowsNginxPreflightChecklist = "WINDOWS_NGINX_PREFLIGHT.md"
        ownerEnvExample = "owner-public-rpc.env.example"
        verify = "VERIFY.md"
        rollback = "ROLLBACK.md"
        bundleChecks = "bundle-checks.json"
    }
    checks = $checks
    failedChecks = @($failedChecks)
    secretMarkerFindings = @($secretMarkerFindings)
    valuesPrinted = $false
    envValuesPrinted = $false
    noSecrets = $secretMarkerFindings.Count -eq 0
    broadcasts = $false
    liveBroadcasts = $false
}

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Public RPC Deployment Bundle")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $($report.status)")
$markdownLines.Add("")
$markdownLines.Add('This bundle packages placeholder-only files for an owner-operated HTTPS edge in front of the repo-owned private RPC origin `127.0.0.1:8787`.')
$markdownLines.Add("")
$markdownLines.Add("## Files")
$markdownLines.Add("")
foreach ($entry in $report.files.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Value)")
}
$markdownLines.Add("")
$markdownLines.Add("## Required Placeholders")
$markdownLines.Add("")
foreach ($placeholder in $requiredPlaceholders) {
    $markdownLines.Add("- $placeholder")
}
$markdownLines.Add("")
$markdownLines.Add("## Required Env Names")
$markdownLines.Add("")
foreach ($name in $requiredEnvNames) {
    $markdownLines.Add("- $name")
}
$markdownLines.Add("")
$markdownLines.Add("## Verification Commands")
$markdownLines.Add("")
foreach ($command in $requiredCommands) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
$markdownLines.Add("## Owner-Host Render Commands")
$markdownLines.Add("")
foreach ($command in $ownerRenderCommands) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
$markdownLines.Add("## Owner-Host Preflight Commands")
$markdownLines.Add("")
foreach ($command in $ownerPreflightCommands) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
$markdownLines.Add("## Rollback Commands")
$markdownLines.Add("")
foreach ($command in $rollbackCommands) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
$markdownLines.Add("## Bundle Checks")
$markdownLines.Add("")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): $($entry.Value)")
}

$reportText = $report | ConvertTo-Json -Depth 16
$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $reportText -Label "public RPC deployment bundle report"
Assert-FlowChainNoSecretText -Text $markdownText -Label "public RPC deployment bundle markdown"
foreach ($artifactText in @($allBundleText, $bundleChecksText)) {
    Assert-FlowChainNoSecretText -Text $artifactText -Label "public RPC deployment bundle artifacts"
}
Assert-FlowChainNoSecretFiles -Path $bundleFullDir
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain public RPC deployment bundle status: $($report.status)"
Write-Host "Bundle: $bundleFullDir"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($report.status -ne "passed") {
    throw "FlowChain public RPC deployment bundle failed."
}
