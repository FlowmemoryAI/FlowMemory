# Verify Public RPC Before Sharing

Run these on the owner host after DNS, TLS, allowed origins, rate limit, and backup path are configured locally.

## Owner-Host Render Commands

- powershell -NoProfile -ExecutionPolicy Bypass -File render-public-rpc-bundle.template.ps1 -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -OwnerEnvFile <FLOWCHAIN_OWNER_ENV_FILE> -RepoRoot <FLOWCHAIN_REPO_ABSOLUTE_PATH> -ServiceUser <FLOWCHAIN_SERVICE_USER> -ServiceGroup <FLOWCHAIN_SERVICE_GROUP> -TlsCertificatePath <PATH_TO_TLS_CERTIFICATE> -TlsCertificateKeyPath <PATH_TO_TLS_CERTIFICATE_KEY> -NginxExe <FLOWCHAIN_NGINX_EXE>

## Repository Checks

- npm run flowchain:service:restart -- -LiveProfile
- npm run flowchain:service:supervisor -- -Once
- npm run flowchain:service:supervisor:validate
- npm run flowchain:service:install:systemd:validate
- npm run flowchain:service:status
- npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30
- npm run flowchain:ops:snapshot -- -AllowBlocked
- npm run flowchain:public-rpc:validate
- npm run flowchain:public-rpc:check
- npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked
- npm run flowchain:tester:gateway:e2e
- npm run flowchain:wallet:live-tester:e2e
- npm run flowchain:backup:restore:validate
- npm run flowchain:backup:check
- npm run flowchain:public-deployment:contract -- -AllowBlocked
- npm run flowchain:external-tester:packet -- -AllowBlocked
- npm run flowchain:live:cutover:rehearsal -- -AllowBlocked
- npm run flowchain:no-secret:scan
- npm run flowchain:ops:launch-watch -- -NoRefresh
- npm run flowchain:truth-table -- -AllowBlocked

## Owner-Host Preflight Checks

- npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>
- npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -StartBridgeRelayerLoop
- systemd-analyze verify <FLOWCHAIN_SYSTEMD_RENDERED_UNIT>
- systemd-analyze verify <FLOWCHAIN_SUPERVISOR_SYSTEMD_RENDERED_UNIT>
- nginx -t
- bash <FLOWCHAIN_NGINX_PREFLIGHT_SCRIPT>
- powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_NGINX_WINDOWS_PREFLIGHT_SCRIPT>
