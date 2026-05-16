# Verify Public RPC Before Sharing

Run these on the owner host after DNS, TLS, allowed origins, rate limit, and backup path are configured locally.

- npm run flowchain:service:restart -- -LiveProfile
- npm run flowchain:service:status
- npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30
- npm run flowchain:ops:snapshot -- -AllowBlocked
- npm run flowchain:public-rpc:validate
- npm run flowchain:public-rpc:check
- npm run flowchain:backup:restore:validate
- npm run flowchain:backup:check
- npm run flowchain:public-deployment:contract -- -AllowBlocked
- npm run flowchain:external-tester:packet -- -AllowBlocked
