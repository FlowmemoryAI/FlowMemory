# FlowMemory Crypto Test Vectors

Status: draft v0.

`flowpulse-observation-v0.json` contains the primary FlowPulse v0 observation, receipt, artifact, verifier report, worker signature digest, and verifier signature digest vector.

`../fixtures/vectors.json` contains the package-level vector set validated by `npm run validate:vectors`.

The vectors are not production data and contain no production secrets. The worker signature entry intentionally includes the EIP-712 domain separator, struct hash, and signing digest, but no private key or signature.

Use these vectors to verify independent implementations in contracts, verifier services, and off-chain tooling before any schema is treated as stable.
