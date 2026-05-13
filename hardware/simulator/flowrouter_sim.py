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


def digest(seed: int, label: str, length: int = 64) -> str:
    return hashlib.sha256(f"flowrouter-v0:{seed}:{label}".encode("utf-8")).hexdigest()[:length]


def short_id(seed: int, label: str) -> str:
    return digest(seed, label, 12)


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
    parser.add_argument("--validate-file", type=Path, help="validate an existing simulator JSON file")
    args = parser.parse_args()

    schema_dir = Path(__file__).resolve().parent / "schemas"

    try:
        if args.validate_file:
            doc = json.loads(args.validate_file.read_text(encoding="utf-8"))
            validate_packets(doc["packets"], schema_dir)
            print(f"valid: {args.validate_file}")
            return 0

        doc = output_document(args.seed)
        validate_packets(doc["packets"], schema_dir)
        encoded = json.dumps(doc, indent=2, sort_keys=True) + "\n"
        if args.out:
            args.out.parent.mkdir(parents=True, exist_ok=True)
            args.out.write_text(encoded, encoding="utf-8")
            print(f"wrote: {args.out}")
        else:
            sys.stdout.write(encoded)
        return 0
    except (KeyError, json.JSONDecodeError, OSError, ValidationError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
