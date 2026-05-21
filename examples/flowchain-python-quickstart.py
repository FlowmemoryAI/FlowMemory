from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PYTHON_SDK = ROOT / "sdks" / "python"
if str(PYTHON_SDK) not in sys.path:
    sys.path.insert(0, str(PYTHON_SDK))

from flowchain import FlowChainClient  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description="FlowChain Python quickstart")
    parser.add_argument("--rpc", default=os.environ.get("FLOWCHAIN_RPC_URL", "http://127.0.0.1:8787/rpc"))
    parser.add_argument("--send", action="store_true", help="Submit a local private wallet transfer.")
    args = parser.parse_args()

    client = FlowChainClient(args.rpc, timeout=30)
    readiness = client.rpc_readiness()
    status = client.chain_status()
    blocks = client.block_list({"limit": 1})
    wallet_balances = client.wallet_balances({"limit": 25})
    transfer = None
    if args.send:
        sender, recipient = _send_candidates(wallet_balances)
        transfer = client.wallet_send(
            sender,
            recipient,
            "1",
            memo=f"flowchain-python-quickstart-{int(time.time())}",
            apply_block=True,
            create_recipient=True,
        )

    result = {
        "schema": "flowchain.example.python_quickstart.v0",
        "status": "passed",
        "rpcUrl": args.rpc,
        "productionReady": bool(_get(readiness, "productionReady", False)),
        "publicRpcReady": bool(_get(readiness, "publicRpcReady", False)),
        "height": _get(status, "currentBlock", _get(status, "latestHeight", None)),
        "blockCount": len(_get(blocks, "blocks", [])),
        "walletBalanceCount": len(_get(wallet_balances, "balances", [])),
        "submittedTransfer": transfer is not None,
        "transferId": _get(transfer, "transferId", None) if transfer else None,
        "noLiveBroadcast": True,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


def _get(value: Any, key: str, default: Any = None) -> Any:
    return value.get(key, default) if isinstance(value, dict) else default


def _send_candidates(wallet_balances: Any) -> tuple[str, str]:
    rows = _get(wallet_balances, "balances", [])
    accounts: list[tuple[str, int]] = []
    for row in rows if isinstance(rows, list) else []:
        if not isinstance(row, dict):
            continue
        nested = row.get("balance") if isinstance(row.get("balance"), dict) else {}
        source = row.get("source")
        status = row.get("status")
        account_id = nested.get("accountId") or row.get("walletAddress")
        amount = nested.get("units") or row.get("amount") or "0"
        if account_id and (source == "local-runtime-balance" or status == "local_runtime") and str(amount).isdigit():
            accounts.append((str(account_id), int(str(amount))))
    sender = next((account for account, amount in accounts if amount > 1), None)
    recipient = next((account for account, _amount in accounts if account != sender), None)
    if sender is None or recipient is None:
        raise RuntimeError("could not find two local wallet accounts with a spendable balance")
    return sender, recipient


if __name__ == "__main__":
    raise SystemExit(main())
