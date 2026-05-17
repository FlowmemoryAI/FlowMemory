param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_ABUSE_TEST.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$runDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test")
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

$envNames = @(
    "FLOWCHAIN_OWNER_ENV_FILE",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE"
)
$originalEnv = @{}
foreach ($name in $envNames) {
    $originalEnv[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

$cases = New-Object System.Collections.ArrayList
$responseSummaries = New-Object System.Collections.ArrayList
$fatalError = $null
$serverProcess = $null
$serverStarted = $false
$stdoutPath = Join-Path $runDir "control-plane.stdout.log"
$stderrPath = Join-Path $runDir "control-plane.stderr.log"
$allowedOrigin = "https://flowchain-public-rpc-abuse-allowed.example"
$blockedOrigin = "https://flowchain-public-rpc-abuse-blocked.invalid"
$script:clientSuffix = 20

function Get-FreeLocalPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse("127.0.0.1"), 0)
    $listener.Start()
    try {
        return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally {
        $listener.Stop()
    }
}

function Get-AbuseProp {
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

function ConvertTo-AbuseHeaderMap {
    param([AllowNull()][object] $Headers)

    $map = [ordered]@{}
    if ($null -eq $Headers) {
        return $map
    }

    if ($Headers -is [System.Net.WebHeaderCollection]) {
        foreach ($key in @($Headers.AllKeys)) {
            $map[$key] = "$($Headers[$key])"
        }
        return $map
    }

    if ($Headers -is [System.Collections.IDictionary]) {
        foreach ($key in @($Headers.Keys)) {
            $map["$key"] = "$($Headers[$key])"
        }
        return $map
    }

    foreach ($prop in @($Headers.PSObject.Properties)) {
        $map[$prop.Name] = "$($prop.Value)"
    }
    return $map
}

function Get-AbuseHeader {
    param(
        [AllowNull()][object] $Response,
        [Parameter(Mandatory = $true)][string] $Name
    )

    $headers = Get-AbuseProp -Object $Response -Name "headers" -Default ([ordered]@{})
    foreach ($entry in $headers.GetEnumerator()) {
        if ("$($entry.Key)" -ieq $Name) {
            return "$($entry.Value)"
        }
    }
    return ""
}

function ConvertFrom-AbuseJson {
    param([AllowNull()][string] $Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }
    try {
        return $Text | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Read-AbuseErrorBody {
    param([AllowNull()][object] $Response)

    if ($null -eq $Response) {
        return ""
    }
    try {
        $stream = $Response.GetResponseStream()
        if ($null -eq $stream) {
            return ""
        }
        $reader = [System.IO.StreamReader]::new($stream)
        try {
            return $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
    }
    catch {
        return ""
    }
}

function Invoke-AbuseHttpRequest {
    param(
        [Parameter(Mandatory = $true)][string] $Method,
        [Parameter(Mandatory = $true)][string] $Uri,
        [hashtable] $Headers = @{},
        [AllowNull()][object] $Body = $null,
        [AllowNull()][string] $ContentType = $null,
        [int] $TimeoutSec = 10
    )

    $parameters = @{
        Uri = $Uri
        Method = $Method
        Headers = $Headers
        TimeoutSec = $TimeoutSec
        UseBasicParsing = $true
    }
    if ($PSBoundParameters.ContainsKey("Body") -and $null -ne $Body) {
        $parameters.Body = "$Body"
    }
    if (-not [string]::IsNullOrWhiteSpace($ContentType)) {
        $parameters.ContentType = $ContentType
    }

    try {
        $response = Invoke-WebRequest @parameters
        $bodyText = "$($response.Content)"
        return [ordered]@{
            statusCode = [int] $response.StatusCode
            headers = ConvertTo-AbuseHeaderMap -Headers $response.Headers
            bodyText = $bodyText
            json = ConvertFrom-AbuseJson -Text $bodyText
            errorMessage = ""
        }
    }
    catch {
        $response = $null
        try {
            if ($_.Exception.PSObject.Properties.Name -contains "Response") {
                $response = $_.Exception.Response
            }
        }
        catch {
            $response = $null
        }
        $statusCode = 0
        $headers = [ordered]@{}
        if ($null -ne $response) {
            try {
                $statusCode = [int] $response.StatusCode
            }
            catch {
                $statusCode = 0
            }
            $headers = ConvertTo-AbuseHeaderMap -Headers $response.Headers
        }
        $bodyText = Read-AbuseErrorBody -Response $response
        return [ordered]@{
            statusCode = $statusCode
            headers = $headers
            bodyText = $bodyText
            json = ConvertFrom-AbuseJson -Text $bodyText
            errorMessage = $_.Exception.Message
        }
    }
}

function New-AbuseHeaders {
    param([string] $Origin = $allowedOrigin)

    $suffix = $script:clientSuffix
    $script:clientSuffix += 1
    return @{
        Origin = $Origin
        "X-Forwarded-For" = "203.0.113.$suffix, 198.51.100.$suffix"
    }
}

function Get-AbuseResponseData {
    param([AllowNull()][object] $Response)

    $json = Get-AbuseProp -Object $Response -Name "json"
    $error = Get-AbuseProp -Object $json -Name "error"
    return Get-AbuseProp -Object $error -Name "data"
}

function Get-AbuseResponseReasonCode {
    param([AllowNull()][object] $Response)

    $json = Get-AbuseProp -Object $Response -Name "json"
    $direct = Get-AbuseProp -Object $json -Name "reasonCode"
    if (-not [string]::IsNullOrWhiteSpace("$direct")) {
        return "$direct"
    }
    $data = Get-AbuseResponseData -Response $Response
    return "$(Get-AbuseProp -Object $data -Name 'reasonCode' -Default '')"
}

function Get-AbuseResponseSchema {
    param([AllowNull()][object] $Response)

    $json = Get-AbuseProp -Object $Response -Name "json"
    $direct = Get-AbuseProp -Object $json -Name "schema"
    if (-not [string]::IsNullOrWhiteSpace("$direct")) {
        return "$direct"
    }
    $data = Get-AbuseResponseData -Response $Response
    return "$(Get-AbuseProp -Object $data -Name 'schema' -Default '')"
}

function Get-AbuseResponseErrorCode {
    param([AllowNull()][object] $Response)

    $json = Get-AbuseProp -Object $Response -Name "json"
    $error = Get-AbuseProp -Object $json -Name "error"
    return Get-AbuseProp -Object $error -Name "code"
}

function Get-AbuseResponseNoSecretsFlag {
    param([AllowNull()][object] $Response)

    $json = Get-AbuseProp -Object $Response -Name "json"
    $direct = Get-AbuseProp -Object $json -Name "noSecrets"
    if ($null -ne $direct) {
        return $direct
    }
    $data = Get-AbuseResponseData -Response $Response
    return Get-AbuseProp -Object $data -Name "noSecrets"
}

function Add-AbuseCase {
    param(
        [Parameter(Mandatory = $true)][string] $Id,
        [Parameter(Mandatory = $true)][string] $Requirement,
        [Parameter(Mandatory = $true)][bool] $Passed,
        [AllowNull()][object] $Response = $null,
        [string] $Evidence = ""
    )

    $statusCode = Get-AbuseProp -Object $Response -Name "statusCode" -Default $null
    $summary = [ordered]@{
        id = $Id
        httpStatus = $statusCode
        schema = Get-AbuseResponseSchema -Response $Response
        reasonCode = Get-AbuseResponseReasonCode -Response $Response
        errorCode = Get-AbuseResponseErrorCode -Response $Response
        noSecretsFlag = Get-AbuseResponseNoSecretsFlag -Response $Response
        corsHeaderPresent = -not [string]::IsNullOrWhiteSpace((Get-AbuseHeader -Response $Response -Name "Access-Control-Allow-Origin"))
        retryAfterHeaderPresent = -not [string]::IsNullOrWhiteSpace((Get-AbuseHeader -Response $Response -Name "Retry-After"))
        errorCaptured = -not [string]::IsNullOrWhiteSpace("$(Get-AbuseProp -Object $Response -Name 'errorMessage' -Default '')")
        errorMessage = "$(Get-AbuseProp -Object $Response -Name 'errorMessage' -Default '')"
    }
    [void] $responseSummaries.Add($summary)
    [void] $cases.Add([ordered]@{
        id = $Id
        requirement = $Requirement
        status = if ($Passed) { "passed" } else { "failed" }
        evidence = $Evidence
        response = $summary
    })
}

function Wait-ControlPlaneHealth {
    param(
        [Parameter(Mandatory = $true)][string] $BaseUrl,
        [int] $TimeoutSeconds = 20
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastError = $null
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-RestMethod -Uri "$BaseUrl/health" -Method Get -TimeoutSec 5
            if ($null -ne $response -and $response.schema -eq "flowmemory.control_plane.health.v0") {
                return
            }
            $lastError = "unexpected health schema"
        }
        catch {
            $lastError = $_.Exception.Message
        }
        Start-Sleep -Milliseconds 500
    }
    throw "Temporary control-plane did not become healthy. Last status: $lastError"
}

try {
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", $null, "Process")
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_RPC_ALLOWED_ORIGINS", $allowedOrigin, "Process")
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "2", "Process")

    $port = Get-FreeLocalPort
    $baseUrl = "http://127.0.0.1:$port"
    $serverScript = Join-Path $repoRoot "services/control-plane/src/server.ts"
    $serverProcess = Start-Process -FilePath "node" `
        -ArgumentList @($serverScript, "--host", "127.0.0.1", "--port", "$port") `
        -WorkingDirectory $repoRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru
    Wait-ControlPlaneHealth -BaseUrl $baseUrl
    $serverStarted = $true

    $health = Invoke-AbuseHttpRequest -Method "GET" -Uri "$baseUrl/health" -Headers (New-AbuseHeaders)
    Add-AbuseCase -Id "allowed-origin-health" `
        -Requirement "Allowed browser origin can read health with a non-wildcard CORS echo." `
        -Passed (($health.statusCode -eq 200) -and ((Get-AbuseHeader -Response $health -Name "Access-Control-Allow-Origin") -eq $allowedOrigin)) `
        -Response $health `
        -Evidence "status=$($health.statusCode), corsEchoMatchesConfiguredOrigin=$((Get-AbuseHeader -Response $health -Name "Access-Control-Allow-Origin") -eq $allowedOrigin)"

    $disallowed = Invoke-AbuseHttpRequest -Method "GET" -Uri "$baseUrl/health" -Headers (New-AbuseHeaders -Origin $blockedOrigin)
    Add-AbuseCase -Id "disallowed-origin-rejected" `
        -Requirement "Disallowed browser origin is rejected before public RPC handling." `
        -Passed (($disallowed.statusCode -eq 403) -and ((Get-AbuseResponseSchema -Response $disallowed) -eq "flowmemory.control_plane.cors_rejected.v0") -and [string]::IsNullOrWhiteSpace((Get-AbuseHeader -Response $disallowed -Name "Access-Control-Allow-Origin"))) `
        -Response $disallowed `
        -Evidence "status=$($disallowed.statusCode), corsHeaderPresent=$(-not [string]::IsNullOrWhiteSpace((Get-AbuseHeader -Response $disallowed -Name "Access-Control-Allow-Origin")))"

    $options = Invoke-AbuseHttpRequest -Method "OPTIONS" -Uri "$baseUrl/rpc" -Headers (New-AbuseHeaders)
    Add-AbuseCase -Id "options-preflight" `
        -Requirement "Allowed CORS preflight is handled without dispatching JSON-RPC." `
        -Passed (($options.statusCode -eq 204) -and ((Get-AbuseHeader -Response $options -Name "Access-Control-Allow-Origin") -eq $allowedOrigin)) `
        -Response $options `
        -Evidence "status=$($options.statusCode), corsEchoMatchesConfiguredOrigin=$((Get-AbuseHeader -Response $options -Name "Access-Control-Allow-Origin") -eq $allowedOrigin)"

    $unsupported = Invoke-AbuseHttpRequest -Method "POST" -Uri "$baseUrl/rpc" -Headers (New-AbuseHeaders) -ContentType "text/plain" -Body "not-json"
    Add-AbuseCase -Id "unsupported-media-type" `
        -Requirement "Non-JSON POST bodies are rejected with HTTP 415 before JSON parsing." `
        -Passed (($unsupported.statusCode -eq 415) -and ((Get-AbuseResponseSchema -Response $unsupported) -eq "flowmemory.control_plane.unsupported_media_type.v0") -and ((Get-AbuseResponseReasonCode -Response $unsupported) -eq "request.unsupported_media_type")) `
        -Response $unsupported `
        -Evidence "status=$($unsupported.statusCode), reason=$(Get-AbuseResponseReasonCode -Response $unsupported)"

    $malformed = Invoke-AbuseHttpRequest -Method "POST" -Uri "$baseUrl/rpc" -Headers (New-AbuseHeaders) -ContentType "application/json" -Body "{"
    Add-AbuseCase -Id "malformed-json" `
        -Requirement "Malformed JSON returns the stable JSON-RPC parse error envelope." `
        -Passed (($malformed.statusCode -eq 400) -and ((Get-AbuseResponseErrorCode -Response $malformed) -eq -32700) -and ((Get-AbuseResponseReasonCode -Response $malformed) -eq "parse.error") -and ((Get-AbuseResponseNoSecretsFlag -Response $malformed) -eq $true)) `
        -Response $malformed `
        -Evidence "status=$($malformed.statusCode), errorCode=$(Get-AbuseResponseErrorCode -Response $malformed), reason=$(Get-AbuseResponseReasonCode -Response $malformed)"

    $unknown = Invoke-AbuseHttpRequest -Method "POST" -Uri "$baseUrl/rpc" -Headers (New-AbuseHeaders) -ContentType "application/json" -Body (@{ jsonrpc = "2.0"; id = 1; method = "flow_sendRawTransaction" } | ConvertTo-Json -Compress)
    Add-AbuseCase -Id "unknown-method" `
        -Requirement "Unsupported public methods fail closed as JSON-RPC method-not-found errors." `
        -Passed (($unknown.statusCode -eq 200) -and ((Get-AbuseResponseErrorCode -Response $unknown) -eq -32601) -and ((Get-AbuseResponseReasonCode -Response $unknown) -eq "method.not_found")) `
        -Response $unknown `
        -Evidence "status=$($unknown.statusCode), errorCode=$(Get-AbuseResponseErrorCode -Response $unknown), reason=$(Get-AbuseResponseReasonCode -Response $unknown)"

    $transactionSubmitBody = @{
        jsonrpc = "2.0"
        id = "blocked-transaction-submit"
        method = "transaction_submit"
        params = @{ signedEnvelope = @{ schema = "flowmemory.abuse_test_signed_envelope.v0"; signature = "0xabuse" } }
    } | ConvertTo-Json -Depth 8 -Compress
    $transactionSubmit = Invoke-AbuseHttpRequest -Method "POST" -Uri "$baseUrl/rpc" -Headers (New-AbuseHeaders) -ContentType "application/json" -Body $transactionSubmitBody
    Add-AbuseCase -Id "transaction-submit-rejected" `
        -Requirement "Public RPC rejects transaction_submit before local file-intake dispatch." `
        -Passed (($transactionSubmit.statusCode -eq 200) -and ((Get-AbuseResponseErrorCode -Response $transactionSubmit) -eq -32601) -and ((Get-AbuseResponseReasonCode -Response $transactionSubmit) -eq "method.not_found")) `
        -Response $transactionSubmit `
        -Evidence "status=$($transactionSubmit.statusCode), errorCode=$(Get-AbuseResponseErrorCode -Response $transactionSubmit), reason=$(Get-AbuseResponseReasonCode -Response $transactionSubmit)"

    $bridgeObservationSubmitBody = @{
        jsonrpc = "2.0"
        id = "blocked-bridge-observation-submit"
        method = "bridge_observation_submit"
        params = @{ observation = @{ observationId = "abuse-observation" } }
    } | ConvertTo-Json -Depth 8 -Compress
    $bridgeObservationSubmit = Invoke-AbuseHttpRequest -Method "POST" -Uri "$baseUrl/rpc" -Headers (New-AbuseHeaders) -ContentType "application/json" -Body $bridgeObservationSubmitBody
    Add-AbuseCase -Id "bridge-observation-submit-rejected" `
        -Requirement "Public RPC rejects bridge_observation_submit before local bridge observation intake dispatch." `
        -Passed (($bridgeObservationSubmit.statusCode -eq 200) -and ((Get-AbuseResponseErrorCode -Response $bridgeObservationSubmit) -eq -32601) -and ((Get-AbuseResponseReasonCode -Response $bridgeObservationSubmit) -eq "method.not_found")) `
        -Response $bridgeObservationSubmit `
        -Evidence "status=$($bridgeObservationSubmit.statusCode), errorCode=$(Get-AbuseResponseErrorCode -Response $bridgeObservationSubmit), reason=$(Get-AbuseResponseReasonCode -Response $bridgeObservationSubmit)"

    $rawJsonGetBody = @{
        jsonrpc = "2.0"
        id = "blocked-raw-json-get"
        method = "raw_json_get"
        params = @{ source = "launchCore" }
    } | ConvertTo-Json -Depth 8 -Compress
    $rawJsonGet = Invoke-AbuseHttpRequest -Method "POST" -Uri "$baseUrl/rpc" -Headers (New-AbuseHeaders) -ContentType "application/json" -Body $rawJsonGetBody
    Add-AbuseCase -Id "raw-json-get-rejected" `
        -Requirement "Public RPC rejects raw_json_get before raw fixture payloads can be returned." `
        -Passed (($rawJsonGet.statusCode -eq 200) -and ((Get-AbuseResponseErrorCode -Response $rawJsonGet) -eq -32601) -and ((Get-AbuseResponseReasonCode -Response $rawJsonGet) -eq "method.not_found")) `
        -Response $rawJsonGet `
        -Evidence "status=$($rawJsonGet.statusCode), errorCode=$(Get-AbuseResponseErrorCode -Response $rawJsonGet), reason=$(Get-AbuseResponseReasonCode -Response $rawJsonGet)"

    $bridgeObservationAlias = Invoke-AbuseHttpRequest -Method "POST" -Uri "$baseUrl/bridge/observations" -Headers (New-AbuseHeaders) -ContentType "application/json" -Body (@{ observationId = "abuse-observation-alias" } | ConvertTo-Json -Compress)
    Add-AbuseCase -Id "bridge-observation-post-alias-rejected" `
        -Requirement "Public HTTP bridge observation POST alias is rejected instead of wrapping into bridge_observation_submit." `
        -Passed (($bridgeObservationAlias.statusCode -eq 200) -and ((Get-AbuseResponseErrorCode -Response $bridgeObservationAlias) -eq -32601) -and ((Get-AbuseResponseReasonCode -Response $bridgeObservationAlias) -eq "method.not_found")) `
        -Response $bridgeObservationAlias `
        -Evidence "status=$($bridgeObservationAlias.statusCode), errorCode=$(Get-AbuseResponseErrorCode -Response $bridgeObservationAlias), reason=$(Get-AbuseResponseReasonCode -Response $bridgeObservationAlias)"

    $testerWriteDisabled = Invoke-AbuseHttpRequest -Method "POST" -Uri "$baseUrl/tester/wallets/send" -Headers (New-AbuseHeaders) -ContentType "application/json" -Body (@{ from = "tester-a"; to = "tester-b"; amountUnits = "1" } | ConvertTo-Json -Compress)
    Add-AbuseCase -Id "tester-write-disabled-without-owner-token" `
        -Requirement "Authenticated tester write gateway fails closed when owner token env is not configured." `
        -Passed (($testerWriteDisabled.statusCode -eq 403) -and ((Get-AbuseResponseSchema -Response $testerWriteDisabled) -eq "flowmemory.control_plane.tester_write_disabled.v0") -and ((Get-AbuseResponseNoSecretsFlag -Response $testerWriteDisabled) -eq $true)) `
        -Response $testerWriteDisabled `
        -Evidence "status=$($testerWriteDisabled.statusCode), schema=$(Get-AbuseResponseSchema -Response $testerWriteDisabled)"

    $badParamsBody = @{
        jsonrpc = "2.0"
        id = 2
        method = "receipt_list"
        params = @{ limit = 0 }
    } | ConvertTo-Json -Depth 6 -Compress
    $badParams = Invoke-AbuseHttpRequest -Method "POST" -Uri "$baseUrl/rpc" -Headers (New-AbuseHeaders) -ContentType "application/json" -Body $badParamsBody
    Add-AbuseCase -Id "bad-params" `
        -Requirement "Invalid method params return the stable JSON-RPC invalid-params error." `
        -Passed (($badParams.statusCode -eq 200) -and ((Get-AbuseResponseErrorCode -Response $badParams) -eq -32602) -and ((Get-AbuseResponseReasonCode -Response $badParams) -eq "params.invalid")) `
        -Response $badParams `
        -Evidence "status=$($badParams.statusCode), errorCode=$(Get-AbuseResponseErrorCode -Response $badParams), reason=$(Get-AbuseResponseReasonCode -Response $badParams)"

    $emptyBatch = Invoke-AbuseHttpRequest -Method "POST" -Uri "$baseUrl/rpc" -Headers (New-AbuseHeaders) -ContentType "application/json" -Body "[]"
    Add-AbuseCase -Id "empty-batch" `
        -Requirement "Empty JSON-RPC batches are rejected before dispatch." `
        -Passed (($emptyBatch.statusCode -eq 400) -and ((Get-AbuseResponseReasonCode -Response $emptyBatch) -eq "request.batch_empty")) `
        -Response $emptyBatch `
        -Evidence "status=$($emptyBatch.statusCode), reason=$(Get-AbuseResponseReasonCode -Response $emptyBatch)"

    $oversizedBatchPayload = @()
    for ($index = 0; $index -lt 51; $index++) {
        $oversizedBatchPayload += [ordered]@{ jsonrpc = "2.0"; id = $index; method = "health" }
    }
    $oversizedBatch = Invoke-AbuseHttpRequest -Method "POST" -Uri "$baseUrl/rpc" -Headers (New-AbuseHeaders) -ContentType "application/json" -Body ($oversizedBatchPayload | ConvertTo-Json -Depth 6 -Compress)
    $oversizedBatchData = Get-AbuseResponseData -Response $oversizedBatch
    Add-AbuseCase -Id "oversized-batch" `
        -Requirement "JSON-RPC batches above the local cap are rejected before dispatch." `
        -Passed (($oversizedBatch.statusCode -eq 413) -and ((Get-AbuseResponseReasonCode -Response $oversizedBatch) -eq "request.batch_too_large") -and ((Get-AbuseProp -Object $oversizedBatchData -Name "maxBatchRequests") -eq 50)) `
        -Response $oversizedBatch `
        -Evidence "status=$($oversizedBatch.statusCode), reason=$(Get-AbuseResponseReasonCode -Response $oversizedBatch), maxBatchRequests=$(Get-AbuseProp -Object $oversizedBatchData -Name "maxBatchRequests")"

    $oversizedPayload = @{
        jsonrpc = "2.0"
        id = 3
        method = "health"
        params = @{ padding = ("x" * 300000) }
    } | ConvertTo-Json -Depth 6 -Compress
    $oversizedBody = Invoke-AbuseHttpRequest -Method "POST" -Uri "$baseUrl/rpc" -Headers (New-AbuseHeaders) -ContentType "application/json" -Body $oversizedPayload -TimeoutSec 20
    Add-AbuseCase -Id "oversized-body" `
        -Requirement "Request bodies above the local payload cap are rejected with HTTP 413." `
        -Passed (($oversizedBody.statusCode -eq 413) -and ((Get-AbuseResponseSchema -Response $oversizedBody) -eq "flowmemory.control_plane.payload_too_large.v0") -and ((Get-AbuseResponseReasonCode -Response $oversizedBody) -eq "request.payload_too_large") -and ((Get-AbuseResponseNoSecretsFlag -Response $oversizedBody) -eq $true)) `
        -Response $oversizedBody `
        -Evidence "status=$($oversizedBody.statusCode), schema=$(Get-AbuseResponseSchema -Response $oversizedBody), reason=$(Get-AbuseResponseReasonCode -Response $oversizedBody)"

    $notification = Invoke-AbuseHttpRequest -Method "POST" -Uri "$baseUrl/rpc" -Headers (New-AbuseHeaders) -ContentType "application/json" -Body (@{ jsonrpc = "2.0"; method = "health" } | ConvertTo-Json -Compress)
    Add-AbuseCase -Id "notification-no-content" `
        -Requirement "JSON-RPC notifications do not leak data and return HTTP 204." `
        -Passed (($notification.statusCode -eq 204) -and [string]::IsNullOrWhiteSpace("$($notification.bodyText)")) `
        -Response $notification `
        -Evidence "status=$($notification.statusCode), bodyEmpty=$([string]::IsNullOrWhiteSpace("$($notification.bodyText)"))"

    $rateHeaders = @{
        Origin = $allowedOrigin
        "X-Forwarded-For" = "203.0.113.240, 198.51.100.240"
    }
    $rateFirst = Invoke-AbuseHttpRequest -Method "GET" -Uri "$baseUrl/health" -Headers $rateHeaders
    $rateSecond = Invoke-AbuseHttpRequest -Method "GET" -Uri "$baseUrl/health" -Headers $rateHeaders
    $rateThird = Invoke-AbuseHttpRequest -Method "GET" -Uri "$baseUrl/health" -Headers $rateHeaders
    [void] $responseSummaries.Add([ordered]@{
        id = "rate-limit-first"
        httpStatus = $rateFirst.statusCode
        schema = Get-AbuseResponseSchema -Response $rateFirst
        reasonCode = Get-AbuseResponseReasonCode -Response $rateFirst
        errorCode = Get-AbuseResponseErrorCode -Response $rateFirst
        noSecretsFlag = Get-AbuseResponseNoSecretsFlag -Response $rateFirst
        corsHeaderPresent = -not [string]::IsNullOrWhiteSpace((Get-AbuseHeader -Response $rateFirst -Name "Access-Control-Allow-Origin"))
        retryAfterHeaderPresent = -not [string]::IsNullOrWhiteSpace((Get-AbuseHeader -Response $rateFirst -Name "Retry-After"))
    })
    [void] $responseSummaries.Add([ordered]@{
        id = "rate-limit-second"
        httpStatus = $rateSecond.statusCode
        schema = Get-AbuseResponseSchema -Response $rateSecond
        reasonCode = Get-AbuseResponseReasonCode -Response $rateSecond
        errorCode = Get-AbuseResponseErrorCode -Response $rateSecond
        noSecretsFlag = Get-AbuseResponseNoSecretsFlag -Response $rateSecond
        corsHeaderPresent = -not [string]::IsNullOrWhiteSpace((Get-AbuseHeader -Response $rateSecond -Name "Access-Control-Allow-Origin"))
        retryAfterHeaderPresent = -not [string]::IsNullOrWhiteSpace((Get-AbuseHeader -Response $rateSecond -Name "Retry-After"))
    })
    Add-AbuseCase -Id "rate-limit" `
        -Requirement "Per-client rate limiting returns HTTP 429 with Retry-After and no secret material." `
        -Passed (($rateFirst.statusCode -eq 200) -and ($rateSecond.statusCode -eq 200) -and ($rateThird.statusCode -eq 429) -and ((Get-AbuseHeader -Response $rateThird -Name "Retry-After").Length -gt 0) -and ((Get-AbuseResponseSchema -Response $rateThird) -eq "flowmemory.control_plane.rate_limited.v0") -and ((Get-AbuseResponseNoSecretsFlag -Response $rateThird) -eq $true)) `
        -Response $rateThird `
        -Evidence "first=$($rateFirst.statusCode), second=$($rateSecond.statusCode), third=$($rateThird.statusCode), retryAfterPresent=$((Get-AbuseHeader -Response $rateThird -Name "Retry-After").Length -gt 0)"
}
catch {
    $fatalError = $_.Exception.Message
    Add-AbuseCase -Id "abuse-harness-runtime" `
        -Requirement "Temporary local public RPC abuse harness must start and finish without fatal errors." `
        -Passed $false `
        -Evidence "fatalErrorCaptured=true"
}
finally {
    if ($null -ne $serverProcess -and -not $serverProcess.HasExited) {
        Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue
        $serverProcess.WaitForExit(5000) | Out-Null
    }
    foreach ($name in $envNames) {
        [Environment]::SetEnvironmentVariable($name, $originalEnv[$name], "Process")
    }
}

$hygiene = Test-FlowChainResponseHygiene -Responses @($responseSummaries) -EnvNames @("FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE")
Add-AbuseCase -Id "response-hygiene" `
    -Requirement "Abuse-test response summaries do not contain raw env values or secret-shaped material." `
    -Passed ($hygiene.passed -eq $true) `
    -Evidence "findings=$(@($hygiene.findings).Count)"

$failedCases = @($cases | Where-Object { $_.status -ne "passed" })
$status = if ($failedCases.Count -eq 0 -and [string]::IsNullOrWhiteSpace($fatalError)) { "passed" } else { "failed" }
$checks = [ordered]@{
    serverStarted = $serverStarted
    allowedOriginAccepted = @($cases | Where-Object { $_.id -eq "allowed-origin-health" -and $_.status -eq "passed" }).Count -eq 1
    disallowedOriginRejected = @($cases | Where-Object { $_.id -eq "disallowed-origin-rejected" -and $_.status -eq "passed" }).Count -eq 1
    optionsPreflightPassed = @($cases | Where-Object { $_.id -eq "options-preflight" -and $_.status -eq "passed" }).Count -eq 1
    unsupportedMediaTypeRejected = @($cases | Where-Object { $_.id -eq "unsupported-media-type" -and $_.status -eq "passed" }).Count -eq 1
    malformedJsonRejected = @($cases | Where-Object { $_.id -eq "malformed-json" -and $_.status -eq "passed" }).Count -eq 1
    unknownMethodRejected = @($cases | Where-Object { $_.id -eq "unknown-method" -and $_.status -eq "passed" }).Count -eq 1
    transactionSubmitRejected = @($cases | Where-Object { $_.id -eq "transaction-submit-rejected" -and $_.status -eq "passed" }).Count -eq 1
    bridgeObservationSubmitRejected = @($cases | Where-Object { $_.id -eq "bridge-observation-submit-rejected" -and $_.status -eq "passed" }).Count -eq 1
    rawJsonGetRejected = @($cases | Where-Object { $_.id -eq "raw-json-get-rejected" -and $_.status -eq "passed" }).Count -eq 1
    bridgeObservationPostAliasRejected = @($cases | Where-Object { $_.id -eq "bridge-observation-post-alias-rejected" -and $_.status -eq "passed" }).Count -eq 1
    testerWriteGatewayFailsClosed = @($cases | Where-Object { $_.id -eq "tester-write-disabled-without-owner-token" -and $_.status -eq "passed" }).Count -eq 1
    badParamsRejected = @($cases | Where-Object { $_.id -eq "bad-params" -and $_.status -eq "passed" }).Count -eq 1
    emptyBatchRejected = @($cases | Where-Object { $_.id -eq "empty-batch" -and $_.status -eq "passed" }).Count -eq 1
    oversizedBatchRejected = @($cases | Where-Object { $_.id -eq "oversized-batch" -and $_.status -eq "passed" }).Count -eq 1
    oversizedBodyRejected = @($cases | Where-Object { $_.id -eq "oversized-body" -and $_.status -eq "passed" }).Count -eq 1
    notificationNoContent = @($cases | Where-Object { $_.id -eq "notification-no-content" -and $_.status -eq "passed" }).Count -eq 1
    rateLimitRejected = @($cases | Where-Object { $_.id -eq "rate-limit" -and $_.status -eq "passed" }).Count -eq 1
    responseHygienePassed = $hygiene.passed -eq $true
}

$report = [ordered]@{
    schema = "flowchain.public_rpc_abuse_test_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    abuseTestReady = $status -eq "passed"
    validationScope = "local-control-plane-public-rpc-abuse-harness"
    ownerValuesRequired = $false
    localOnly = $true
    serverBoundToLocalhost = $true
    bodyLimitBytes = 262144
    batchLimit = 50
    checks = $checks
    failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
    caseCounts = [ordered]@{
        passed = @($cases | Where-Object { $_.status -eq "passed" }).Count
        failed = $failedCases.Count
        total = $cases.Count
    }
    cases = @($cases)
    responseHygiene = $hygiene
    reportPaths = [ordered]@{
        report = $reportFullPath
        markdown = $markdownFullPath
        stdout = $stdoutPath
        stderr = $stderrPath
    }
    fatalErrorCaptured = -not [string]::IsNullOrWhiteSpace($fatalError)
    fatalErrorMessage = if ([string]::IsNullOrWhiteSpace($fatalError)) { "" } else { $fatalError }
    noLiveBroadcast = $true
    envValuesPrinted = $false
    noSecrets = $hygiene.passed -eq $true
}

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Public RPC Abuse Test")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Abuse test ready: $($report.abuseTestReady)")
$markdownLines.Add("")
$markdownLines.Add("This local harness starts a temporary private control-plane server and records public RPC abuse behavior without owner endpoint values.")
$markdownLines.Add("")
$markdownLines.Add("## Cases")
$markdownLines.Add("")
$markdownLines.Add("| Requirement | Status | Evidence |")
$markdownLines.Add("| --- | --- | --- |")
foreach ($case in $cases) {
    $markdownLines.Add("| $($case.requirement.Replace('|','/')) | $($case.status) | $($case.evidence.Replace('|','/')) |")
}

$reportText = $report | ConvertTo-Json -Depth 20
Assert-FlowChainNoSecretText -Text $reportText -Label "public RPC abuse test report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "public RPC abuse test markdown"
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain public RPC abuse test status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($failedCases.Count -gt 0) {
    Write-Host "Failed cases: $((@($failedCases | ForEach-Object { $_.id })) -join ', ')"
}
if ($status -eq "passed") {
    exit 0
}
exit 1
