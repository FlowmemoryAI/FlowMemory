# FlowChain Python SDK

This is a dependency-free Python client and CLI for the FlowChain local RPC and
private control-plane routes.

```powershell
$env:PYTHONPATH = "sdks/python"
python -m flowchain.cli status --json
python -m flowchain.cli blocks --json --limit 5
python examples/flowchain-python-quickstart.py
```

The default RPC URL is `http://127.0.0.1:8787/rpc`. Public RPC and live bridge
write access stay blocked until owner inputs and production gates pass.
