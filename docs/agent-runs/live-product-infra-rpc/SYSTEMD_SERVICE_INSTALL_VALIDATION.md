# FlowChain Systemd Service Install Validation

Generated: 2026-05-21T17:46:34.8739397Z
Status: passed

This validation proves the owner Linux systemd install plan is present, no-secret, non-mutating, live-profile by default, and includes autorecovery through the FlowChain supervisor.
It also executes the real default Plan and bridge-relayer opt-in Plan actions against rendered units in a temporary directory and verifies that no host mutation occurs.

## Checks

| Check | Result |
| --- | --- |
| installScriptExists | True |
| installPackageScriptPresent | True |
| validationPackageScriptPresent | True |
| publicRpcBundleExists | True |
| liveServiceTemplateExists | True |
| supervisorTemplateExists | True |
| renderScriptExists | True |
| verifyRunbookExists | True |
| rollbackRunbookExists | True |
| liveServiceUsesLiveProfile | True |
| liveServiceRunsStatusAfterStart | True |
| liveServiceReloadRestartsLiveProfile | True |
| liveServiceStopPreservesState | True |
| liveServiceRestartOnFailure | True |
| liveServiceRemainAfterExit | True |
| supervisorUsesAutorecoveryLoop | True |
| supervisorRestartAlways | True |
| bridgeRelayerDefaultOff | True |
| bridgeRelayerOptInPlanCommandPassed | True |
| bridgeRelayerOptInPlanReportPassed | True |
| bridgeRelayerOptInPlanDidNotMutate | True |
| bridgeRelayerOptInPlanUsesRenderedUnits | True |
| bridgeRelayerOptInStartsLoop | True |
| bridgeRelayerOptInUsesSupervisor | True |
| bridgeRelayerOptInPlanNoSecrets | True |
| bridgeRelayerOptInPlanEnvValuesPrintedFalse | True |
| bridgeRelayerOptInPlanBroadcastsFalse | True |
| ownerEnvFileUsed | True |
| repoWorkingDirectoryUsed | True |
| cargoTargetDirIsExternalized | True |
| leastPrivilegeHardeningPresent | True |
| writePathsScoped | True |
| installTargetPresent | True |
| renderScriptRendersSystemdUnits | True |
| verifyRunbookMentionsSystemdVerify | True |
| rollbackRunbookMentionsSystemctl | True |
| installPlanValidationPassed | True |
| installPlanCommandPassed | True |
| installPlanDidNotMutate | True |
| installPlanUsesRenderedUnits | True |
| installPlanReportNoSecrets | True |
| installPlanReportEnvValuesPrintedFalse | True |
| installPlanReportBroadcastsFalse | True |
| installCommandsPresent | True |
| statusCommandsPresent | True |
| uninstallCommandsPresent | True |
| hostMutationPerformedFalse | True |
| envValuesPrintedFalse | True |
| secretMarkerFindingsEmpty | True |
| noSecrets | True |
| broadcastsFalse | True |

## Install Plan

- `sudo install -o root -g root -m 0644 <FLOWCHAIN_RENDER_DIR>/flowchain-live.service /etc/systemd/system/flowchain-live.service`
- `sudo install -o root -g root -m 0644 <FLOWCHAIN_RENDER_DIR>/flowchain-supervisor.service /etc/systemd/system/flowchain-supervisor.service`
- `sudo systemctl daemon-reload`
- `sudo systemctl enable --now flowchain-live.service`
- `sudo systemctl enable --now flowchain-supervisor.service`

## Status Plan

- `systemctl status flowchain-live.service --no-pager`
- `systemctl status flowchain-supervisor.service --no-pager`
- `journalctl -u flowchain-live.service -u flowchain-supervisor.service --since -1h --no-pager`
- `npm run flowchain:service:status`
- `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30`

## Uninstall Plan

- `sudo systemctl disable --now flowchain-supervisor.service`
- `sudo systemctl disable --now flowchain-live.service`
- `sudo rm -f /etc/systemd/system/flowchain-supervisor.service /etc/systemd/system/flowchain-live.service`
- `sudo systemctl daemon-reload`
