from __future__ import annotations

import json
import os
import re
import time
import urllib.error
import urllib.request
from typing import Any
from urllib.parse import urlsplit, urlunsplit

JsonValue = Any

DEFAULT_RPC_URL = "http://127.0.0.1:8787/rpc"

_SECRET_PATTERNS = [
    re.compile(
        r"\b(private[_ -]?key|seed[_ -]?phrase|mnemonic|api[_ -]?key|webhook|bearer|auth[_ -]?token|"
        r"access[_ -]?token|refresh[_ -]?token|password|passphrase|vault[_ -]?ciphertext)\b\s*[:=]\s*[\"']?[^\"'\s,}]+",
        re.IGNORECASE,
    ),
    re.compile(r"\bhttps?://[^\s\"'<>]*?(?:apikey|api_key|token|secret|key)=[^\s\"'<>]+", re.IGNORECASE),
]


def redact_flowchain_text(value: object) -> str:
    text = value if isinstance(value, str) else repr(value)
    for pattern in _SECRET_PATTERNS:
        text = pattern.sub(_redact_secret_match, text)
    return text


def _redact_secret_match(match: re.Match[str]) -> str:
    text = match.group(0)
    if text.lower().startswith("http"):
        return "[REDACTED_URL_WITH_SECRET_QUERY]"
    key = match.group(1) if match.lastindex else "secret"
    return f"{key}=[REDACTED]"


class FlowChainRpcError(Exception):
    def __init__(self, message: str, code: int, data: JsonValue | None = None):
        super().__init__(redact_flowchain_text(message))
        self.code = code
        self.data = data


