# FlowChain Ops Escalation Dry Run

Generated: 2026-05-17T20:49:56.6773808Z
Status: passed
Current alert state: blocked

This dry run maps current ops findings to local operator actions. It does not send network delivery or store external delivery credentials.

## Checks

- opsSnapshotLoaded: True
- opsAlertRulesLoaded: True
- opsSnapshotStatusSafe: True
- opsAlertRulesPassed: True
- alertRefreshCommandPassed: True
- packageScriptsPresent: True
- notificationPlanNoNetworkDelivery: True
- notificationPlanStoresNoSecrets: True
- notificationPlanOutOfRepo: True
- activeRulesExistInManifest: True
- activeRulesHaveCommands: True
- everyCurrentFindingMapped: True
- everyCurrentFindingHasCommands: True
- noCommandUrls: True
- noInlineEnvAssignments: True
- dryRunEventsDoNotSend: True
- dryRunEventsStoreNoCredentials: True
- envValuesPrintedFalse: True
- noSecrets: True
- broadcastsFalse: True

## Dry Run Events

- public-rpc-not-ready: blocked, rule public-rpc-not-shareable, commands `npm run flowchain:public-rpc:check; npm run flowchain:public-rpc:validate; npm run flowchain:public-rpc:abuse-test`
- backup-not-ready: blocked, rule backup-not-ready, commands `npm run flowchain:backup:restore:validate; npm run flowchain:backup:check`
- bridge-not-ready: blocked, rule bridge-not-ready, commands `npm run flowchain:bridge:live:check; npm run flowchain:bridge:infra:check; npm run flowchain:bridge:emergency-stop`
- bridge-relayer-not-ready: blocked, rule bridge-relayer-not-ready, commands `npm run flowchain:bridge:relayer:once -- -AllowBlocked; npm run flowchain:bridge:live:check; npm run flowchain:bridge:infra:check`
- external-tester-not-shareable: blocked, rule external-tester-not-shareable, commands `npm run flowchain:tester:readiness; npm run flowchain:external-tester:packet`
- deployment-contract-not-ready: blocked, rule deployment-contract-not-ready, commands `npm run flowchain:public-deployment:contract -- -AllowBlocked`
