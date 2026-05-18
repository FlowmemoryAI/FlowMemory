# Secret Scan Proof

Commands:

```powershell
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
npm run flowchain:emergency:export-evidence
```

Latest status:

- No-secret scan: passed.
- Unsafe-claim scan: passed.
- Evidence stage no-secret scan: passed.
- Evidence bundle manifest safety check: passed.

Scanned surfaces include:

- final command reports and logs;
- full-smoke and product reports;
- real-value pilot reports;
- dashboard fixtures;
- bridge mock evidence;
- wallet public metadata.

Evidence export excludes:

- `.git`;
- `node_modules`;
- Rust target directories;
- build outputs;
- env files;
- local vaults;
- private-key material;
- seed phrase and mnemonic files;
- RPC credentials;
- API keys;
- webhooks;
- nested archives.
