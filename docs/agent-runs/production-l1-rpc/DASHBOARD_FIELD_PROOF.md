# Dashboard Field Proof

The smoke client validates every dashboard-facing method in `DASHBOARD_CONTRACT.md`.

Evidence from `npm run control-plane:smoke`:

- chain and node fields: `health`, `node_status`, `sync_status`, `chain_status`, `finality_status`;
- explorer fields: `block_list`, `block_get`, `transaction_list`, `transaction_get`, `event_list`, `event_get`, `receipt_get`;
- account fields: `account_list`, `account_get`, `balance_get`, `wallet_metadata_list`, `wallet_metadata_get`;
- token and DEX fields: token, balance, pool, LP, swap, and product-flow list/detail methods;
- Flow Memory fields: Rootfield, agent, model, receipt, artifact, verifier, memory cell, challenge, finality, and provenance methods;
- bridge fields: config, status, observation, deposit, credit, withdrawal intent, release evidence, replay rejection, and pilot methods;
- diagnostics fields: `raw_json_get` and `devnet_state`.

No dashboard view needs to parse raw logs. Raw JSON is retained only for explicit local diagnostics and is scanned for secret-shaped material before return.
