#!/usr/bin/env python3
"""Deterministic FlowRouter V0 POC packet generator and validator."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


DEFAULT_SEED = 42
SCHEMA_FILES = {
    "device_manifest": "device_manifest.schema.json",
    "heartbeat": "heartbeat.schema.json",
    "flowpulse_digest_relay": "flowpulse_digest_relay.schema.json",
    "verifier_report_digest_relay": "verifier_report_digest_relay.schema.json",
    "compact_receipt_relay": "compact_receipt_relay.schema.json",
    "local_cache_status": "local_cache_status.schema.json",
    "gateway_discovery": "gateway_discovery.schema.json",
    "sidecar_status": "sidecar_status.schema.json",
    "nfc_memory_cartridge_metadata": "nfc_memory_cartridge_metadata.schema.json",
    "emergency_offline_signal": "emergency_offline_signal.schema.json",
    "bridge_alert": "bridge_alert.schema.json",
    "node_health": "node_health.schema.json",
    "peer_hint": "peer_hint.schema.json",
    "dashboard_feed": "dashboard_feed.schema.json",
}

OPERATOR_SIGNALS_SCHEMA_FILE = "flowchain_operator_signals.schema.json"
NEGATIVE_REPORT_SCHEMA_FILE = "negative_validation_report.schema.json"
ZERO_HASH = "0x0000000000000000000000000000000000000000000000000000000000000000"
HARDWARE_ROOTFIELD_ID = "rootfield:hardware:flowrouter-local-alpha"
HARDWARE_CHAIN_CONTEXT = "flowchain-private-local-testnet"
FIXTURE_TIME_PREFIX = "2026-05-13T17:"
SECRET_SHAPED_PATTERNS = [
    "BEGIN PRIVATE " + "KEY",
    "PRIVATE_" + "KEY=",
    "MNEMONIC=",
    "SEED_PHRASE=",
    "RPC_URL=",
    "API_KEY=",
    "WEBHOOK_URL=",
    "sk_live_",
    "sk-proj-",
    "https://hooks.slack.com/services/",
]
ID_PATTERNS = {
    "device_id": re.compile(r"^fr-[0-9a-f]{12}$"),
    "gateway_id": re.compile(r"^gw-[0-9a-f]{12}$"),
    "cartridge_id": re.compile(r"^cart-[0-9a-f]{12}$"),
    "peer_id": re.compile(r"^peer-[0-9a-f]{12}$"),
    "report_id": re.compile(r"^vr-[0-9a-f]{12}$"),
    "bridge_id": re.compile(r"^bridge-[0-9a-f]{12}$"),
    "cache_id": re.compile(r"^cache-[0-9a-f]{12}$"),
    "digest64": re.compile(r"^[0-9a-f]{64}$"),
    "tx_hash_prefix": re.compile(r"^0x[0-9a-f]{16}$"),
}


def digest(seed: int, label: str, length: int = 64) -> str:
    return hashlib.sha256(f"flowrouter-v0:{seed}:{label}".encode("utf-8")).hexdigest()[:length]


def short_id(seed: int, label: str) -> str:
    return digest(seed, label, 12)


def ensure_hex(value: str) -> str:
    return value if value.startswith("0x") else f"0x{value}"


def iso_tick(offset_seconds: int) -> str:
    # Fixed clock keeps fixtures deterministic.
    base_hour = 17
    minute = offset_seconds // 60
    second = offset_seconds % 60
    return f"2026-05-13T{base_hour:02d}:{minute:02d}:{second:02d}Z"


def default_raw_fixture_path(seed: int) -> Path:
    return Path(f"hardware/fixtures/flowrouter_sample_seed{seed}.json")


def default_operator_fixture_path(seed: int) -> Path:
    return Path(f"fixtures/hardware/flowrouter_local_alpha_seed{seed}.json")


def default_handoff_fixture_path(seed: int) -> Path:
    return Path(f"fixtures/hardware/flowrouter_control_plane_handoff_seed{seed}.json")


def default_negative_report_path(seed: int) -> Path:
    return Path(f"fixtures/hardware/flowrouter_negative_validation_seed{seed}.json")


def clone_json(value: Any) -> Any:
    return json.loads(json.dumps(value, sort_keys=True))


def build_packets(seed: int) -> dict[str, Any]:
    device_id = f"fr-{short_id(seed, 'device')}"
    gateway_id = f"gw-{short_id(seed, 'gateway')}"
    cartridge_id = f"cart-{short_id(seed, 'cartridge')}"
    receipt_digest = digest(seed, "receipt")
    flowpulse_digest = digest(seed, "flowpulse")
    verifier_digest = digest(seed, "verifier")
    bridge_digest = digest(seed, "bridge-alert")
    cache_digest = digest(seed, "cache")

    manifest = {
        "packet_type": "device_manifest",
        "schema_version": "flowrouter.poc.v0",
        "device_id": device_id,
        "device_role": "flowrouter-dev-kit",
        "generated_at": iso_tick(0),
        "hardware": {
            "router": "OpenWrt One candidate",
            "compute": "Raspberry Pi 5 8GB candidate",
            "storage": "NVMe 256GB cache candidate",
            "sidecar": "Meshtastic USB sidecar candidate",
            "display": "OLED/e-paper status candidate",
            "nfc": "passive NFC cartridge candidate",
            "flowcore": "cobalt light-pipe LED candidate",
        },
        "capabilities": [
            "heartbeat",
            "gateway_discovery",
            "compact_receipt_relay",
            "verifier_report_digest_relay",
            "bridge_alert",
            "operator_metadata",
            "local_cache_status",
            "sidecar_status",
            "node_health",
            "peer_hint",
            "dashboard_feed",
        ],
        "security": {
            "identity_mode": "simulated-key-fingerprint",
            "trust_level": "advisory",
            "state_authority": "local-only-unverified",
        },
    }

    heartbeat = {
        "packet_type": "heartbeat",
        "schema_version": "flowrouter.poc.v0",
        "device_id": device_id,
        "sequence": 1000 + seed,
        "emitted_at": iso_tick(10),
        "uptime_seconds": 86400 + seed,
        "power_state": "mains",
        "network_state": "online",
        "cache_state": "healthy",
        "sidecar_state": "ready",
        "flowcore_state": "online",
        "warnings": [],
    }

    flowpulse_relay = {
        "packet_type": "flowpulse_digest_relay",
        "schema_version": "flowrouter.poc.v0",
        "device_id": device_id,
        "sequence": 1001 + seed,
        "emitted_at": iso_tick(20),
        "chain": "base-sepolia-sim",
        "from_block": 1200000,
        "to_block": 1200024,
        "event_count": 7,
        "digest": flowpulse_digest,
        "payload_bytes_estimate": 112,
        "lora_eligible": True,
        "verification_state": "advisory",
    }

    verifier_report = {
        "packet_type": "verifier_report_digest_relay",
        "schema_version": "flowrouter.poc.v0",
        "device_id": device_id,
        "sequence": 1002 + seed,
        "emitted_at": iso_tick(30),
        "report_id": f"vr-{short_id(seed, 'verifier-report')}",
        "subject_digest": flowpulse_digest,
        "result": "unresolved",
        "report_digest": verifier_digest,
        "payload_bytes_estimate": 128,
        "lora_eligible": True,
    }

    receipt_relay = {
        "packet_type": "compact_receipt_relay",
        "schema_version": "flowrouter.poc.v0",
        "device_id": device_id,
        "sequence": 1003 + seed,
        "emitted_at": iso_tick(40),
        "chain": "base-sepolia-sim",
        "block_hint": 1200012,
        "tx_hash_prefix": f"0x{digest(seed, 'tx', 16)}",
        "log_index_hint": 3,
        "receipt_digest": receipt_digest,
        "payload_bytes_estimate": 96,
        "lora_eligible": True,
        "verification_state": "advisory",
    }

    cache_status = {
        "packet_type": "local_cache_status",
        "schema_version": "flowrouter.poc.v0",
        "device_id": device_id,
        "sequence": 1004 + seed,
        "emitted_at": iso_tick(50),
        "cache_id": f"cache-{short_id(seed, 'cache-id')}",
        "mode": "bounded-local",
        "bytes_used": 7340032,
        "bytes_limit": 268435456,
        "artifact_count": 3,
        "receipt_count": 11,
        "verified_count": 4,
        "unresolved_count": 7,
        "cache_digest": cache_digest,
        "health": "healthy",
    }

    gateway_discovery = {
        "packet_type": "gateway_discovery",
        "schema_version": "flowrouter.poc.v0",
        "device_id": device_id,
        "gateway_id": gateway_id,
        "sequence": 1005 + seed,
        "emitted_at": iso_tick(60),
        "lan_reachable": True,
        "upstream_reachable": True,
        "sidecar_reachable": True,
        "dashboard_hint": "http://flowrouter.local/status",
        "advertised_roles": ["local-dashboard", "cache-status", "digest-relay"],
    }

    sidecar_status = {
        "packet_type": "sidecar_status",
        "schema_version": "flowrouter.poc.v0",
        "device_id": device_id,
        "sequence": 1006 + seed,
        "emitted_at": iso_tick(70),
        "radio": "meshtastic",
        "region": "US",
        "modem_preset": "LongFast",
        "payload_budget_bytes": 160,
        "mqtt_state": "disabled",
        "tx_enabled": True,
        "rssi_dbm": -91,
        "snr_db": 7.25,
        "warnings": [],
    }

    cartridge = {
        "packet_type": "nfc_memory_cartridge_metadata",
        "schema_version": "flowrouter.poc.v0",
        "cartridge_id": cartridge_id,
        "label": "field-test-cache-alpha",
        "pointer": f"flowmemory://cache/{short_id(seed, 'pointer')}",
        "digest": digest(seed, "cartridge-digest"),
        "created_at": iso_tick(80),
        "expires_at": "2026-06-13T17:00:00Z",
        "contains_secrets": False,
        "trust_level": "untrusted-pointer",
    }

    emergency = {
        "packet_type": "emergency_offline_signal",
        "schema_version": "flowrouter.poc.v0",
        "device_id": device_id,
        "sequence": 1007 + seed,
        "emitted_at": iso_tick(90),
        "code": "UPSTREAM_LOSS",
        "priority": "local",
        "ttl_seconds": 900,
        "summary": "Upstream unavailable; LAN dashboard and local cache still reachable.",
        "last_gateway_id": gateway_id,
        "operator_action": "check-upstream-and-power",
    }

    bridge_alert = {
        "packet_type": "bridge_alert",
        "schema_version": "flowrouter.poc.v0",
        "device_id": device_id,
        "sequence": 1008 + seed,
        "emitted_at": iso_tick(95),
        "bridge_id": f"bridge-{short_id(seed, 'bridge')}",
        "source_chain": "flowchain-local-alpha",
        "target_chain": "base-sepolia-sim",
        "alert_code": "LOCKBOX_OBSERVER_LAG",
        "severity": "warning",
        "subject_id": f"lockbox:{short_id(seed, 'bridge-subject')}",
        "digest": bridge_digest,
        "block_hint": 1200024,
        "payload_bytes_estimate": 136,
        "lora_eligible": True,
        "verification_state": "advisory",
        "summary": "Bridge observer digest lag detected; local chain continues while operator reviews.",
        "operator_action": "review-bridge-observer-and-do-not-block-chain",
    }

    node_health = {
        "packet_type": "node_health",
        "schema_version": "flowrouter.poc.v0",
        "device_id": device_id,
        "sequence": 1009 + seed,
        "emitted_at": iso_tick(105),
        "health": "healthy",
        "uptime_seconds": heartbeat["uptime_seconds"],
        "cpu_temp_c": 43.5,
        "memory_used_mb": 512,
        "disk_free_mb": 238592,
        "queue_depth": 2,
        "health_digest": digest(seed, "node-health"),
        "payload_bytes_estimate": 112,
        "lora_eligible": True,
        "chain_startup_blocking": False,
    }

    peer_hint = {
        "packet_type": "peer_hint",
        "schema_version": "flowrouter.poc.v0",
        "device_id": device_id,
        "sequence": 1010 + seed,
        "emitted_at": iso_tick(110),
        "peer_id": f"peer-{short_id(seed, 'peer')}",
        "peer_role": "observer",
        "transport": "meshtastic-control-sim",
        "link_state": "heard",
        "last_seen_at": iso_tick(108),
        "rssi_dbm": -88,
        "snr_db": 6.5,
        "advertised_roles": ["hardware-observer", "digest-relay"],
        "payload_bytes_estimate": 104,
        "lora_eligible": True,
        "normal_network_required_for_sync": True,
    }

    dashboard_feed = {
        "packet_type": "dashboard_feed",
        "schema_version": "flowrouter.poc.v0",
        "device_id": device_id,
        "generated_at": iso_tick(115),
        "network": {
            "lan": "reachable",
            "upstream": "reachable",
            "gateway_id": gateway_id,
        },
        "cache": {
            "health": cache_status["health"],
            "bytes_used": cache_status["bytes_used"],
            "bytes_limit": cache_status["bytes_limit"],
            "unresolved_count": cache_status["unresolved_count"],
        },
        "sidecar": {
            "state": "ready",
            "region": sidecar_status["region"],
            "payload_budget_bytes": sidecar_status["payload_budget_bytes"],
        },
        "peer": {
            "peer_id": peer_hint["peer_id"],
            "link_state": peer_hint["link_state"],
            "transport": peer_hint["transport"],
        },
        "node_health": {
            "health": node_health["health"],
            "queue_depth": node_health["queue_depth"],
            "chain_startup_blocking": node_health["chain_startup_blocking"],
        },
        "flowcore": {
            "state": "online",
            "pattern": "solid-cobalt",
        },
        "latest_receipt_digest": receipt_digest,
        "trust_labels": ["local", "advisory", "not-chain-verified"],
    }

    return {
        "device_manifest": manifest,
        "heartbeat": heartbeat,
        "flowpulse_digest_relay": flowpulse_relay,
        "verifier_report_digest_relay": verifier_report,
        "compact_receipt_relay": receipt_relay,
        "local_cache_status": cache_status,
        "gateway_discovery": gateway_discovery,
        "sidecar_status": sidecar_status,
        "nfc_memory_cartridge_metadata": cartridge,
        "emergency_offline_signal": emergency,
        "bridge_alert": bridge_alert,
        "node_health": node_health,
        "peer_hint": peer_hint,
        "dashboard_feed": dashboard_feed,
    }


def build_operator_signals(seed: int, packets: dict[str, Any] | None = None) -> dict[str, Any]:
    packet_set = packets if packets is not None else build_packets(seed)
    manifest = packet_set["device_manifest"]
    heartbeat = packet_set["heartbeat"]
    receipt = packet_set["compact_receipt_relay"]
    verifier = packet_set["verifier_report_digest_relay"]
    emergency = packet_set["emergency_offline_signal"]
    bridge = packet_set["bridge_alert"]
    cartridge = packet_set["nfc_memory_cartridge_metadata"]
    sidecar = packet_set["sidecar_status"]
    node_health = packet_set["node_health"]
    peer_hint = packet_set["peer_hint"]
    dashboard = packet_set["dashboard_feed"]

    device_id = heartbeat["device_id"]
    generated_at = dashboard["generated_at"]
    packet_fixture_path = f"hardware/fixtures/flowrouter_sample_seed{seed}.json"
    operator_fixture_path = f"fixtures/hardware/flowrouter_local_alpha_seed{seed}.json"
    handoff_fixture_path = f"fixtures/hardware/flowrouter_control_plane_handoff_seed{seed}.json"
    negative_report_path = f"fixtures/hardware/flowrouter_negative_validation_seed{seed}.json"
    operator_metadata_id = f"operator-metadata:hardware:{short_id(seed, 'operator-metadata')}"
    worker_id = f"hardware-node:{device_id}"
    verifier_id = f"hardware-relay:{device_id}"
    receipt_id = f"receipt:hardware:{short_id(seed, 'work-receipt-ref')}"
    verifier_report_id = f"report:hardware:{short_id(seed, 'verifier-report-ref')}"
    alert_id = f"hw-alert-{short_id(seed, 'offline-alert')}"
    bridge_alert_id = f"bridge-alert:hardware:{short_id(seed, 'bridge-alert-ref')}"
    bridge_incident_id = f"hw-alert-{short_id(seed, 'bridge-incident')}"
    challenge_id = f"challenge:hardware:{short_id(seed, 'offline-challenge')}"
    artifact_id = f"artifact:hardware:{short_id(seed, 'cartridge-artifact-ref')}"
    memory_cell_id = f"memory:hardware:{short_id(seed, 'cartridge-memory-ref')}"
    finality_receipt_id = f"finality:hardware:{short_id(seed, 'receipt-finality')}"
    node_health_id = f"node-health:hardware:{short_id(seed, 'node-health-ref')}"
    peer_hint_id = f"peer-hint:hardware:{short_id(seed, 'peer-hint-ref')}"

    provenance = {
        "subsystem": "hardware",
        "origin": "fixture",
        "chainContext": HARDWARE_CHAIN_CONTEXT,
        "fixturePath": operator_fixture_path,
        "capturedAt": generated_at,
        "localPathHint": packet_fixture_path,
    }

    hardware_node = {
        "id": device_id,
        "nodeId": device_id,
        "callsign": "FlowRouter local-alpha fixture",
        "role": "router",
        "firmware": "flowrouter.poc.v0",
        "transport": "local-wifi+meshtastic-sidecar-sim",
        "lastHeartbeatAt": heartbeat["emitted_at"],
        "linkedWorkLaneId": "CHECKPOINT_STORAGE",
        "locationHint": "local lab fixture",
        "status": "verified" if heartbeat["network_state"] == "online" else "stale",
        "powerState": heartbeat["power_state"],
        "cacheState": heartbeat["cache_state"],
        "sidecarState": heartbeat["sidecar_state"],
        "flowcoreState": heartbeat["flowcore_state"],
        "warnings": heartbeat["warnings"],
        "localOnly": True,
        "sourcePacketType": "heartbeat",
        "provenance": provenance,
    }

    node_health_record = {
        "nodeHealthId": node_health_id,
        "nodeId": device_id,
        "rootfieldId": HARDWARE_ROOTFIELD_ID,
        "health": node_health["health"],
        "observedAt": node_health["emitted_at"],
        "uptimeSeconds": node_health["uptime_seconds"],
        "cpuTempC": node_health["cpu_temp_c"],
        "memoryUsedMb": node_health["memory_used_mb"],
        "diskFreeMb": node_health["disk_free_mb"],
        "queueDepth": node_health["queue_depth"],
        "healthDigest": ensure_hex(node_health["health_digest"]),
        "status": "observed",
        "payloadBytesEstimate": node_health["payload_bytes_estimate"],
        "loraEligible": node_health["lora_eligible"],
        "chainStartupBlocking": node_health["chain_startup_blocking"],
        "localOnly": True,
        "sourcePacketType": "node_health",
        "provenance": provenance,
    }

    peer_hint_record = {
        "peerHintId": peer_hint_id,
        "nodeId": device_id,
        "peerId": peer_hint["peer_id"],
        "peerRole": peer_hint["peer_role"],
        "transport": peer_hint["transport"],
        "linkState": peer_hint["link_state"],
        "lastSeenAt": peer_hint["last_seen_at"],
        "advertisedRoles": peer_hint["advertised_roles"],
        "rssiDbm": peer_hint["rssi_dbm"],
        "snrDb": peer_hint["snr_db"],
        "payloadBytesEstimate": peer_hint["payload_bytes_estimate"],
        "loraEligible": peer_hint["lora_eligible"],
        "normalNetworkRequiredForSync": peer_hint["normal_network_required_for_sync"],
        "localOnly": True,
        "sourcePacketType": "peer_hint",
        "provenance": provenance,
    }

    operator_metadata = {
        "metadataId": operator_metadata_id,
        "operatorId": f"operator:local:{short_id(seed, 'operator')}",
        "nodeId": device_id,
        "rootfieldId": HARDWARE_ROOTFIELD_ID,
        "displayName": "Local hardware operator fixture",
        "roles": ["hardware_observer", "fixture_relay"],
        "transportPreferences": ["local-simulator", "meshtastic-control-sim"],
        "hardwareRequiredForPrivateTestnet": False,
        "noSecrets": True,
        "radioPayloadBudgetBytes": sidecar["payload_budget_bytes"],
        "metadataSource": "device_manifest",
        "observedAt": manifest["generated_at"],
        "localOnly": True,
        "sourcePacketType": "device_manifest",
        "provenance": provenance,
    }

    work_receipt = {
        "receiptId": receipt_id,
        "rootfieldId": HARDWARE_ROOTFIELD_ID,
        "workerId": worker_id,
        "inputRoot": ZERO_HASH,
        "outputRoot": ensure_hex(receipt["receipt_digest"]),
        "artifactCommitment": ensure_hex(cartridge["digest"]),
        "ruleSet": "flowmemory.hardware.operator_signal.local_alpha.v0",
        "status": "unresolved",
        "receiptDigest": ensure_hex(receipt["receipt_digest"]),
        "chain": receipt["chain"],
        "locatorHint": {
            "blockHint": receipt["block_hint"],
            "txHashPrefix": receipt["tx_hash_prefix"],
            "logIndexHint": receipt["log_index_hint"],
        },
        "resolutionState": "needs-normal-network-reconciliation",
        "payloadBytesEstimate": receipt["payload_bytes_estimate"],
        "loraEligible": receipt["lora_eligible"],
        "localOnly": True,
        "sourcePacketType": "compact_receipt_relay",
    }

    verifier_report = {
        "reportId": verifier_report_id,
        "relayReportId": verifier["report_id"],
        "rootfieldId": HARDWARE_ROOTFIELD_ID,
        "receiptId": receipt_id,
        "verifierId": verifier_id,
        "reportDigest": ensure_hex(verifier["report_digest"]),
        "subjectDigest": ensure_hex(verifier["subject_digest"]),
        "status": verifier["result"],
        "reasonCodes": ["hardware_digest_relay_only"],
        "resolutionState": "needs-full-report",
        "payloadBytesEstimate": verifier["payload_bytes_estimate"],
        "loraEligible": verifier["lora_eligible"],
        "localOnly": True,
        "sourcePacketType": "verifier_report_digest_relay",
    }

    bridge_alert = {
        "bridgeAlertId": bridge_alert_id,
        "bridgeId": bridge["bridge_id"],
        "rootfieldId": HARDWARE_ROOTFIELD_ID,
        "severity": bridge["severity"],
        "alertCode": bridge["alert_code"],
        "sourceChain": bridge["source_chain"],
        "targetChain": bridge["target_chain"],
        "subjectId": bridge["subject_id"],
        "eventDigest": ensure_hex(bridge["digest"]),
        "blockHint": bridge["block_hint"],
        "status": "unresolved",
        "resolutionState": "operator-review-required",
        "summary": bridge["summary"],
        "recommendedAction": bridge["operator_action"],
        "payloadBytesEstimate": bridge["payload_bytes_estimate"],
        "loraEligible": bridge["lora_eligible"],
        "localOnly": True,
        "doesNotBlockLocalChain": True,
        "sourcePacketType": "bridge_alert",
        "provenance": provenance,
    }

    artifact = {
        "artifactId": artifact_id,
        "rootfieldId": HARDWARE_ROOTFIELD_ID,
        "commitment": ensure_hex(cartridge["digest"]),
        "uriHint": cartridge["pointer"],
        "status": "observed",
        "availabilityStatus": "metadata-only",
        "cartridgeId": cartridge["cartridge_id"],
        "label": cartridge["label"],
        "expiresAt": cartridge["expires_at"],
        "containsSecrets": cartridge["contains_secrets"],
        "trustLevel": cartridge["trust_level"],
        "localOnly": True,
        "sourcePacketType": "nfc_memory_cartridge_metadata",
    }

    memory_cell = {
        "memoryCellId": memory_cell_id,
        "rootfieldId": HARDWARE_ROOTFIELD_ID,
        "currentRoot": ensure_hex(cartridge["digest"]),
        "latestRoot": ensure_hex(cartridge["digest"]),
        "receiptId": receipt_id,
        "artifactId": artifact_id,
        "status": "observed",
        "summary": "NFC cartridge metadata pointer projected into a local memory cell candidate.",
        "updatedAt": cartridge["created_at"],
        "resolutionState": "untrusted-metadata-only",
        "localOnly": True,
        "sourcePacketType": "nfc_memory_cartridge_metadata",
    }

    challenge = {
        "challengeId": challenge_id,
        "targetId": receipt_id,
        "receiptId": receipt_id,
        "reportId": verifier_report_id,
        "openedBy": worker_id,
        "status": "pending",
        "reason": "offline-alert-candidate",
        "summary": emergency["summary"],
        "openedAt": emergency["emitted_at"],
        "ttlSeconds": emergency["ttl_seconds"],
        "recommendedAction": emergency["operator_action"],
        "doesNotExecuteRemoteAction": True,
        "localOnly": True,
        "sourcePacketType": "emergency_offline_signal",
    }

    finality_receipt = {
        "finalityReceiptId": finality_receipt_id,
        "objectId": receipt_id,
        "receiptId": receipt_id,
        "rootfieldId": HARDWARE_ROOTFIELD_ID,
        "finalityStatus": "local-pending",
        "settlement": "local-fixture",
        "status": "pending",
        "localOnly": True,
        "sourcePacketType": "compact_receipt_relay",
    }

    alert = {
        "id": alert_id,
        "incidentId": alert_id,
        "severity": "warning",
        "title": emergency["code"],
        "summary": emergency["summary"],
        "openedAt": emergency["emitted_at"],
        "linkedObjectIds": [device_id, receipt_id, challenge_id],
        "recommendedAction": emergency["operator_action"],
        "status": "unresolved",
        "localOnly": True,
        "sourcePacketType": "emergency_offline_signal",
        "provenance": provenance,
    }

    bridge_incident = {
        "id": bridge_incident_id,
        "incidentId": bridge_incident_id,
        "severity": bridge["severity"],
        "title": bridge["alert_code"],
        "summary": bridge["summary"],
        "openedAt": bridge["emitted_at"],
        "linkedObjectIds": [bridge_alert_id],
        "recommendedAction": bridge["operator_action"],
        "status": "unresolved",
        "localOnly": True,
        "sourcePacketType": "bridge_alert",
        "provenance": provenance,
    }

    def signal_envelope(
        label: str,
        signal_type: str,
        packet: dict[str, Any],
        object_refs: list[dict[str, str]],
        status: str,
    ) -> dict[str, Any]:
        packet_type = packet["packet_type"]
        sequence = packet.get("sequence", seed)
        observed_at = packet.get("emitted_at", packet.get("created_at", packet.get("generated_at", generated_at)))
        return {
            "schema": "flowmemory.hardware_operator_signal_envelope.local_alpha.v0",
            "envelopeId": f"hw-env-{short_id(seed, f'{label}-envelope')}",
            "signalId": f"hw-sig-{short_id(seed, f'{label}-signal')}",
            "signalType": signal_type,
            "sourcePacketType": packet_type,
            "sourcePacketId": f"{packet_type}:{sequence}",
            "observedAt": observed_at,
            "status": status,
            "localOnly": True,
            "payloadBytesEstimate": packet.get("payload_bytes_estimate", 0),
            "loraEligible": packet.get("lora_eligible", False),
            "objectRefs": object_refs,
            "provenance": provenance,
        }

    def workbench_record(
        record_id: str,
        kind: str,
        title: str,
        summary: str,
        status: str,
        facts: list[dict[str, str]],
        raw: dict[str, Any],
    ) -> dict[str, Any]:
        return {
            "id": record_id,
            "kind": kind,
            "title": title,
            "summary": summary,
            "status": status,
            "facts": facts,
            "provenance": provenance,
            "raw": raw,
        }

    signal_envelopes = [
        signal_envelope(
            "operator-metadata",
            "operator_metadata",
            manifest,
            [{"collection": "operatorMetadata", "objectId": operator_metadata_id}],
            "observed",
        ),
        signal_envelope(
            "heartbeat",
            "heartbeat",
            heartbeat,
            [{"collection": "hardwareNodes", "objectId": device_id}],
            "observed",
        ),
        signal_envelope(
            "receipt-relay",
            "receipt_relay",
            receipt,
            [{"collection": "workReceipts", "objectId": receipt_id}],
            "unresolved",
        ),
        signal_envelope(
            "verifier-digest-relay",
            "verifier_digest_relay",
            verifier,
            [{"collection": "verifierReports", "objectId": verifier_report_id}],
            "unresolved",
        ),
        signal_envelope(
            "offline-alert-challenge",
            "offline_alert_challenge_input",
            emergency,
            [
                {"collection": "alerts", "objectId": alert_id},
                {"collection": "challenges", "objectId": challenge_id},
            ],
            "pending",
        ),
        signal_envelope(
            "bridge-alert",
            "bridge_alert",
            bridge,
            [
                {"collection": "bridgeAlerts", "objectId": bridge_alert_id},
                {"collection": "alerts", "objectId": bridge_incident_id},
            ],
            "unresolved",
        ),
        signal_envelope(
            "nfc-memory-cartridge",
            "nfc_memory_cartridge_metadata",
            cartridge,
            [
                {"collection": "artifactCommitments", "objectId": artifact_id},
                {"collection": "memoryCells", "objectId": memory_cell_id},
            ],
            "observed",
        ),
        signal_envelope(
            "node-health",
            "node_health",
            node_health,
            [{"collection": "nodeHealth", "objectId": node_health_id}],
            "observed",
        ),
        signal_envelope(
            "peer-hint",
            "peer_hint",
            peer_hint,
            [{"collection": "peerHints", "objectId": peer_hint_id}],
            "observed",
        ),
    ]

    signal_summaries = {
        "operator_metadata": "Local operator metadata for optional hardware fixture ingestion.",
        "heartbeat": "FlowRouter heartbeat and coarse node state.",
        "receipt_relay": "Compact WorkReceipt digest relay awaiting normal reconciliation.",
        "verifier_digest_relay": "Compact VerifierReport digest relay awaiting the full report.",
        "offline_alert_challenge_input": "Offline alert that can seed a local challenge candidate.",
        "bridge_alert": "Compact bridge observer alert that does not block local chain progress.",
        "nfc_memory_cartridge_metadata": "NFC metadata pointer projected into artifact and memory references.",
        "node_health": "Compact node health digest that cannot block local chain startup.",
        "peer_hint": "Low-bandwidth peer hint for operator-visible local topology only.",
    }
    hardware_signals = [
        {
            "id": envelope["signalId"],
            "signalId": envelope["signalId"],
            "envelopeId": envelope["envelopeId"],
            "nodeId": device_id,
            "signalType": envelope["signalType"],
            "sourcePacketType": envelope["sourcePacketType"],
            "summary": signal_summaries[envelope["signalType"]],
            "status": envelope["status"],
            "transport": "local-simulator" if not envelope["loraEligible"] else "meshtastic-control-sim",
            "receivedAt": envelope["observedAt"],
            "localOnly": True,
            "loraEligible": envelope["loraEligible"],
            "linkedObjectIds": [ref["objectId"] for ref in envelope["objectRefs"]],
            "provenance": provenance,
            "rawEnvelope": envelope,
        }
        for envelope in signal_envelopes
    ]

    return {
        "schema": "flowmemory.hardware_operator_signals.local_alpha.v0",
        "generatedAt": generated_at,
        "chainId": "flowmemory-local-alpha",
        "environment": "local-devnet-fixture",
        "source": "fixture",
        "sourcePaths": {
            "packetFixture": packet_fixture_path,
            "operatorFixture": operator_fixture_path,
            "operatorSchema": "hardware/simulator/schemas/flowchain_operator_signals.schema.json",
            "handoffFixture": handoff_fixture_path,
            "handoffSchema": "schemas/flowmemory/hardware-control-plane-handoff.schema.json",
            "negativeReport": negative_report_path,
            "negativeReportSchema": "hardware/simulator/schemas/negative_validation_report.schema.json",
            "mappingDoc": "hardware/flowrouter/FLOWCHAIN_LOCAL_ALPHA_SIGNALS.md",
        },
        "boundary": {
            "localOnly": True,
            "advisory": True,
            "normalNetworkReconciliationRequired": True,
            "hardwareRequiredForPrivateTestnet": False,
            "claimLimitations": [
                "Hardware-originated references are hints until reconciled by normal indexer, receipt, and verifier paths.",
                "LoRa and Meshtastic packets carry compact control signals, not artifacts, model data, media, or raw memory.",
                "NFC cartridge metadata is an untrusted pointer until checked against expected commitments.",
                "Emergency offline signals are operator alerts or challenge inputs only; they do not execute remote actions.",
                "Bridge alerts are operator review hints and must not block local chain progress.",
                "Node health signals are observability hints and cannot block private/local chain startup.",
                "Peer hints describe local topology candidates only and require normal network reconciliation for sync.",
            ],
        },
        "packetMappings": [
            {
                "sourcePacketType": "device_manifest",
                "flowchainSignal": "operator_metadata",
                "objectCollection": "operatorMetadata",
                "objectRef": operator_metadata_id,
                "localAlphaRole": "names the local optional hardware operator fixture issuer",
                "trustBoundary": "local metadata only; no wallet, secret, or production operator claim",
            },
            {
                "sourcePacketType": "heartbeat",
                "flowchainSignal": "hardware_node_status",
                "objectCollection": "hardwareNodes",
                "objectRef": device_id,
                "localAlphaRole": "shows FlowRouter reachability and coarse device state",
                "trustBoundary": "local advisory status, not hardware attestation",
            },
            {
                "sourcePacketType": "node_health",
                "flowchainSignal": "node_health",
                "objectCollection": "nodeHealth",
                "objectRef": node_health_id,
                "localAlphaRole": "adds compact node health and queue-depth observability",
                "trustBoundary": "observability only; it cannot block local chain startup",
            },
            {
                "sourcePacketType": "peer_hint",
                "flowchainSignal": "peer_hint",
                "objectCollection": "peerHints",
                "objectRef": peer_hint_id,
                "localAlphaRole": "surfaces a local topology hint for operator review",
                "trustBoundary": "peer hint only; not authentication, sync proof, or LAN discovery authority",
            },
            {
                "sourcePacketType": "compact_receipt_relay",
                "flowchainSignal": "work_receipt_reference",
                "objectCollection": "workReceipts",
                "objectRef": receipt_id,
                "localAlphaRole": "points the workbench at a WorkReceipt candidate",
                "trustBoundary": "digest and locator hints require normal receipt reconciliation",
            },
            {
                "sourcePacketType": "verifier_report_digest_relay",
                "flowchainSignal": "verifier_report_reference",
                "objectCollection": "verifierReports",
                "objectRef": verifier_report_id,
                "localAlphaRole": "points the workbench at a VerifierReport candidate",
                "trustBoundary": "digest relay is not the full verifier report",
            },
            {
                "sourcePacketType": "emergency_offline_signal",
                "flowchainSignal": "alert_challenge_input",
                "objectCollection": "challenges",
                "objectRef": challenge_id,
                "localAlphaRole": "creates an operator alert and optional challenge input",
                "trustBoundary": "local operator attention only; no public emergency-service claim",
            },
            {
                "sourcePacketType": "bridge_alert",
                "flowchainSignal": "bridge_observer_alert",
                "objectCollection": "bridgeAlerts",
                "objectRef": bridge_alert_id,
                "localAlphaRole": "surfaces bridge-observer lag without blocking the local chain",
                "trustBoundary": "digest alert only; no production bridge readiness or settlement claim",
            },
            {
                "sourcePacketType": "nfc_memory_cartridge_metadata",
                "flowchainSignal": "artifact_memory_reference",
                "objectCollection": "artifactCommitments",
                "objectRef": artifact_id,
                "localAlphaRole": "connects cartridge metadata to an artifact or memory reference",
                "trustBoundary": "untrusted metadata pointer, not a secret store or proof",
            },
        ],
        "signalEnvelopes": signal_envelopes,
        "hardwareSignals": hardware_signals,
        "operatorMetadata": [operator_metadata],
        "hardwareNodes": [hardware_node],
        "nodeHealth": [node_health_record],
        "peerHints": [peer_hint_record],
        "workReceipts": [work_receipt],
        "verifierReports": [verifier_report],
        "bridgeAlerts": [bridge_alert],
        "artifactCommitments": [artifact],
        "memoryCells": [memory_cell],
        "challenges": [challenge],
        "finalityReceipts": [finality_receipt],
        "alerts": [alert, bridge_incident],
        "workbenchRecords": {
            "operatorMetadata": [
                workbench_record(
                    operator_metadata_id,
                    "Hardware operator metadata",
                    operator_metadata["displayName"],
                    "Local-only metadata for the optional hardware signal fixture issuer.",
                    "observed",
                    [
                        {"label": "operator", "value": operator_metadata["operatorId"]},
                        {"label": "node", "value": operator_metadata["nodeId"]},
                        {"label": "hardware required", "value": "false"},
                        {"label": "payload budget", "value": str(operator_metadata["radioPayloadBudgetBytes"])},
                    ],
                    operator_metadata,
                )
            ],
            "nodeHealth": [
                workbench_record(
                    node_health_id,
                    "Hardware node health",
                    node_health["health"],
                    "Compact node health digest for local operator observability.",
                    "observed",
                    [
                        {"label": "node", "value": device_id},
                        {"label": "queue depth", "value": str(node_health["queue_depth"])},
                        {"label": "health digest", "value": ensure_hex(node_health["health_digest"])},
                        {"label": "blocks startup", "value": "false"},
                    ],
                    node_health_record,
                )
            ],
            "peerHints": [
                workbench_record(
                    peer_hint_id,
                    "Hardware peer hint",
                    peer_hint["peer_id"],
                    "Low-bandwidth peer hint for local topology review.",
                    "observed",
                    [
                        {"label": "node", "value": device_id},
                        {"label": "peer", "value": peer_hint["peer_id"]},
                        {"label": "transport", "value": peer_hint["transport"]},
                        {"label": "link state", "value": peer_hint["link_state"]},
                    ],
                    peer_hint_record,
                )
            ],
            "receipts": [
                workbench_record(
                    receipt_id,
                    "Hardware WorkReceipt relay",
                    receipt_id,
                    "Compact hardware receipt relay awaiting normal network reconciliation.",
                    "unresolved",
                    [
                        {"label": "rootfield", "value": HARDWARE_ROOTFIELD_ID},
                        {"label": "receipt digest", "value": ensure_hex(receipt["receipt_digest"])},
                        {"label": "block hint", "value": str(receipt["block_hint"])},
                        {"label": "tx prefix", "value": receipt["tx_hash_prefix"]},
                    ],
                    work_receipt,
                )
            ],
            "verifierReports": [
                workbench_record(
                    verifier_report_id,
                    "Hardware VerifierReport relay",
                    verifier_report_id,
                    "Compact verifier report digest relay; full report is still required.",
                    "unresolved",
                    [
                        {"label": "relay report id", "value": verifier["report_id"]},
                        {"label": "report digest", "value": ensure_hex(verifier["report_digest"])},
                        {"label": "subject digest", "value": ensure_hex(verifier["subject_digest"])},
                        {"label": "result", "value": verifier["result"]},
                    ],
                    verifier_report,
                )
            ],
            "bridgeAlerts": [
                workbench_record(
                    bridge_alert_id,
                    "Hardware bridge alert",
                    bridge["alert_code"],
                    bridge["summary"],
                    "unresolved",
                    [
                        {"label": "bridge", "value": bridge["bridge_id"]},
                        {"label": "source", "value": bridge["source_chain"]},
                        {"label": "target", "value": bridge["target_chain"]},
                        {"label": "digest", "value": ensure_hex(bridge["digest"])},
                    ],
                    bridge_alert,
                )
            ],
            "artifacts": [
                workbench_record(
                    artifact_id,
                    "NFC cartridge artifact reference",
                    cartridge["label"],
                    "NFC cartridge metadata pointer; content is untrusted until commitment checks pass.",
                    "observed",
                    [
                        {"label": "cartridge", "value": cartridge["cartridge_id"]},
                        {"label": "pointer", "value": cartridge["pointer"]},
                        {"label": "commitment", "value": ensure_hex(cartridge["digest"])},
                        {"label": "expires", "value": cartridge["expires_at"]},
                    ],
                    artifact,
                )
            ],
            "memoryCells": [
                workbench_record(
                    memory_cell_id,
                    "Hardware memory cell candidate",
                    memory_cell_id,
                    "Projected from NFC cartridge metadata for local operator inspection.",
                    "observed",
                    [
                        {"label": "rootfield", "value": HARDWARE_ROOTFIELD_ID},
                        {"label": "latest root", "value": ensure_hex(cartridge["digest"])},
                        {"label": "receipt", "value": receipt_id},
                        {"label": "artifact", "value": artifact_id},
                    ],
                    memory_cell,
                )
            ],
            "challenges": [
                workbench_record(
                    challenge_id,
                    "Offline alert challenge candidate",
                    emergency["code"],
                    emergency["summary"],
                    "pending",
                    [
                        {"label": "target", "value": receipt_id},
                        {"label": "report", "value": verifier_report_id},
                        {"label": "ttl seconds", "value": str(emergency["ttl_seconds"])},
                        {"label": "action", "value": emergency["operator_action"]},
                    ],
                    challenge,
                )
            ],
            "hardwareSignals": [
                workbench_record(
                    signal["signalId"],
                    "Hardware operator signal",
                    signal["signalType"],
                    signal["summary"],
                    signal["status"],
                    [
                        {"label": "node", "value": signal["nodeId"]},
                        {"label": "transport", "value": signal["transport"]},
                        {"label": "source packet", "value": signal["sourcePacketType"]},
                        {"label": "linked objects", "value": ", ".join(signal["linkedObjectIds"])},
                    ],
                    signal,
                )
                for signal in hardware_signals
            ],
            "provenance": [
                workbench_record(
                    "hardware-operator-signal-fixture",
                    "Hardware operator signal fixture",
                    operator_fixture_path,
                    "Deterministic optional hardware signal projection for control-plane/workbench import.",
                    "verified",
                    [
                        {"label": "packet fixture", "value": packet_fixture_path},
                        {"label": "schema", "value": "flowmemory.hardware_operator_signals.local_alpha.v0"},
                        {"label": "seed", "value": str(seed)},
                        {"label": "hardware required", "value": "false"},
                    ],
                    {
                        "sourcePaths": {
                            "packetFixture": packet_fixture_path,
                            "operatorFixture": operator_fixture_path,
                            "handoffFixture": handoff_fixture_path,
                        }
                    },
                )
            ],
        },
        "compatibility": {
            "controlPlaneStateKeys": [
                "hardwareSignals",
                "operatorMetadata",
                "hardwareNodes",
                "nodeHealth",
                "peerHints",
                "workReceipts",
                "verifierReports",
                "bridgeAlerts",
                "artifactCommitments",
                "memoryCells",
                "challenges",
                "finalityReceipts",
                "alerts",
            ],
            "workbenchSectionKeys": [
                "operatorMetadata",
                "nodeHealth",
                "peerHints",
                "receipts",
                "verifierReports",
                "bridgeAlerts",
                "artifacts",
                "memoryCells",
                "challenges",
                "hardwareSignals",
                "provenance",
            ],
            "jsonRpcBoundary": "Read-only fixture data; no submit, wallet, live indexing, or production settlement method is implied.",
            "flowchainFullSmokeOptionalRow": {
                "label": "Validate optional hardware operator signal fixtures",
                "command": "python hardware/simulator/flowrouter_sim.py --smoke",
                "requiredForChainProgress": False,
                "hardwareRequired": False,
            },
        },
    }


def build_control_plane_handoff(seed: int, operator_signals: dict[str, Any] | None = None) -> dict[str, Any]:
    signal_doc = operator_signals if operator_signals is not None else build_operator_signals(seed)
    state_keys = signal_doc["compatibility"]["controlPlaneStateKeys"]
    return {
        "schema": "flowmemory.hardware_control_plane_handoff.local_alpha.v0",
        "generatedAt": signal_doc["generatedAt"],
        "chainId": signal_doc["chainId"],
        "environment": signal_doc["environment"],
        "sourceFixture": signal_doc["sourcePaths"]["operatorFixture"],
        "hardwareRequiredForPrivateTestnet": False,
        "mode": "read-only-optional-merge",
        "boundary": signal_doc["boundary"],
        "ingest": {
            "stateKeys": state_keys,
            "mergePolicy": "replace-by-stable-id",
            "idFields": {
                "hardwareSignals": "signalId",
                "operatorMetadata": "metadataId",
                "hardwareNodes": "nodeId",
                "nodeHealth": "nodeHealthId",
                "peerHints": "peerHintId",
                "workReceipts": "receiptId",
                "verifierReports": "reportId",
                "bridgeAlerts": "bridgeAlertId",
                "artifactCommitments": "artifactId",
                "memoryCells": "memoryCellId",
                "challenges": "challengeId",
                "finalityReceipts": "finalityReceiptId",
                "alerts": "incidentId",
            },
            "localOnly": True,
            "normalNetworkReconciliationRequired": True,
        },
        "collections": {key: signal_doc[key] for key in state_keys},
        "workbenchRecords": signal_doc["workbenchRecords"],
        "optionalSmokeRows": [signal_doc["compatibility"]["flowchainFullSmokeOptionalRow"]],
    }


class ValidationError(Exception):
    pass


def check_type(value: Any, expected: str) -> bool:
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return (isinstance(value, int) or isinstance(value, float)) and not isinstance(value, bool)
    if expected == "boolean":
        return isinstance(value, bool)
    return True


def validate_value(schema: dict[str, Any], value: Any, path: str) -> None:
    expected = schema.get("type")
    if expected and not check_type(value, expected):
        raise ValidationError(f"{path}: expected {expected}, got {type(value).__name__}")

    if "const" in schema and value != schema["const"]:
        raise ValidationError(f"{path}: value {value!r} does not match const {schema['const']!r}")

    if "enum" in schema and value not in schema["enum"]:
        raise ValidationError(f"{path}: value {value!r} not in enum {schema['enum']!r}")

    if isinstance(value, str) and "maxLength" in schema and len(value) > schema["maxLength"]:
        raise ValidationError(f"{path}: string longer than {schema['maxLength']}")

    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            raise ValidationError(f"{path}: value below minimum {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            raise ValidationError(f"{path}: value above maximum {schema['maximum']}")

    if isinstance(value, dict):
        required = schema.get("required", [])
        for key in required:
            if key not in value:
                raise ValidationError(f"{path}: missing required key {key}")

        properties = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            extra = sorted(set(value) - set(properties))
            if extra:
                raise ValidationError(f"{path}: unexpected keys {extra}")
        for key, child in properties.items():
            if key in value:
                validate_value(child, value[key], f"{path}.{key}")

    if isinstance(value, list) and "items" in schema:
        if "minItems" in schema and len(value) < schema["minItems"]:
            raise ValidationError(f"{path}: array shorter than {schema['minItems']}")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            raise ValidationError(f"{path}: array longer than {schema['maxItems']}")
        for index, item in enumerate(value):
            validate_value(schema["items"], item, f"{path}[{index}]")


def iter_strings(value: Any, path: str) -> list[tuple[str, str]]:
    if isinstance(value, str):
        return [(path, value)]
    if isinstance(value, dict):
        strings: list[tuple[str, str]] = []
        for key, child in value.items():
            strings.extend(iter_strings(child, f"{path}.{key}"))
        return strings
    if isinstance(value, list):
        strings = []
        for index, child in enumerate(value):
            strings.extend(iter_strings(child, f"{path}[{index}]"))
        return strings
    return []


def validate_no_secret_shaped_payloads(value: Any, path: str) -> None:
    for string_path, string_value in iter_strings(value, path):
        upper_value = string_value.upper()
        for pattern in SECRET_SHAPED_PATTERNS:
            compare_value = upper_value if pattern == pattern.upper() else string_value
            if pattern in compare_value:
                raise ValidationError(f"{string_path}: secret-shaped payload rejected")


def validate_fixture_timestamp(value: Any, path: str) -> None:
    if not isinstance(value, str) or not value.startswith(FIXTURE_TIME_PREFIX) or not value.endswith("Z"):
        raise ValidationError(f"{path}: stale timestamp rejected")


def validate_pattern(field: str, value: Any, path: str) -> None:
    pattern = ID_PATTERNS[field]
    if not isinstance(value, str) or not pattern.fullmatch(value):
        raise ValidationError(f"{path}: malformed {field}")


def validate_packet_semantics(packet: dict[str, Any], path: str) -> None:
    validate_no_secret_shaped_payloads(packet, path)

    for key in ("emitted_at", "generated_at", "created_at", "last_seen_at"):
        if key in packet:
            validate_fixture_timestamp(packet[key], f"{path}.{key}")

    if "device_id" in packet:
        validate_pattern("device_id", packet["device_id"], f"{path}.device_id")
    if "gateway_id" in packet:
        validate_pattern("gateway_id", packet["gateway_id"], f"{path}.gateway_id")
    if "cartridge_id" in packet:
        validate_pattern("cartridge_id", packet["cartridge_id"], f"{path}.cartridge_id")
    if "peer_id" in packet:
        validate_pattern("peer_id", packet["peer_id"], f"{path}.peer_id")
    if "report_id" in packet:
        validate_pattern("report_id", packet["report_id"], f"{path}.report_id")
    if "bridge_id" in packet:
        validate_pattern("bridge_id", packet["bridge_id"], f"{path}.bridge_id")
    if "cache_id" in packet:
        validate_pattern("cache_id", packet["cache_id"], f"{path}.cache_id")
    if "tx_hash_prefix" in packet:
        validate_pattern("tx_hash_prefix", packet["tx_hash_prefix"], f"{path}.tx_hash_prefix")

    for key in ("digest", "subject_digest", "report_digest", "receipt_digest", "cache_digest", "health_digest"):
        if key in packet:
            validate_pattern("digest64", packet[key], f"{path}.{key}")


def assert_unique(items: list[Any], id_field: str, path: str) -> None:
    seen: set[str] = set()
    for index, item in enumerate(items):
        if not isinstance(item, dict):
            continue
        value = item.get(id_field)
        if not isinstance(value, str):
            continue
        if value in seen:
            raise ValidationError(f"{path}[{index}]: duplicate {id_field}")
        seen.add(value)


def validate_operator_signal_semantics(operator_signals: dict[str, Any]) -> None:
    validate_no_secret_shaped_payloads(operator_signals, "operator_signals")
    assert_unique(operator_signals["signalEnvelopes"], "signalId", "operator_signals.signalEnvelopes")
    assert_unique(operator_signals["signalEnvelopes"], "envelopeId", "operator_signals.signalEnvelopes")
    assert_unique(operator_signals["hardwareSignals"], "signalId", "operator_signals.hardwareSignals")


def validate_handoff_semantics(handoff: dict[str, Any]) -> None:
    validate_no_secret_shaped_payloads(handoff, "control_plane_handoff")
    id_fields = handoff["ingest"]["idFields"]
    collections = handoff["collections"]
    for collection, id_field in id_fields.items():
        assert_unique(collections.get(collection, []), id_field, f"control_plane_handoff.collections.{collection}")


def load_schema(schema_dir: Path, packet_type: str) -> dict[str, Any]:
    schema_file = SCHEMA_FILES.get(packet_type)
    if not schema_file:
        raise ValidationError(f"no schema registered for packet type {packet_type}")
    return json.loads((schema_dir / schema_file).read_text(encoding="utf-8"))


def validate_packets(packets: dict[str, Any], schema_dir: Path) -> None:
    for name, packet in packets.items():
        if not isinstance(packet, dict):
            raise ValidationError(f"{name}: packet must be an object")
        packet_type = packet.get("packet_type")
        if packet_type != name:
            raise ValidationError(f"{name}: packet_type {packet_type!r} does not match key")
        schema = load_schema(schema_dir, packet_type)
        validate_value(schema, packet, name)
        validate_packet_semantics(packet, name)


def validate_operator_signals(operator_signals: dict[str, Any], schema_dir: Path) -> None:
    schema = json.loads((schema_dir / OPERATOR_SIGNALS_SCHEMA_FILE).read_text(encoding="utf-8"))
    validate_value(schema, operator_signals, "operator_signals")
    validate_operator_signal_semantics(operator_signals)


def validate_control_plane_handoff(handoff: dict[str, Any], repo_root: Path) -> None:
    schema_path = repo_root / "schemas" / "flowmemory" / "hardware-control-plane-handoff.schema.json"
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    validate_value(schema, handoff, "control_plane_handoff")
    validate_handoff_semantics(handoff)


def validate_negative_report(report: dict[str, Any], schema_dir: Path) -> None:
    schema = json.loads((schema_dir / NEGATIVE_REPORT_SCHEMA_FILE).read_text(encoding="utf-8"))
    validate_value(schema, report, "negative_report")


def output_document(seed: int) -> dict[str, Any]:
    return {
        "simulator": "flowrouter-v0-poc",
        "seed": seed,
        "generated_at": iso_tick(120),
        "packets": build_packets(seed),
    }


def run_negative_cases(seed: int, schema_dir: Path, repo_root: Path) -> list[dict[str, Any]]:
    packets = build_packets(seed)
    operator_doc = build_operator_signals(seed, packets)
    handoff_doc = build_control_plane_handoff(seed, operator_doc)

    cases: list[dict[str, Any]] = []

    def expect_rejected(name: str, validator: Any, value: Any, expected: str) -> None:
        try:
            validator(value)
        except ValidationError as exc:
            message = str(exc)
            if expected not in message:
                raise ValidationError(f"{name}: expected error containing {expected!r}, got {message!r}") from exc
            cases.append({"case": name, "expectedFailure": expected, "actualFailure": message, "passed": True})
            return
        raise ValidationError(f"{name}: negative case unexpectedly passed validation")

    missing_heartbeat_device = clone_json(packets)
    del missing_heartbeat_device["heartbeat"]["device_id"]
    expect_rejected(
        "heartbeat_missing_device_id",
        lambda value: validate_packets(value, schema_dir),
        missing_heartbeat_device,
        "missing required key device_id",
    )

    malformed_heartbeat_device = clone_json(packets)
    malformed_heartbeat_device["heartbeat"]["device_id"] = "flowrouter#42"
    expect_rejected(
        "heartbeat_malformed_device_id",
        lambda value: validate_packets(value, schema_dir),
        malformed_heartbeat_device,
        "malformed device_id",
    )

    stale_heartbeat = clone_json(packets)
    stale_heartbeat["heartbeat"]["emitted_at"] = "2026-05-12T17:00:10Z"
    expect_rejected(
        "heartbeat_stale_timestamp",
        lambda value: validate_packets(value, schema_dir),
        stale_heartbeat,
        "stale timestamp rejected",
    )

    oversized_receipt_relay = clone_json(packets)
    oversized_receipt_relay["compact_receipt_relay"]["payload_bytes_estimate"] = 512
    expect_rejected(
        "receipt_relay_payload_exceeds_control_budget",
        lambda value: validate_packets(value, schema_dir),
        oversized_receipt_relay,
        "value above maximum 200",
    )

    nfc_secret_claim = clone_json(packets)
    nfc_secret_claim["nfc_memory_cartridge_metadata"]["contains_secrets"] = True
    expect_rejected(
        "nfc_metadata_claims_secret_storage",
        lambda value: validate_packets(value, schema_dir),
        nfc_secret_claim,
        "not in enum [False]",
    )

    nfc_secret_pointer = clone_json(packets)
    nfc_secret_pointer["nfc_memory_cartridge_metadata"]["pointer"] = "API_KEY=flowmemory-test-placeholder"
    expect_rejected(
        "nfc_metadata_secret_shaped_pointer",
        lambda value: validate_packets(value, schema_dir),
        nfc_secret_pointer,
        "secret-shaped payload",
    )

    missing_bridge_handoff = clone_json(operator_doc)
    del missing_bridge_handoff["bridgeAlerts"]
    expect_rejected(
        "operator_projection_missing_bridge_alerts",
        lambda value: validate_operator_signals(value, schema_dir),
        missing_bridge_handoff,
        "missing required key bridgeAlerts",
    )

    hardware_required = clone_json(operator_doc)
    hardware_required["boundary"]["hardwareRequiredForPrivateTestnet"] = True
    expect_rejected(
        "operator_projection_requires_hardware",
        lambda value: validate_operator_signals(value, schema_dir),
        hardware_required,
        "not in enum [False]",
    )

    duplicate_signal = clone_json(operator_doc)
    duplicate_signal["signalEnvelopes"][1]["signalId"] = duplicate_signal["signalEnvelopes"][0]["signalId"]
    expect_rejected(
        "operator_projection_duplicate_signal_id",
        lambda value: validate_operator_signals(value, schema_dir),
        duplicate_signal,
        "duplicate signalId",
    )

    oversized_operator_envelope = clone_json(operator_doc)
    oversized_operator_envelope["signalEnvelopes"][2]["payloadBytesEstimate"] = 512
    expect_rejected(
        "operator_envelope_payload_exceeds_control_budget",
        lambda value: validate_operator_signals(value, schema_dir),
        oversized_operator_envelope,
        "value above maximum 200",
    )

    handoff_requires_hardware = clone_json(handoff_doc)
    handoff_requires_hardware["hardwareRequiredForPrivateTestnet"] = True
    expect_rejected(
        "control_plane_handoff_requires_hardware",
        lambda value: validate_control_plane_handoff(value, repo_root),
        handoff_requires_hardware,
        "not in enum [False]",
    )

    handoff_missing_hardware_signals = clone_json(handoff_doc)
    del handoff_missing_hardware_signals["collections"]["hardwareSignals"]
    expect_rejected(
        "control_plane_handoff_missing_hardware_signals",
        lambda value: validate_control_plane_handoff(value, repo_root),
        handoff_missing_hardware_signals,
        "missing required key hardwareSignals",
    )

    return cases


def build_negative_report(seed: int, cases: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schema": "flowmemory.hardware_negative_validation.local_alpha.v0",
        "generatedAt": iso_tick(130),
        "seed": seed,
        "caseCount": len(cases),
        "allCasesRejected": all(case["passed"] for case in cases),
        "cases": cases,
    }


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def assert_matches_file(path: Path, expected: dict[str, Any]) -> None:
    if not path.exists():
        raise ValidationError(f"missing fixture: {path}")
    actual = json.loads(path.read_text(encoding="utf-8"))
    if actual != expected:
        raise ValidationError(f"fixture drift: {path}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED, help="deterministic seed")
    parser.add_argument("--generate-fixtures", action="store_true", help="write the canonical raw, operator, handoff, and negative validation fixtures")
    parser.add_argument("--smoke", action="store_true", help="validate canonical fixtures, check deterministic drift, and run negative cases")
    parser.add_argument("--run-negative-cases", action="store_true", help="run in-memory negative validation cases")
    parser.add_argument("--out", type=Path, help="write generated JSON to this path")
    parser.add_argument("--operator-out", type=Path, help="write FlowChain local-alpha operator signal JSON to this path")
    parser.add_argument("--handoff-out", type=Path, help="write control-plane handoff JSON to this path")
    parser.add_argument("--negative-report-out", type=Path, help="write negative validation report JSON to this path")
    parser.add_argument("--validate-file", type=Path, help="validate an existing simulator JSON file")
    parser.add_argument("--validate-operator-file", type=Path, help="validate an existing FlowChain local-alpha operator signal JSON file")
    parser.add_argument("--validate-handoff-file", type=Path, help="validate an existing hardware control-plane handoff JSON file")
    parser.add_argument("--validate-negative-report-file", type=Path, help="validate an existing negative validation report JSON file")
    args = parser.parse_args()

    schema_dir = Path(__file__).resolve().parent / "schemas"
    repo_root = Path(__file__).resolve().parents[2]

    try:
        if args.validate_negative_report_file:
            negative_report = json.loads(args.validate_negative_report_file.read_text(encoding="utf-8"))
            validate_negative_report(negative_report, schema_dir)
            print(f"valid: {args.validate_negative_report_file}")
            return 0

        if args.validate_handoff_file:
            handoff_doc = json.loads(args.validate_handoff_file.read_text(encoding="utf-8"))
            validate_control_plane_handoff(handoff_doc, repo_root)
            print(f"valid: {args.validate_handoff_file}")
            return 0

        if args.validate_operator_file:
            operator_doc = json.loads(args.validate_operator_file.read_text(encoding="utf-8"))
            validate_operator_signals(operator_doc, schema_dir)
            print(f"valid: {args.validate_operator_file}")
            return 0

        if args.validate_file:
            doc = json.loads(args.validate_file.read_text(encoding="utf-8"))
            validate_packets(doc["packets"], schema_dir)
            print(f"valid: {args.validate_file}")
            return 0

        if args.run_negative_cases:
            cases = run_negative_cases(args.seed, schema_dir, repo_root)
            print(f"negative cases passed: {len(cases)}")
            return 0

        packets = build_packets(args.seed)
        doc = output_document(args.seed)
        validate_packets(doc["packets"], schema_dir)
        operator_doc = build_operator_signals(args.seed, packets)
        validate_operator_signals(operator_doc, schema_dir)
        handoff_doc = build_control_plane_handoff(args.seed, operator_doc)
        validate_control_plane_handoff(handoff_doc, repo_root)
        negative_cases = run_negative_cases(args.seed, schema_dir, repo_root)
        negative_report = build_negative_report(args.seed, negative_cases)
        validate_negative_report(negative_report, schema_dir)

        if args.smoke:
            assert_matches_file(default_raw_fixture_path(args.seed), doc)
            assert_matches_file(default_operator_fixture_path(args.seed), operator_doc)
            assert_matches_file(default_handoff_fixture_path(args.seed), handoff_doc)
            assert_matches_file(default_negative_report_path(args.seed), negative_report)
            print(
                "smoke passed: raw packets, operator signals, control-plane handoff, "
                f"fixture drift check, and {len(negative_cases)} negative cases"
            )
            return 0

        encoded = json.dumps(doc, indent=2, sort_keys=True) + "\n"
        out_path = args.out
        operator_out_path = args.operator_out
        handoff_out_path = args.handoff_out
        negative_report_out_path = args.negative_report_out
        if args.generate_fixtures:
            out_path = out_path or default_raw_fixture_path(args.seed)
            operator_out_path = operator_out_path or default_operator_fixture_path(args.seed)
            handoff_out_path = handoff_out_path or default_handoff_fixture_path(args.seed)
            negative_report_out_path = negative_report_out_path or default_negative_report_path(args.seed)

        if out_path:
            write_json(out_path, doc)
            print(f"wrote: {out_path}")
        else:
            sys.stdout.write(encoded)
        if operator_out_path:
            write_json(operator_out_path, operator_doc)
            print(f"wrote: {operator_out_path}")
        if handoff_out_path:
            write_json(handoff_out_path, handoff_doc)
            print(f"wrote: {handoff_out_path}")
        if negative_report_out_path:
            write_json(negative_report_out_path, negative_report)
            print(f"wrote: {negative_report_out_path}")
        return 0
    except (KeyError, json.JSONDecodeError, OSError, ValidationError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
