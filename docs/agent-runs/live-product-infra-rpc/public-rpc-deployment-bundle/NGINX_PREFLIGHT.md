# Nginx Public RPC Preflight

Run this on the owner host after rendering `nginx-flowchain-rpc.template.conf` outside the repository and before sharing the public URL.

Checklist:

- Render the Nginx template to `<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>`.
- Replace `<FLOWCHAIN_RPC_PUBLIC_HOST>`, `<PATH_TO_TLS_CERTIFICATE>`, `<PATH_TO_TLS_CERTIFICATE_KEY>`, and `<FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>` only on the owner host.
- Confirm the private origin remains `127.0.0.1:8787`.
- Confirm TLS, rate limiting, timeout guardrails, Origin forwarding, X-Forwarded headers, and defensive response headers are present.
- Run `nginx -t` before every reload.
- Run `bash <FLOWCHAIN_NGINX_PREFLIGHT_SCRIPT>` after installing the rendered config.

The preflight script uses only local health and public read/readiness requests. It does not send live transactions.
