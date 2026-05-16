# Public RPC Rollback

Use these commands if the public edge, RPC service, or tester sharing path behaves incorrectly.

- npm run flowchain:ops:snapshot -- -AllowBlocked
- npm run flowchain:service:status
- npm run flowchain:service:restart -- -LiveProfile
- npm run flowchain:service:stop
- npm run flowchain:emergency:stop-local
