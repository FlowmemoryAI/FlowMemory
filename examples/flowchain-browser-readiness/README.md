# FlowChain Browser Readiness Starter

This Vite/React browser starter checks only public-safe FlowChain readiness
endpoints:

- `GET /rpc/discover`
- `GET /rpc/readiness`

It does not submit transactions, read private devnet state, store secrets, or
claim public shareability before the readiness contract says it is safe.

Install from the repo root:

```powershell
npm install
```

Run the starter:

```powershell
npm run flowchain:browser-readiness:dev
```

Build the starter:

```powershell
npm run flowchain:browser-readiness:build
```

Run the mechanical smoke test:

```powershell
npm run flowchain:browser-readiness:smoke
```