class FlowChainClient:
    def __init__(self, rpc_url: str | None = None, timeout: float = 10.0):
        self.rpc_url = rpc_url or os.environ.get("FLOWCHAIN_RPC_URL", DEFAULT_RPC_URL)
        self.timeout = timeout

    def _post_json(self, url: str, payload: JsonValue) -> JsonValue:
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        request = urllib.request.Request(
            url,
            data=body,
            headers={"content-type": "application/json", "accept": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                text = response.read().decode("utf-8")
        except urllib.error.HTTPError as error:
            text = error.read().decode("utf-8", errors="replace")
            parsed = _json_or_none(text)
            raise FlowChainRpcError(f"FlowChain HTTP {error.code}: {text}", error.code, parsed) from error
        except urllib.error.URLError as error:
            raise FlowChainRpcError(f"FlowChain RPC unreachable: {error.reason}", -32000) from error
        except TimeoutError as error:
            raise FlowChainRpcError(f"FlowChain RPC timed out after {self.timeout}s", -32001) from error

        parsed = _json_or_none(text)
        if parsed is None:
            raise FlowChainRpcError(f"FlowChain RPC returned non-JSON response: {text}", -32700)
        return parsed

    def call(self, method: str, params: JsonValue | None = None) -> JsonValue:
        payload = {
            "jsonrpc": "2.0",
            "id": f"flowchain-python-sdk:{method}",
            "method": method,
            "params": {} if params is None else params,
        }
        response = self._post_json(self.rpc_url, payload)
        if isinstance(response, dict) and "error" in response:
            error = response.get("error") or {}
            code = int(error.get("code", -32603)) if isinstance(error, dict) else -32603
            message = str(error.get("message", "FlowChain RPC error")) if isinstance(error, dict) else str(error)
            data = error.get("data") if isinstance(error, dict) else None
            raise FlowChainRpcError(message, code, data)
        if not isinstance(response, dict) or "result" not in response:
            raise FlowChainRpcError(f"FlowChain RPC {method} returned no result", -32603)
        return response["result"]

    def post_control_plane(self, path: str, payload: JsonValue) -> JsonValue:
        return self._post_json(_control_plane_url(self.rpc_url, path), payload)

    def rpc_discover(self) -> JsonValue:
        return self.call("rpc_discover")

    def rpc_readiness(self) -> JsonValue:
        return self.call("rpc_readiness")

    def health(self) -> JsonValue:
        return self.call("health")

    def node_status(self) -> JsonValue:
        return self.call("node_status")

    def chain_status(self) -> JsonValue:
        return self.call("chain_status")

    def block_list(self, params: JsonValue | None = None) -> JsonValue:
        return self.call("block_list", params or {"limit": 10})

    def block_get(self, params: JsonValue) -> JsonValue:
        return self.call("block_get", params)

    def transaction_list(self, params: JsonValue | None = None) -> JsonValue:
        return self.call("transaction_list", params or {"limit": 10})

    def transaction_get(self, params: JsonValue) -> JsonValue:
        return self.call("transaction_get", params)

    def mempool_list(self, params: JsonValue | None = None) -> JsonValue:
        return self.call("mempool_list", params or {"limit": 10})

    def account_list(self, params: JsonValue | None = None) -> JsonValue:
        return self.call("account_list", params or {"limit": 10})

    def balance_get(self, params: JsonValue) -> JsonValue:
        return self.call("balance_get", params)

    def wallet_metadata_list(self, params: JsonValue | None = None) -> JsonValue:
        return self.call("wallet_metadata_list", params or {"limit": 10})

    def wallet_balances(self, params: JsonValue | None = None) -> JsonValue:
        return self.call("wallet_balance_list", params or {"limit": 10})

    def wallet_transfers(self, params: JsonValue | None = None) -> JsonValue:
        return self.call("wallet_transfer_history", params or {"limit": 10})

    def faucet_event_list(self, params: JsonValue | None = None) -> JsonValue:
        return self.call("faucet_event_list", params or {"limit": 10})

    def finality_list(self, params: JsonValue | None = None) -> JsonValue:
        return self.call("finality_list", params or {"limit": 10})

    def bridge_status(self) -> JsonValue:
        return self.call("bridge_status")

    def bridge_readiness(self) -> JsonValue:
        return self.call("bridge_live_readiness")

    def bridge_deposit_list(self, params: JsonValue | None = None) -> JsonValue:
        return self.call("bridge_deposit_list", params or {"limit": 10})

    def bridge_credit_list(self, params: JsonValue | None = None) -> JsonValue:
        return self.call("bridge_credit_list", params or {"limit": 10})

    def withdrawal_list(self, params: JsonValue | None = None) -> JsonValue:
        return self.call("withdrawal_list", params or {"limit": 10})

    def wallet_send(
        self,
        from_account_id: str,
        to_account_id: str,
        amount_units: str | int,
        memo: str | None = None,
        apply_block: bool = False,
        create_recipient: bool = False,
    ) -> JsonValue:
        payload: dict[str, JsonValue] = {
            "fromAccountId": from_account_id,
            "toAccountId": to_account_id,
            "amountUnits": str(amount_units),
            "applyBlock": apply_block,
            "createRecipient": create_recipient,
        }
        if memo:
            payload["memo"] = memo
        return self.post_control_plane("/wallets/send", payload)

    def submit_signed_transaction(self, payload: JsonValue) -> JsonValue:
        return self.post_control_plane("/transactions/submit", payload)

    def submit_signed_envelope(self, signed_envelope: JsonValue, **options: JsonValue) -> JsonValue:
        payload = dict(options)
        payload["signedEnvelope"] = signed_envelope
        return self.submit_signed_transaction(payload)

    def wait_for_transaction(
        self,
        tx_id: str | None = None,
        tx_hash: str | None = None,
        transaction_id: str | None = None,
        timeout: float = 30.0,
        poll: float = 1.0,
    ) -> JsonValue:
        key = tx_hash or tx_id or transaction_id
        if not key:
            raise FlowChainRpcError("wait_for_transaction requires tx_id, tx_hash, or transaction_id", -32602)
        params = {"txHash": key} if tx_hash or str(key).startswith("0x") else {"txId": key}
        started = time.monotonic()
        attempts = 0
        last_error: FlowChainRpcError | None = None
        while time.monotonic() - started <= timeout:
            attempts += 1
            try:
                transaction = self.transaction_get(params)
                return {
                    "schema": "flowchain.python_sdk.wait_transaction.v0",
                    "status": "included",
                    "txId": tx_id if "txId" in params else None,
                    "txHash": tx_hash if "txHash" in params else None,
                    "attempts": attempts,
                    "elapsedMs": int((time.monotonic() - started) * 1000),
                    "transaction": transaction,
                }
            except FlowChainRpcError as error:
                if error.code != -32004:
                    raise
                last_error = error
            remaining = timeout - (time.monotonic() - started)
            if remaining <= 0:
                break
            time.sleep(min(max(poll, 0.1), remaining))
        return {
            "schema": "flowchain.python_sdk.wait_transaction.v0",
            "status": "timeout",
            "txId": tx_id,
            "txHash": tx_hash,
            "attempts": attempts,
            "elapsedMs": int((time.monotonic() - started) * 1000),
            "transaction": None,
            "lastError": None if last_error is None else {"code": last_error.code, "message": str(last_error)},
        }


def _json_or_none(text: str) -> JsonValue | None:
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


def _control_plane_url(rpc_url: str, path: str) -> str:
    parts = urlsplit(rpc_url)
    normalized = path if path.startswith("/") else f"/{path}"
    return urlunsplit((parts.scheme, parts.netloc, normalized, "", ""))
