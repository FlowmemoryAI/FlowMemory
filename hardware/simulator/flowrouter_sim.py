#!/usr/bin/env python3
"""Deterministic FlowRouter V0 POC packet generator and validator."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


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
    "dashboard_feed": "dashboard_feed.schema.json",
}

OPERATOR_SIGNALS_SCHEMA_FILE = "flowchain_operator_signals.schema.json"
ZERO_HASH = "0x0000000000000000000000000000000000000000000000000000000000000000"
HARDWARE_ROOTFIELD_ID = "rootfield:hardware:flowrouter-local-alpha"
HARDWARE_CHAIN_CONTEXT = "flowchain-private-local-testnet"


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


def build_packets(seed: int) -> dict[str, Any]:
    device_id = f"fr-{short_id(seed, 'device')}"
    gateway_id = f"gw-{short_id(seed, 'gateway')}"
    cartridge_id = f"cart-{short_id(seed, 'cartridge')}"
    receipt_digest = digest(seed, "receipt")
    flowpulse_digest = digest(seed, "flowpulse")
    verifier_digest = digest(seed, "verifier")
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
            "local_cache_status",
            "sidecar_status",
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

    dashboard_feed = {
        "packet_type": "dashboard_feed",
        "schema_version": "flowrouter.poc.v0",
        "device_id": device_id,
        "generated_at": iso_tick(100),
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
        "dashboard_feed": dashboard_feed,
    }


def build_operator_signals(seed: int, packets: dict[str, Any] | None = None) -> dict[str, Any]:
    packet_set = packets if packets is not None else build_packets(seed)
    heartbeat = packet_set["heartbeat"]
    receipt = packet_set["compact_receipt_relay"]
    verifier = packet_set["verifier_report_digest_relay"]
    emergency = packet_set["emergency_offline_signal"]
    cartridge = packet_set["nfc_memory_cartridge_metadata"]
    dashboard = packet_set["dashboard_feed"]

    device_id = heartbeat["device_id"]
    generated_at = dashboard["generated_at"]
    packet_fixture_path = f"hardware/fixtures/flowrouter_sample_seed{seed}.json"
    operator_fixture_path = f"fixtures/hardware/flowrouter_local_alpha_seed{seed}.json"
    worker_id = f"hardware-node:{device_id}"
    verifier_id = f"hardware-relay:{device_id}"
    receipt_id = f"receipt:hardware:{short_id(seed, 'work-receipt-ref')}"
    verifier_report_id = f"report:hardware:{short_id(seed, 'verifier-report-ref')}"
    alert_id = f"hw-alert-{short_id(seed, 'offline-alert')}"
    challenge_id = f"challenge:hardware:{short_id(seed, 'offline-challenge')}"
    artifact_id = f"artifact:hardware:{short_id(seed, 'cartridge-artifact-ref')}"
    memory_cell_id = f"memory:hardware:{short_id(seed, 'cartridge-memory-ref')}"
    finality_receipt_id = f"finality:hardware:{short_id(seed, 'receipt-finality')}"

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

    def signal_envelope(
        label: str,
        signal_type: str,
        packet: dict[str, Any],
        object_refs: list[dict[str, str]],
        status: str,
    ) -> dict[str, Any]:
        packet_type = packet["packet_type"]
        sequence = packet.get("sequence", seed)
        return {
            "schema": "flowmemory.hardware_operator_signal_envelope.local_alpha.v0",
            "envelopeId": f"hw-env-{short_id(seed, f'{label}-envelope')}",
            "signalId": f"hw-sig-{short_id(seed, f'{label}-signal')}",
            "signalType": signal_type,
            "sourcePacketType": packet_type,
            "sourcePacketId": f"{packet_type}:{sequence}",
            "observedAt": packet.get("emitted_at", packet.get("created_at", generated_at)),
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
            "nfc-memory-cartridge",
            "nfc_memory_cartridge_metadata",
            cartridge,
            [
                {"collection": "artifactCommitments", "objectId": artifact_id},
                {"collection": "memoryCells", "objectId": memory_cell_id},
            ],
            "observed",
        ),
    ]

    signal_summaries = {
        "heartbeat": "FlowRouter heartbeat and coarse node state.",
        "receipt_relay": "Compact WorkReceipt digest relay awaiting normal reconciliation.",
        "verifier_digest_relay": "Compact VerifierReport digest relay awaiting the full report.",
        "offline_alert_challenge_input": "Offline alert that can seed a local challenge candidate.",
        "nfc_memory_cartridge_metadata": "NFC metadata pointer projected into artifact and memory references.",
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
            ],
        },
        "packetMappings": [
            {
                "sourcePacketType": "heartbeat",
                "flowchainSignal": "hardware_node_status",
                "objectCollection": "hardwareNodes",
                "objectRef": device_id,
                "localAlphaRole": "shows FlowRouter reachability and coarse device state",
                "trustBoundary": "local advisory status, not hardware attestation",
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
        "hardwareNodes": [hardware_node],
        "workReceipts": [work_receipt],
        "verifierReports": [verifier_report],
        "artifactCommitments": [artifact],
        "memoryCells": [memory_cell],
        "challenges": [challenge],
        "finalityReceipts": [finality_receipt],
        "alerts": [alert],
        "workbenchRecords": {
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
                        }
                    },
                )
            ],
        },
        "compatibility": {
            "controlPlaneStateKeys": [
                "hardwareSignals",
                "hardwareNodes",
                "workReceipts",
                "verifierReports",
                "artifactCommitments",
                "memoryCells",
                "challenges",
                "finalityReceipts",
                "alerts",
            ],
            "workbenchSectionKeys": [
                "receipts",
                "verifierReports",
                "artifacts",
                "memoryCells",
                "challenges",
                "hardwareSignals",
                "provenance",
            ],
            "jsonRpcBoundary": "Read-only fixture data; no submit, wallet, live indexing, or production settlement method is implied.",
        },
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
        for index, item in enumerate(value):
            validate_value(schema["items"], item, f"{path}[{index}]")


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


def validate_operator_signals(operator_signals: dict[str, Any], schema_dir: Path) -> None:
    schema = json.loads((schema_dir / OPERATOR_SIGNALS_SCHEMA_FILE).read_text(encoding="utf-8"))
    validate_value(schema, operator_signals, "operator_signals")


def output_document(seed: int) -> dict[str, Any]:
    return {
        "simulator": "flowrouter-v0-poc",
        "seed": seed,
        "generated_at": iso_tick(120),
        "packets": build_packets(seed),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=42, help="deterministic seed")
    parser.add_argument("--out", type=Path, help="write generated JSON to this path")
    parser.add_argument("--operator-out", type=Path, help="write FlowChain local-alpha operator signal JSON to this path")
    parser.add_argument("--validate-file", type=Path, help="validate an existing simulator JSON file")
    parser.add_argument("--validate-operator-file", type=Path, help="validate an existing FlowChain local-alpha operator signal JSON file")
    args = parser.parse_args()

    schema_dir = Path(__file__).resolve().parent / "schemas"

    try:
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

        packets = build_packets(args.seed)
        doc = {
            "simulator": "flowrouter-v0-poc",
            "seed": args.seed,
            "generated_at": iso_tick(120),
            "packets": packets,
        }
        validate_packets(doc["packets"], schema_dir)
        operator_doc = build_operator_signals(args.seed, packets)
        validate_operator_signals(operator_doc, schema_dir)
        encoded = json.dumps(doc, indent=2, sort_keys=True) + "\n"
        if args.out:
            args.out.parent.mkdir(parents=True, exist_ok=True)
            args.out.write_text(encoded, encoding="utf-8")
            print(f"wrote: {args.out}")
        else:
            sys.stdout.write(encoded)
        if args.operator_out:
            args.operator_out.parent.mkdir(parents=True, exist_ok=True)
            args.operator_out.write_text(json.dumps(operator_doc, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            print(f"wrote: {args.operator_out}")
        return 0
    except (KeyError, json.JSONDecodeError, OSError, ValidationError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
