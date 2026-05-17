# FlowChain Public RPC Abuse Test

Generated: 2026-05-17T18:48:14.2284618Z
Status: passed
Abuse test ready: True

This local harness starts a temporary private control-plane server and records public RPC abuse behavior without owner endpoint values.

## Cases

| Requirement | Status | Evidence |
| --- | --- | --- |
| Allowed browser origin can read health with a non-wildcard CORS echo. | passed | status=200, corsEchoMatchesConfiguredOrigin=True |
| Disallowed browser origin is rejected before public RPC handling. | passed | status=403, corsHeaderPresent=False |
| Allowed CORS preflight is handled without dispatching JSON-RPC. | passed | status=204, corsEchoMatchesConfiguredOrigin=True |
| Non-JSON POST bodies are rejected with HTTP 415 before JSON parsing. | passed | status=415, reason=request.unsupported_media_type |
| Malformed JSON returns the stable JSON-RPC parse error envelope. | passed | status=400, errorCode=-32700, reason=parse.error |
| Unsupported public methods fail closed as JSON-RPC method-not-found errors. | passed | status=200, errorCode=-32601, reason=method.not_found |
| Public RPC rejects transaction_submit before local file-intake dispatch. | passed | status=200, errorCode=-32601, reason=method.not_found |
| Public RPC rejects bridge_observation_submit before local bridge observation intake dispatch. | passed | status=200, errorCode=-32601, reason=method.not_found |
| Public RPC rejects raw_json_get before raw fixture payloads can be returned. | passed | status=200, errorCode=-32601, reason=method.not_found |
| Public HTTP bridge observation POST alias is rejected instead of wrapping into bridge_observation_submit. | passed | status=200, errorCode=-32601, reason=method.not_found |
| Authenticated tester write gateway fails closed when owner token env is not configured. | passed | status=403, schema=flowmemory.control_plane.tester_write_disabled.v0 |
| Invalid method params return the stable JSON-RPC invalid-params error. | passed | status=200, errorCode=-32602, reason=params.invalid |
| Empty JSON-RPC batches are rejected before dispatch. | passed | status=400, reason=request.batch_empty |
| JSON-RPC batches above the local cap are rejected before dispatch. | passed | status=413, reason=request.batch_too_large, maxBatchRequests=50 |
| Request bodies above the local payload cap are rejected with HTTP 413. | passed | status=413, schema=flowmemory.control_plane.payload_too_large.v0, reason=request.payload_too_large |
| JSON-RPC notifications do not leak data and return HTTP 204. | passed | status=204, bodyEmpty=True |
| Per-client rate limiting returns HTTP 429 with Retry-After and no secret material. | passed | first=200, second=200, third=429, retryAfterPresent=True |
| Abuse-test response summaries do not contain raw env values or secret-shaped material. | passed | findings=0 |
