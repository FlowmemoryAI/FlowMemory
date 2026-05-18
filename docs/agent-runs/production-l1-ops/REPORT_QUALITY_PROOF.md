# Report Quality Proof

The final report includes per-subsystem entries with:

- owner;
- command;
- status;
- log path;
- report path when available;
- blocker class: `mockPath`, `liveReadiness`, `liveBroadcast`, or `none`;
- reason on failure or block.

Latest summary:

- Overall: `passed-with-live-blockers`.
- Mock path: `passed`.
- Live readiness: `blocked`.
- Live broadcast: not run; requires explicit operator acknowledgement and owner env.

Missing live env is represented as `blocked`, not a crash.

Unsafe live config is represented as `failed` by `npm run flowchain:bridge:live:check`, with env names only.

Missing strict live-pilot proof commands include owner, command, reason, log path, report path, and blocker class in `missingSubsystemCommands`.

`failureBlockerDetails` repeats every non-pass/blocker row with subsystem, owner, command, status, log path, report path, blocker class, and explicit mock/live-readiness/live-broadcast impact booleans.
