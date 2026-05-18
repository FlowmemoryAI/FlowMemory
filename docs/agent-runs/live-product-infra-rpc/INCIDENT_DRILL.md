# FlowChain Incident Drill

Generated: 2026-05-18T06:05:07.7226876Z
Status: passed
Incident drill ready: True

This drill uses synthetic ops input reports for incident conditions, then checks the live local services are still running. It does not stop services, mutate chain state, broadcast bridge transactions, or require owner values.

## Cases

| Case | Status | Evidence |
| --- | --- | --- |
| baseline-owner-blockers-only | passed | expectedStatus=blocked, actualStatus=blocked, exitCode=0, missingCodes=0, commandsPresent=True, safeFlags=True |
| deployment-refresh-aborted-critical | passed | expectedStatus=failed, actualStatus=failed, exitCode=1, missingCodes=0, commandsPresent=True, safeFlags=True |
| node-down-critical | passed | expectedStatus=failed, actualStatus=failed, exitCode=1, missingCodes=0, commandsPresent=True, safeFlags=True |
| control-plane-down-critical | passed | expectedStatus=failed, actualStatus=failed, exitCode=1, missingCodes=0, commandsPresent=True, safeFlags=True |
| stale-state-critical | passed | expectedStatus=failed, actualStatus=failed, exitCode=1, missingCodes=0, commandsPresent=True, safeFlags=True |
| height-not-advancing-critical | passed | expectedStatus=failed, actualStatus=failed, exitCode=1, missingCodes=0, commandsPresent=True, safeFlags=True |
| no-secret-scan-critical | passed | expectedStatus=failed, actualStatus=failed, exitCode=1, missingCodes=0, commandsPresent=True, safeFlags=True |
| bridge-relayer-guardrail-critical | passed | expectedStatus=failed, actualStatus=failed, exitCode=1, missingCodes=0, commandsPresent=True, safeFlags=True |
| bridge-relayer-loop-unhealthy-critical | passed | expectedStatus=failed, actualStatus=failed, exitCode=1, missingCodes=0, commandsPresent=True, safeFlags=True |
| recovery-command-print | passed | exitCode=0, recoverySteps=8, emergencyCommands=4 |
| post-drill-live-status | passed | exitCode=0, status=passed, node=running, controlPlane=running |
