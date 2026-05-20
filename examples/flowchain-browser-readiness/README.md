# FlowChain Browser Readiness Example

This no-dependency browser starter checks only public-safe FlowChain readiness
endpoints:

- `GET /rpc/discover`
- `GET /rpc/readiness`

It does not submit transactions, read private devnet state, store secrets, or
claim public shareability before the readiness contract says it is safe.

Run the mechanical smoke test:

```powershell
npm run smoke --prefix examples/flowchain-browser-readiness
```

Open `index.html` while the local control plane is running, or serve this
directory from any static file server.
