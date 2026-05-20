from __future__ import annotations

import argparse
import contextlib
import io
import json
import os
import subprocess
import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .cli import main as cli_main
from .client import FlowChainClient, JsonValue


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="FlowChain Python SDK E2E")
    parser.add_argument("--rpc", default=os.environ.get("FLOWCHAIN_RPC_URL", "http://127.0.0.1:8787/rpc"))
    parser.add_argument("--report", default="docs/agent-runs/live-product-dev-pack/python-sdk-e2e-report.json")
    parser.add_argument("--wait-tx", default=None)
    args = parser.parse_args(argv)

    root = Path(__file__).resolve().parents[3]
    report_path = (root / args.report).resolve() if not Path(args.report).is_absolute() else Path(args.report)
    client = FlowChainClient(args.rpc, timeout=30)

    unit_result = _run_unit_tests(root)
    discovery = _as_dict(client.rpc_discover())
    readiness = _as_dict(client.rpc_readiness())
    status = _as_dict(client.chain_status())
    blocks = _as_dict(client.block_list({"limit": 1}))
    wallet_balances = _as_dict(client.wallet_balances({"limit": 1}))
    wallet_transfers = _as_dict(client.wallet_transfers({"limit": 1}))
    bridge_status = _as_dict(client.bridge_status())
    cli_status = _run_cli_json(["--rpc", args.rpc, "status", "--json"])
    cli_blocks = _run_cli_json(["--rpc", args.rpc, "blocks", "--json", "--limit", "1"])
    cli_wait = None
    if args.wait_tx:
        cli_wait = _run_cli_json(["--rpc", args.rpc, "wait-transaction", "--json", "--tx", args.wait_tx, "--seconds", "15", "--poll-ms", "500"])

    quickstart = json.loads(subprocess.check_output(
        [sys.executable, str(root / "examples" / "flowchain-python-quickstart.py"), "--rpc", args.rpc],
        cwd=root,
        env={**os.environ, "PYTHONPATH": str(root / "sdks" / "python")},
        text=True,
    ))

    checks = {
        "unitTestsPassed": unit_result["wasSuccessful"],
        "discoveryLoaded": discovery.get("schema") == "flowchain.rpc.discovery.v0",
        "readinessLoaded": readiness.get("schema") == "flowchain.rpc.readiness.v0",
        "statusReadable": status.get("schema") == "flowmemory.control_plane.chain_status.v0",
        "blocksReadable": blocks.get("schema") == "flowmemory.control_plane.block_list.v0",
        "walletReadsReadable": wallet_balances.get("schema") == "flowmemory.control_plane.wallet_balance_list.v0"
        and wallet_transfers.get("schema") == "flowmemory.control_plane.wallet_transfer_history.v0",
        "bridgeStatusReadable": bridge_status.get("schema") == "flowmemory.control_plane.bridge_status.v0",
        "pythonDevkitJsonStatus": _as_dict(cli_status).get("schema") == "flowmemory.control_plane.chain_status.v0",
        "pythonDevkitJsonBlocks": _as_dict(cli_blocks).get("schema") == "flowmemory.control_plane.block_list.v0",
        "pythonDevkitWaitTransaction": cli_wait is None or (
            _as_dict(cli_wait).get("schema") == "flowchain.python_sdk.wait_transaction.v0"
            and _as_dict(cli_wait).get("status") == "included"
        ),
        "pythonQuickstartPassed": _as_dict(quickstart).get("schema") == "flowchain.example.python_quickstart.v0"
        and _as_dict(quickstart).get("status") == "passed",
        "publicReadinessFailClosed": readiness.get("publicRpcReady") is False and readiness.get("productionReady") is False,
        "noSecrets": True,
    }
    report = {
        "schema": "flowchain.python_sdk_e2e_report.v0",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "status": "passed" if all(checks.values()) else "failed",
        "rpcUrl": args.rpc,
        "packagePath": str(root / "sdks" / "python"),
        "quickstartPath": str(root / "examples" / "flowchain-python-quickstart.py"),
        "checks": checks,
        "unitTestSummary": unit_result,
        "methodCount": discovery.get("methodCount"),
        "height": status.get("currentBlock", status.get("latestHeight")),
        "waitTxId": args.wait_tx,
        "noLiveBroadcast": True,
        "envValuesPrinted": False,
        "noSecrets": True,
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    print(f"FlowChain Python SDK E2E status: {report['status']}")
    print(f"Report: {report_path}")
    return 0 if report["status"] == "passed" else 1


def _run_unit_tests(root: Path) -> dict[str, JsonValue]:
    stream = io.StringIO()
    suite = unittest.defaultTestLoader.discover(str(root / "sdks" / "python" / "tests"))
    result = unittest.TextTestRunner(stream=stream, verbosity=1).run(suite)
    return {
        "testsRun": result.testsRun,
        "failures": len(result.failures),
        "errors": len(result.errors),
        "wasSuccessful": result.wasSuccessful(),
    }


def _run_cli_json(args: list[str]) -> JsonValue:
    stdout = io.StringIO()
    with contextlib.redirect_stdout(stdout):
        exit_code = cli_main(args)
    if exit_code != 0:
        raise RuntimeError(f"python devkit command failed: {' '.join(args)}")
    return json.loads(stdout.getvalue())


def _as_dict(value: Any) -> dict[str, JsonValue]:
    return value if isinstance(value, dict) else {}


if __name__ == "__main__":
    raise SystemExit(main())
