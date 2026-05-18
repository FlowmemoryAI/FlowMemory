param(
    [ValidateSet("Env", "Validate", "PrepareDepositEvidence", "PrepareReleaseEvidence")]
    [string] $Action = "Env",

    [switch] $Live,

    [string] $LockboxAddress = "",

    [string] $BaseRecipient = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot

$command = switch ($Action) {
    "Env" { "env" }
    "Validate" { "validate" }
    "PrepareDepositEvidence" { "prepare-deposit-evidence" }
    "PrepareReleaseEvidence" { "prepare-release-evidence" }
}

$args = @("run", "wallet:operator-bridge", "--prefix", "crypto", "--", $command)
if ($Live) {
    $args += "--live"
}
if (-not [string]::IsNullOrWhiteSpace($LockboxAddress)) {
    $args += @("--lockbox-address", $LockboxAddress)
}
if (-not [string]::IsNullOrWhiteSpace($BaseRecipient)) {
    $args += @("--base-recipient", $BaseRecipient)
}

Invoke-FlowChainCommand -Label "Run FlowChain wallet operator bridge command" -FilePath "npm" -ArgumentList $args

