# Second Computer Proof

Fresh Windows command order:

```powershell
winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements
winget install --id GitHub.cli --exact --source winget --accept-package-agreements --accept-source-agreements
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
gh auth login
gh repo clone FlowmemoryAI/FlowMemory "$env:USERPROFILE\FlowMemory\FlowMemory"
cd "$env:USERPROFILE\FlowMemory\FlowMemory"
npm install
npm install --prefix apps/dashboard
npm install --prefix crypto
npm run flowchain:second-computer:verify
npm run flowchain:production-l1:e2e
```

Restore from export:

```powershell
npm run flowchain:import -- --BundlePath devnet/local/export/flowchain-local-state.zip -Force
npm run flowchain:node:status
```

Start and inspect:

```powershell
npm run flowchain:node:start
npm run flowchain:node:status
npm run control-plane:serve
npm run workbench:dev
```

Stop:

```powershell
npm run flowchain:emergency:stop-local
```
