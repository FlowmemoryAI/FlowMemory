from __future__ import annotations

import contextlib
import io
import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from flowchain import FlowChainClient, FlowChainRpcError, redact_flowchain_text
from flowchain.cli import main as cli_main


class _RpcHandler(BaseHTTPRequestHandler):
    server: "_RpcServer"

    def do_POST(self) -> None:
        length = int(self.headers.get("content-length", "0"))
        body = json.loads(self.rfile.read(length).decode("utf-8"))
        self.server.requests.append({"path": self.path, "body": body})
        response = self.server.responses.pop(0)
        if callable(response):
            response = response(body, self.path)
        status = response.get("status", 200)
        payload = response.get("body", {})
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, _format: str, *_args: Any) -> None:
        return


class _RpcServer(ThreadingHTTPServer):
    requests: list[dict[str, Any]]
    responses: list[Any]


@contextlib.contextmanager
def rpc_server(*responses: Any):
    server = _RpcServer(("127.0.0.1", 0), _RpcHandler)
    server.requests = []
    server.responses = list(responses)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield server, f"http://127.0.0.1:{server.server_port}/rpc"
    finally:
        server.shutdown()
        server.server_close()


class FlowChainClientTests(unittest.TestCase):
    def test_json_rpc_envelope_shape(self) -> None:
        with rpc_server({"body": {"jsonrpc": "2.0", "id": "ok", "result": {"schema": "ok"}}}) as (server, url):
            result = FlowChainClient(url).call("health", {})
        self.assertEqual(result, {"schema": "ok"})
        self.assertEqual(server.requests[0]["path"], "/rpc")
        self.assertEqual(
            server.requests[0]["body"],
            {
                "jsonrpc": "2.0",
                "id": "flowchain-python-sdk:health",
                "method": "health",
                "params": {},
            },
        )

    def test_json_rpc_errors_are_tagged(self) -> None:
        with rpc_server({"body": {"jsonrpc": "2.0", "id": "fail", "error": {"code": -32601, "message": "method.not_found"}}}) as (_server, url):
            with self.assertRaises(FlowChainRpcError) as raised:
                FlowChainClient(url).call("missing")
        self.assertEqual(raised.exception.code, -32601)
        self.assertEqual(str(raised.exception), "method.not_found")

    def test_wallet_send_uses_control_plane_path(self) -> None:
        with rpc_server({"body": {"schema": "flowmemory.control_plane.wallet_send_result.v0"}}) as (server, url):
            result = FlowChainClient(url).wallet_send("local-account:a", "local-account:b", "1", apply_block=True)
        self.assertEqual(result["schema"], "flowmemory.control_plane.wallet_send_result.v0")
        self.assertEqual(server.requests[0]["path"], "/wallets/send")
        self.assertEqual(server.requests[0]["body"]["fromAccountId"], "local-account:a")
        self.assertEqual(server.requests[0]["body"]["applyBlock"], True)

    def test_wait_for_transaction_retries_not_found(self) -> None:
        with rpc_server(
            {"body": {"jsonrpc": "2.0", "id": "wait", "error": {"code": -32004, "message": "not found"}}},
            {"body": {"jsonrpc": "2.0", "id": "wait", "result": {"schema": "flowmemory.control_plane.transaction_detail.v0"}}},
        ) as (server, url):
            result = FlowChainClient(url).wait_for_transaction(tx_id="tx:test", timeout=1, poll=0.01)
        self.assertEqual(result["schema"], "flowchain.python_sdk.wait_transaction.v0")
        self.assertEqual(result["status"], "included")
        self.assertEqual(result["attempts"], 2)
        self.assertEqual([request["body"]["method"] for request in server.requests], ["transaction_get", "transaction_get"])

    def test_cli_status_prints_json(self) -> None:
        with rpc_server({"body": {"jsonrpc": "2.0", "id": "ok", "result": {"schema": "flowmemory.control_plane.chain_status.v0"}}}) as (_server, url):
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                exit_code = cli_main(["--rpc", url, "status", "--json"])
        self.assertEqual(exit_code, 0)
        self.assertEqual(json.loads(stdout.getvalue())["schema"], "flowmemory.control_plane.chain_status.v0")

    def test_redacts_secret_shaped_diagnostics(self) -> None:
        text = redact_flowchain_text("private_key=abc123 bearer:token-value HTTPS://example.invalid/path?api_key=value public=ok")
        self.assertNotIn("abc123", text)
        self.assertNotIn("token-value", text)
        self.assertNotIn("api_key=value", text)
        self.assertIn("public=ok", text)


if __name__ == "__main__":
    unittest.main()
