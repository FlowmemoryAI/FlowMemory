"""Validate FlowMemory crypto v0 test vectors.

This script is intentionally small and offline-only. It verifies the published
FlowPulse observation vector without reading secrets, RPC endpoints, or network
state.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Iterable, Tuple

try:
    from Crypto.Hash import keccak
except ImportError as exc:  # pragma: no cover - dependency guard for local use
    raise SystemExit(
        "Missing pycryptodome. Install a Keccak-256 provider before validating "
        "FlowMemory vectors."
    ) from exc


ROOT = Path(__file__).resolve().parent
VECTOR_PATH = ROOT / "test-vectors" / "flowpulse-observation-v0.json"


def keccak256(data: bytes) -> bytes:
    digest = keccak.new(digest_bits=256)
    digest.update(data)
    return digest.digest()


def hex32(value: bytes) -> str:
    if len(value) != 32:
        raise ValueError(f"expected 32 bytes, got {len(value)}")
    return "0x" + value.hex()


def parse_bytes32(value: str) -> bytes:
    raw = value[2:] if value.startswith("0x") else value
    data = bytes.fromhex(raw)
    if len(data) != 32:
        raise ValueError(f"expected bytes32, got {len(data)} bytes: {value}")
    return data


def encode_address(value: str) -> bytes:
    raw = value[2:] if value.startswith("0x") else value
    data = bytes.fromhex(raw)
    if len(data) != 20:
        raise ValueError(f"expected address, got {len(data)} bytes: {value}")
    return (b"\x00" * 12) + data


def encode_uint(value: int) -> bytes:
    return int(value).to_bytes(32, "big")


def abi_encode_static(fields: Iterable[Tuple[str, object]]) -> bytes:
    out = b""
    for field_type, value in fields:
        if field_type.startswith("uint"):
            out += encode_uint(int(value))
        elif field_type == "bytes32":
            out += parse_bytes32(str(value))
        elif field_type == "address":
            out += encode_address(str(value))
        else:
            raise ValueError(f"unsupported field type: {field_type}")
    return out


TYPE_STRINGS = {
    "flowPulseObservationV0": (
        "FlowPulseObservationV0(uint256 chainId,address emittingContract,"
        "uint64 blockNumber,bytes32 blockHash,bytes32 txHash,"
        "uint32 transactionIndex,uint32 logIndex,bytes32 eventSignature,"
        "bytes32 pulseId,bytes32 rootfieldId)"
    ),
    "flowPulseEventArgsV0": (
        "FlowPulseEventArgsV0(bytes32 pulseId,bytes32 rootfieldId,"
        "address actor,uint8 pulseType,bytes32 subject,bytes32 commitment,"
        "bytes32 parentPulseId,uint64 sequence,uint64 occurredAt,"
        "bytes32 uriHash)"
    ),
    "flowPulseReceiptV0": (
        "FlowPulseReceiptV0(bytes32 observationId,bytes32 eventArgsHash,"
        "bytes32 artifactRoot,bytes32 storageReceiptCommitment,"
        "bytes32 evidenceRoot,uint16 receiptVersion)"
    ),
    "verifierReportV0": (
        "FlowMemoryVerifierReportV0(bytes32 reportSchemaHash,"
        "bytes32 observationId,bytes32 receiptHash,bytes32 verifierId,"
        "bytes32 verifierSetRoot,uint8 status,bytes32 checksRoot,"
        "uint64 finalizedBlockNumber,bytes32 finalizedBlockHash,"
        "uint16 reportVersion)"
    ),
    "attestationEnvelopeV0": (
        "FlowMemoryAttestationEnvelopeV0(bytes32 subjectHash,uint8 subjectKind,"
        "bytes32 attesterId,bytes32 attesterKeyId,bytes32 verifierSetRoot,"
        "uint64 issuedAtUnixMs,uint64 expiresAtUnixMs,bytes32 nonce)"
    ),
}


def expect(label: str, actual: str, expected: str) -> None:
    if actual != expected:
        raise AssertionError(f"{label}: expected {expected}, got {actual}")


def validate_flowpulse_observation_vector() -> None:
    vector = json.loads(VECTOR_PATH.read_text(encoding="utf-8"))
    type_hashes = vector["typeHashes"]
    flow_pulse = vector["flowPulse"]
    observation = vector["observation"]
    receipt = vector["receipt"]
    report = vector["verifierReport"]
    attestation = vector["attestationEnvelope"]

    for name, type_string in TYPE_STRINGS.items():
        expect(name, hex32(keccak256(type_string.encode("utf-8"))), type_hashes[name])

    pulse_id = hex32(
        keccak256(
            abi_encode_static(
                [
                    ("bytes32", flow_pulse["schemaId"]),
                    ("uint256", flow_pulse["chainId"]),
                    ("address", flow_pulse["emittingContract"]),
                    ("bytes32", flow_pulse["rootfieldId"]),
                    ("address", flow_pulse["actor"]),
                    ("uint8", flow_pulse["pulseType"]),
                    ("bytes32", flow_pulse["subject"]),
                    ("bytes32", flow_pulse["commitment"]),
                    ("bytes32", flow_pulse["parentPulseId"]),
                    ("uint64", flow_pulse["sequence"]),
                ]
            )
        )
    )
    expect("pulseId", pulse_id, flow_pulse["pulseId"])

    observation_id = hex32(
        keccak256(
            abi_encode_static(
                [
                    ("bytes32", type_hashes["flowPulseObservationV0"]),
                    ("uint256", flow_pulse["chainId"]),
                    ("address", flow_pulse["emittingContract"]),
                    ("uint64", observation["blockNumber"]),
                    ("bytes32", observation["blockHash"]),
                    ("bytes32", observation["txHash"]),
                    ("uint32", observation["transactionIndex"]),
                    ("uint32", observation["logIndex"]),
                    ("bytes32", flow_pulse["eventSignature"]),
                    ("bytes32", flow_pulse["pulseId"]),
                    ("bytes32", flow_pulse["rootfieldId"]),
                ]
            )
        )
    )
    expect("observationId", observation_id, observation["observationId"])

    event_args_hash = hex32(
        keccak256(
            abi_encode_static(
                [
                    ("bytes32", type_hashes["flowPulseEventArgsV0"]),
                    ("bytes32", flow_pulse["pulseId"]),
                    ("bytes32", flow_pulse["rootfieldId"]),
                    ("address", flow_pulse["actor"]),
                    ("uint8", flow_pulse["pulseType"]),
                    ("bytes32", flow_pulse["subject"]),
                    ("bytes32", flow_pulse["commitment"]),
                    ("bytes32", flow_pulse["parentPulseId"]),
                    ("uint64", flow_pulse["sequence"]),
                    ("uint64", flow_pulse["occurredAt"]),
                    ("bytes32", flow_pulse["uriHash"]),
                ]
            )
        )
    )
    expect("eventArgsHash", event_args_hash, receipt["eventArgsHash"])

    receipt_hash = hex32(
        keccak256(
            abi_encode_static(
                [
                    ("bytes32", type_hashes["flowPulseReceiptV0"]),
                    ("bytes32", observation["observationId"]),
                    ("bytes32", receipt["eventArgsHash"]),
                    ("bytes32", receipt["artifactRoot"]),
                    ("bytes32", receipt["storageReceiptCommitment"]),
                    ("bytes32", receipt["evidenceRoot"]),
                    ("uint16", receipt["receiptVersion"]),
                ]
            )
        )
    )
    expect("receiptHash", receipt_hash, receipt["receiptHash"])

    report_id = hex32(
        keccak256(
            abi_encode_static(
                [
                    ("bytes32", type_hashes["verifierReportV0"]),
                    ("bytes32", report["reportSchemaHash"]),
                    ("bytes32", observation["observationId"]),
                    ("bytes32", receipt["receiptHash"]),
                    ("bytes32", report["verifierId"]),
                    ("bytes32", report["verifierSetRoot"]),
                    ("uint8", report["status"]),
                    ("bytes32", report["checksRoot"]),
                    ("uint64", report["finalizedBlockNumber"]),
                    ("bytes32", report["finalizedBlockHash"]),
                    ("uint16", report["reportVersion"]),
                ]
            )
        )
    )
    expect("reportId", report_id, report["reportId"])

    attestation_hash = hex32(
        keccak256(
            abi_encode_static(
                [
                    ("bytes32", type_hashes["attestationEnvelopeV0"]),
                    ("bytes32", attestation["subjectHash"]),
                    ("uint8", attestation["subjectKind"]),
                    ("bytes32", attestation["attesterId"]),
                    ("bytes32", attestation["attesterKeyId"]),
                    ("bytes32", attestation["verifierSetRoot"]),
                    ("uint64", attestation["issuedAtUnixMs"]),
                    ("uint64", attestation["expiresAtUnixMs"]),
                    ("bytes32", attestation["nonce"]),
                ]
            )
        )
    )
    expect("attestationEnvelopeHash", attestation_hash, attestation["attestationEnvelopeHash"])


def main() -> None:
    validate_flowpulse_observation_vector()
    print("FLOWPULSE_VECTOR_RECOMPUTE_OK")


if __name__ == "__main__":
    main()
