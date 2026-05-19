# Windows Nginx Public RPC Preflight

Run this on the Windows owner host after rendering `nginx-flowchain-rpc.template.conf` outside the repository and before sharing the public URL.

Checklist:

- Render the Nginx template to `<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>`.
- Replace `<FLOWCHAIN_RPC_PUBLIC_HOST>`, `<PATH_TO_TLS_CERTIFICATE>`, `<PATH_TO_TLS_CERTIFICATE_KEY>`, and `<FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>` only on the owner host.
- Set `<FLOWCHAIN_NGINX_EXE>` to the local `nginx.exe` path.
- Confirm the private origin remains `127.0.0.1:8787`.
- Confirm TLS, rate limiting, Origin forwarding, X-Forwarded headers, and defensive response headers are present.
- Run `powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_NGINX_PREFLIGHT_SCRIPT>` after installing the rendered config.

The PowerShell preflight uses local health and public read/readiness requests only. It does not send live transactions.
