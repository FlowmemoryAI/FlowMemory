# FlowChain Bridge Relayer Loop Validation

Generated: 2026-05-17T20:41:09.7434978Z
Status: passed

This validation starts an isolated live service with the bridge relayer loop enabled, verifies the loop is reported as running, then stops the service and confirms the relayer loop is not left running.

## Checks

- startCommandPassed: True
- startReportWritten: True
- liveProfile: True
- relayerLoopRequested: True
- relayerLoopStartedOrRunning: True
- relayerPidRecorded: True
- relayerPollSecondsRecorded: True
- relayerQueuesRuntimeHandoffs: True
- statusCommandPassed: True
- statusReportsRelayerRunning: True
- statusRelayerCommandLineMatched: True
- statusRelayerReportFresh: True
- statusRelayerReportAcceptable: True
- statusRelayerReportBlockedOnlyOnOwnerInputs: True
- statusRelayerReportNoSecrets: True
- statusRelayerReportNoBroadcasts: True
- statusRelayerReportHealthy: True
- stopCommandPassed: True
- stopPreservedState: True
- stopHandledRelayerLoop: True
- statusAfterStopCommandPassed: True
- statusAfterStopNotRunning: True
- envValuesPrintedFalse: True
- noSecrets: True
- broadcastsFalse: True

## Commands

- validate: npm run flowchain:bridge:relayer:loop:validate
- start: npm run flowchain:service:start -- -LiveProfile -StartBridgeRelayerLoop
- status: npm run flowchain:service:status -- -AllowBlocked
- stop: npm run flowchain:service:stop
