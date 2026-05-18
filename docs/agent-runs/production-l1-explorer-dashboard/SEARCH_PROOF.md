# Search Proof

Evidence file: `docs/agent-runs/production-l1-explorer-dashboard/search-proof-queries.json`.

Control-plane search route: `GET /explorer/search?q=...&limit=8`, backed by JSON-RPC `explorer_search`.

Verified search counts:

- Block height `1`: 8 matches.
- Block hash `0x61e9...1a9b`: 8 matches.
- Transaction ID `0x2cff...3189`: 2 matches.
- Account `0x0673...7f21`: 2 matches.
- Token `token:flowchain-pilot-ltu`: 6 matches.
- Pool `pool:fclt-local-unit`: 3 matches.
- Bridge observation `0x0430...223c`: 8 matches.
- Bridge credit `0xff3e...74a6`: 7 matches.
- Withdrawal intent `0xe6f0...1751`: 5 matches.

The browser verification also filled the dashboard search box for Base tx hash, bridge observation ID, bridge credit ID, credited account, local transfer tx ID, swap tx ID, withdrawal intent ID, and release evidence ID; each produced at least one visible result.
