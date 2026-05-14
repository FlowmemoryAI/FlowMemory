# Install Proof

Windows prerequisite and install commands:

```powershell
npm install
npm install --prefix apps/dashboard
npm install --prefix crypto
npm run flowchain:prereq
npm run flowchain:doctor
```

Authenticated private-repo path:

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
npm run flowchain:production-l1:e2e
```

Offline bundle path:

```powershell
npm run flowchain:second-computer:bundle
```

On the second computer:

```powershell
Expand-Archive .\flowchain-second-computer-source-bundle.zip -DestinationPath "$env:USERPROFILE\FlowMemory"
cd "$env:USERPROFILE\FlowMemory\FlowMemory"
npm install
npm install --prefix apps/dashboard
npm install --prefix crypto
npm run flowchain:second-computer:verify
npm run flowchain:production-l1:e2e
```

Latest local prerequisite proof:

- `npm run flowchain:prereq` passed inside the final root command.
- `npm run flowchain:doctor` passed with local live mode blocked on env names.

