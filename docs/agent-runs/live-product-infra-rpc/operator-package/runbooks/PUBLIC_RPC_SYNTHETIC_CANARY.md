# FlowChain Public RPC Synthetic Canary

Generated: 2026-05-21T17:05:40.9727317Z
Status: blocked

This canary runs only read-only public endpoint probes. It does not create wallets, request faucet funds, submit transactions, or broadcast bridge operations.

## Public Launch Boundary

- Required owner input names: `FLOWCHAIN_RPC_PUBLIC_URL`
- Missing owner input names: `FLOWCHAIN_RPC_PUBLIC_URL`
- Endpoint value printed: `false`
- Network probes run: `False`

## Probe Plan

- HTTP GET paths: `/health, /rpc/discover, /rpc/readiness, /chain/status`
- JSON-RPC methods: `chain_status, node_status, block_list, mempool_list`
- Denied write methods: `transaction_submit, wallet_send, wallet_create, tester_wallet_send, faucet_request, bridge_credit_apply`

## Artifacts

- Report: docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json
