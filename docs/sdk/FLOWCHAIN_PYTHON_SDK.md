# FlowChain Python SDK

Status: local/private SDK and CLI for Python builders.

The Python SDK lives at:

```text
sdks/python
```

It uses only the Python standard library and defaults to:

```text
http://127.0.0.1:8787/rpc
```

## Client Example

```python
from flowchain import FlowChainClient

client = FlowChainClient("http://127.0.0.1:8787/rpc")
readiness = client.rpc_readiness()
status = client.chain_status()
blocks = client.block_list({"limit": 5})
balances = client.wallet_balances({"limit": 5})
transfer = client.wallet_send(
    "local-account:sender",
    "local-account:recipient",
    "1",
    memo="python-sdk-local-test",
    apply_block=True,
    create_recipient=True,
)
```

## CLI Examples

```powershell
$env:PYTHONPATH = "sdks/python"
python -m flowchain.cli discover --json
python -m flowchain.cli readiness --json
python -m flowchain.cli status --json
python -m flowchain.cli blocks --json --limit 5
python -m flowchain.cli wallet-balances --json --limit 5
python -m flowchain.cli wallet-transfers --json --limit 5
python -m flowchain.cli bridge-status --json
python -m flowchain.cli wait-transaction --json --tx <tx-id> --seconds 30
```

## Quickstart

```powershell
python examples/flowchain-python-quickstart.py
python examples/flowchain-python-quickstart.py --send
```

The `--send` mode submits a private local wallet transfer through the local
control plane. It does not enable public write access or broadcast to Base.

## Verification

```powershell
python -m unittest discover sdks/python/tests
npm run flowchain:python-sdk:test
npm run flowchain:dev-pack:e2e
```

`flowchain:dev-pack:e2e` runs the Python unit tests, calls the Python CLI
against the live local RPC, and executes the Python quickstart before the
developer inventory can mark additional language SDKs as implemented.
