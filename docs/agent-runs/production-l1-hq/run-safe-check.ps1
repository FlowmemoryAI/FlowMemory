param(
    [Parameter(Mandatory = $true)]
    [string] $Slug,

    [Parameter(Mandatory = $true)]
    [string] $Command,

    [Parameter(Mandatory = $true)]
    [string] $LogDir,

    [int] $TimeoutSeconds = 1800
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$stdoutPath = Join-Path $LogDir "$Slug.stdout.log"
$stderrPath = Join-Path $LogDir "$Slug.stderr.log"
$resultPath = Join-Path $LogDir "$Slug.result.json"
$startedAt = (Get-Date).ToUniversalTime()
$timeoutMs = [Math]::Max(1, $TimeoutSeconds) * 1000

$cmdLine = "/d /s /c `"$Command 1> `"$stdoutPath`" 2> `"$stderrPath`"`""
$process = Start-Process -FilePath "cmd.exe" -ArgumentList $cmdLine -WorkingDirectory (Get-Location) -WindowStyle Hidden -PassThru
$timedOut = -not $process.WaitForExit($timeoutMs)
if ($timedOut) {
    try {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
    catch {
    }
}

$exitCode = if ($timedOut) { 124 } else { $process.ExitCode }
$endedAt = (Get-Date).ToUniversalTime()
$status = if ($exitCode -eq 0) {
    "passed"
}
elseif ($timedOut) {
    "timeout"
}
else {
    "failed"
}

$result = [ordered]@{
    schema = "flowchain.safe_check_result.v0"
    slug = $Slug
    command = $Command
    status = $status
    exitCode = $exitCode
    timedOut = [bool] $timedOut
    startedAt = $startedAt.ToString("o")
    endedAt = $endedAt.ToString("o")
    durationSeconds = [Math]::Round(($endedAt - $startedAt).TotalSeconds, 3)
    stdoutLog = $stdoutPath
    stderrLog = $stderrPath
}

$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding utf8
$result | ConvertTo-Json -Compress -Depth 8
