# FlowChain Tester Write Token Setup

Generated: 2026-05-21T08:40:21.4448708+00:00
Status: passed

A tester write bearer token exists in ignored local storage, and the ignored owner env file has the tester write fields. The committed report and this markdown do not contain the raw token or token digest.

Token file: `devnet/local/owner-inputs/tester-write-token.local.txt`
Owner env file: `devnet/local/owner-inputs/flowchain-owner.local.env`
Token created: False
Existing token preserved: True

## Next Commands

- npm run flowchain:owner-env:readiness -- -AllowBlocked
- npm run flowchain:tester:gateway:e2e
- npm run flowchain:external-tester:packet -- -AllowBlocked

Share the raw token out-of-band only with approved testers after the public deployment contract marks the packet shareable. Do not paste it into chat, GitHub, or committed files.
