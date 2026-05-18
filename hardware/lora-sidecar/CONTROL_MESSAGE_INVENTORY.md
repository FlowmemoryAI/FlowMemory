# Meshtastic/LoRa Control Message Inventory

Last updated: 2026-05-14

This inventory addresses issue #12. It defines candidate control messages for FlowRouter v0 and explicitly rules out high-bandwidth payloads.

## Message Envelope

Every candidate should fit in a small binary or compact text payload. Target payloads should stay well below practical Meshtastic limits and should be designed around compact fields rather than JSON verbosity.

Common fields:

| Field | Shape | Purpose |
| --- | --- | --- |
| `v` | uint8 | Schema version. |
| `type` | enum/uint8 | Message type. |
| `node` | short node id or hash prefix | Sender identity hint; not sufficient authentication. |
| `seq` | uint32/uint64 | Replay detection and ordering. |
| `ts` | compact timestamp or monotonic tick | Freshness hint when clocks exist. |
| `flags` | bitset | Low-battery, local-only, degraded, test mode. |
| `auth` | truncated MAC/signature field | Required before state-changing use; exact scheme unresolved. |

## Candidate Messages

| Message | Purpose group | Approximate payload shape | Why it fits low bandwidth | Risks and requirements |
| --- | --- | --- | --- | --- |
| Node heartbeat | Status ping | `v,type,node,seq,uptime,bat/temp,flags,auth` | Tiny status tuple; no artifact data. | Spoofing and replay risk; needs auth and sequence tracking. |
| Node health digest | Status ping | `v,type,node,seq,health,queue,temp,free,health_hash,auth` | Compact health and queue fields only; no logs or receipts. | Advisory only; must not block local chain startup. |
| Gateway availability | Status ping | `v,type,node,seq,wan,lan,cache,sidecar,flags,auth` | Bitfields describe availability instead of carrying logs. | Overclaiming connectivity; receiver must treat as advisory. |
| Peer hint | Topology hint | `v,type,node,seq,peer,role,link,rssi,snr,auth` | Short peer and link-state hint only; no sync payload. | Spoofing/replay risk; normal network path performs actual sync and reconciliation. |
| FlowPulse digest | Compact digest | `v,type,node,seq,chain,from,to,digest32,count,flags,auth` | Sends a hash over a FlowPulse range, not events. | Digest cannot be trusted until verified by indexer/receipts. |
| Artifact availability digest | Compact digest | `v,type,node,seq,namespace,digest32,count,bytes_class,ttl,auth` | Announces cache hints only; no artifacts. | May leak inventory metadata; needs privacy review. |
| Compact receipt reference | Compact receipt reference | `v,type,node,seq,chain,block_hint,tx_hash_prefix/log_hint,receipt_hash,auth` | Carries short pointer and hash, not receipt body. | Prefix collisions and stale hints; full verification requires normal network path. |
| Bridge alert digest | Compact bridge alert | `v,type,node,seq,bridge,src,dst,code,digest32,block_hint,auth` | Sends a bridge-observer alert code and digest, not bridge payloads or settlement state. | Advisory only; must not block local chain progress or imply production bridge readiness. |
| Field diagnostic | Field diagnostic | `v,type,node,seq,temp,power_class,rssi,snr,loss,flags,auth` | Numeric summary only. | Sensor accuracy, spoofing, and replay risk. |
| Emergency/local signal | Emergency signal | `v,type,node,seq,code,priority,ttl,location_hint?,auth` | Short code and optional coarse hint. | Abuse risk; no public emergency-service claim. |
| Operator command warning | Operator command | `v,type,node,seq,command_id,intent,ttl,auth` | Intent marker only; no scripts or payloads. | Must not execute privileged action in v0; needs strong auth, authorization, replay protection, and audit before any future action. |

## Message Type Notes

### Node Heartbeat

Use for "this node is alive" and coarse device state. Keep it periodic but infrequent to avoid channel congestion.

### Node Health Digest

Use for compact local health and queue-depth hints. A warning or stale node-health message can inform an operator, but V0 hardware health never gates private/local chain startup.

### Gateway Availability

Use for advisory state about upstream internet, LAN reachability, local cache, and sidecar status. It does not prove connectivity to the global internet.

### Peer Hint

Use for local topology hints such as "this peer was heard recently." It is not authentication, sync proof, or a replacement for normal network discovery.

### FlowPulse Digest

Use only as a compact checkpoint over a known event range. It should never carry event bodies, logs, memory artifacts, or model data.

### Artifact Availability Digest

Use to say "this cache may have content matching this digest or namespace." It must not expose sensitive labels or bulk metadata.

### Compact Receipt Reference

Use as a breadcrumb for later reconciliation. It can include a chain id, block hint, short transaction/log hint, and receipt hash. It is not final proof by itself.

### Bridge Alert Digest

Use as a compact local operator warning when a bridge observer reports lag, mismatch, or stale relay state. It is a review hint only; the local private chain keeps running and normal bridge observer workflows must reconcile the digest.

### Field Diagnostic

Use for temperature, power class, RSSI/SNR, message loss, and degraded-state flags. It helps correlate field notes after the test.

### Emergency/Local Signal

Use for local operator attention in degraded connectivity. It is not a public safety system and should not claim emergency-service reliability.

### Operator Command Warning

Use only to warn or mark intent. V0 must not execute remote commands over LoRa. Future state-changing commands require a separate threat model.

## Authentication And Replay Needs

V0 must assume LoRa control channels are adversarial:

- Node IDs can be spoofed.
- Packets can be replayed.
- Messages can be lost, delayed, duplicated, or reordered.
- Channel keys can leak.
- Routing metadata remains visible even when payloads are encrypted.

Before state-changing use, every message needs:

- Message authentication bound to device identity.
- Sequence, nonce, or receipt-based replay protection.
- Expiration/freshness policy that handles offline operation.
- Domain separation by network, test, channel, and message type.
- Audit log on the receiving node.
- Operator-visible warning when auth fails or freshness is uncertain.

## Retry And Loss Policy

- Heartbeats can be lossy.
- Availability messages can be repeated at low frequency.
- Digests and receipt references may be resent with the same sequence until acknowledged by a normal network path.
- Emergency/local signals may repeat with TTL and priority limits.
- Operator command warnings must not be retried into execution semantics.

## Explicit Non-Goals

- No high-bandwidth payloads.
- No artifact transfer.
- No AI memory transfer.
- No app traffic.
- No ISP replacement.
- No production mesh deployment.
- No firmware implementation in this issue.
- No app UI implementation in this issue.
