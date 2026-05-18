# End-To-End Search Proof

Dashboard search box evidence is in `browser-dom-evidence.json`; API search evidence is in `search-proof-queries.json`.

Verified end-to-end search paths:

- Base tx hash: visible result count `> 0`.
- Bridge observation ID: visible result count `> 0`.
- Bridge credit ID: visible result count `> 0`.
- Local credited account: visible result count `> 0`.
- Local transfer tx ID: visible result count `> 0`.
- Swap tx ID: visible result count `> 0`.
- Withdrawal intent ID: visible result count `> 0`.
- Release evidence ID: visible result count `> 0`.

The same identifiers return matches from `GET /explorer/search`, so the UI path is backed by the existing control-plane API or explicitly marked deterministic fallback data.
