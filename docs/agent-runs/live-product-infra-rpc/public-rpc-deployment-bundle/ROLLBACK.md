# Public RPC Rollback

Use these commands if the public edge, RPC service, or tester sharing path behaves incorrectly.

## Repository Rollback Commands

- npm run flowchain:ops:snapshot -- -AllowBlocked
- npm run flowchain:service:status
- npm run flowchain:service:restart -- -LiveProfile
- npm run flowchain:service:stop
- npm run flowchain:emergency:stop-local

## Owner-Host Edge Rollback Commands

- systemctl stop flowchain-supervisor.service
- systemctl stop flowchain-live.service
- cp <PREVIOUS_FLOWCHAIN_RPC_NGINX_CONF> <FLOWCHAIN_RPC_NGINX_RENDERED_CONF>
- nginx -t
- systemctl reload nginx
- systemctl restart flowchain-live.service
- systemctl restart flowchain-supervisor.service
