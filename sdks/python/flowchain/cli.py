from __future__ import annotations

import argparse
import json
import sys
from typing import Any, Callable

from .client import FlowChainClient, FlowChainRpcError


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    client = FlowChainClient(args.rpc, args.timeout)
    try:
        result = args.handler(client, args)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except FlowChainRpcError as error:
        payload = {
            "schema": "flowchain.python_sdk.error.v0",
            "code": error.code,
            "message": str(error),
            "data": error.data,
        }
        print(json.dumps(payload, indent=2, sort_keys=True), file=sys.stderr)
        return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="flowchain", description="FlowChain Python SDK CLI")
    parser.add_argument("--rpc", default=None, help="FlowChain RPC URL. Defaults to FLOWCHAIN_RPC_URL or localhost.")
    parser.add_argument("--timeout", type=float, default=10.0, help="Request timeout in seconds.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    _add_command(subparsers, "discover", lambda client, _args: client.rpc_discover())
    _add_command(subparsers, "readiness", lambda client, _args: client.rpc_readiness())
    _add_command(subparsers, "health", lambda client, _args: client.health())
    _add_command(subparsers, "status", lambda client, _args: client.chain_status())
    _add_command(subparsers, "node-status", lambda client, _args: client.node_status())
    _add_limited_command(subparsers, "blocks", lambda client, args: client.block_list({"limit": args.limit}))
    _add_limited_command(subparsers, "transactions", lambda client, args: client.transaction_list({"limit": args.limit}))
    _add_limited_command(subparsers, "accounts", lambda client, args: client.account_list({"limit": args.limit}))
    _add_limited_command(subparsers, "mempool", lambda client, args: client.mempool_list({"limit": args.limit}))
    _add_limited_command(subparsers, "wallet-metadata", lambda client, args: client.wallet_metadata_list({"limit": args.limit}))
    _add_limited_command(subparsers, "wallet-balances", lambda client, args: client.wallet_balances({"limit": args.limit}))
    _add_limited_command(subparsers, "wallet-transfers", lambda client, args: client.wallet_transfers({"limit": args.limit}))
    _add_limited_command(subparsers, "faucet-events", lambda client, args: client.faucet_event_list({"limit": args.limit}))
    _add_limited_command(subparsers, "finality", lambda client, args: client.finality_list({"limit": args.limit}))
    _add_command(subparsers, "bridge-readiness", lambda client, _args: client.bridge_readiness())
    _add_command(subparsers, "bridge-status", lambda client, _args: client.bridge_status())
    _add_limited_command(subparsers, "bridge-deposits", lambda client, args: client.bridge_deposit_list({"limit": args.limit}))
    _add_limited_command(subparsers, "bridge-credits", lambda client, args: client.bridge_credit_list({"limit": args.limit}))
    _add_limited_command(subparsers, "withdrawals", lambda client, args: client.withdrawal_list({"limit": args.limit}))

    wait = subparsers.add_parser("wait-transaction")
    _add_json_flag(wait)
    wait.add_argument("--tx", required=True, help="Transaction id or hash to poll.")
    wait.add_argument("--seconds", type=float, default=30.0)
    wait.add_argument("--poll-ms", type=int, default=1000)
    wait.set_defaults(handler=lambda client, args: client.wait_for_transaction(
        tx_hash=args.tx if args.tx.startswith("0x") else None,
        tx_id=None if args.tx.startswith("0x") else args.tx,
        timeout=args.seconds,
        poll=args.poll_ms / 1000,
    ))

    send = subparsers.add_parser("wallet-send")
    _add_json_flag(send)
    send.add_argument("--from", dest="from_account_id", required=True)
    send.add_argument("--to", dest="to_account_id", required=True)
    send.add_argument("--amount-units", required=True)
    send.add_argument("--memo", default=None)
    send.add_argument("--apply-block", action="store_true")
    send.add_argument("--create-recipient", action="store_true")
    send.set_defaults(handler=lambda client, args: client.wallet_send(
        from_account_id=args.from_account_id,
        to_account_id=args.to_account_id,
        amount_units=args.amount_units,
        memo=args.memo,
        apply_block=args.apply_block,
        create_recipient=args.create_recipient,
    ))

    call = subparsers.add_parser("call")
    _add_json_flag(call)
    call.add_argument("method")
    call.add_argument("--params", default="{}", help="JSON object or array params.")
    call.set_defaults(handler=lambda client, args: client.call(args.method, json.loads(args.params)))
    return parser


def _add_command(subparsers: argparse._SubParsersAction[argparse.ArgumentParser], name: str, handler: Callable[[FlowChainClient, Any], Any]) -> None:
    parser = subparsers.add_parser(name)
    _add_json_flag(parser)
    parser.set_defaults(handler=handler)


def _add_limited_command(subparsers: argparse._SubParsersAction[argparse.ArgumentParser], name: str, handler: Callable[[FlowChainClient, Any], Any]) -> None:
    parser = subparsers.add_parser(name)
    _add_json_flag(parser)
    parser.add_argument("--limit", type=int, default=10)
    parser.set_defaults(handler=handler)


def _add_json_flag(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--json", action="store_true", help="Emit JSON. Included for parity with the Node devkit; output is always JSON.")


if __name__ == "__main__":
    raise SystemExit(main())
