# FlowChain Public RPC Deployment Bundle

This bundle is placeholder-only. It is safe to commit because it contains env names, templates, and commands, not owner values.

Files:

- `nginx-flowchain-rpc.template.conf`: HTTPS reverse-proxy template for the private origin `127.0.0.1:8787`.
- `flowchain-live.service.template`: systemd unit template for the owner-host live service.
- `flowchain-supervisor.service.template`: systemd unit template for continuous service autorecovery.
- `nginx-preflight.template.sh`: Nginx config-test and public read preflight script template.
- `NGINX_PREFLIGHT.md`: Nginx render, TLS, rate-limit, CORS, and reload checklist.
- `owner-public-rpc.env.example`: local owner env-file shape with blank values.
- `VERIFY.md`: pre-share verification commands.
- `ROLLBACK.md`: rollback and emergency commands.
- `bundle-checks.json`: machine-checkable proof that required placeholders and safety properties are present.
