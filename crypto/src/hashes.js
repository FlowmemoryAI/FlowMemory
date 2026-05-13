import { keccak_256 } from "@noble/hashes/sha3.js";
import { DOMAIN_STRINGS } from "./constants.js";
import { abiEncodeStatic, bytesToHex, canonicalJson, concatBytes, utf8Bytes } from "./encoding.js";

export function keccak256Bytes(data) {
  return keccak_256(data);
}

export function keccak256Hex(data) {
  return bytesToHex(keccak256Bytes(data));
}

export function keccakUtf8(value) {
  return keccak256Hex(utf8Bytes(value));
}

export function canonicalJsonHash(value) {
  return keccakUtf8(canonicalJson(value));
}

export function typeHash(typeString) {
  return keccakUtf8(typeString);
}

export function typedHash(typeString, fields) {
  return keccak256Hex(abiEncodeStatic([["bytes32", typeHash(typeString)], ...fields]));
}

export function domainSeparatedHash(domain, payloadBytes) {
  return keccak256Hex(concatBytes(keccak_256(utf8Bytes(domain)), payloadBytes));
}

export function domainSeparator(domainName) {
  const domain = DOMAIN_STRINGS[domainName] ?? domainName;
  return keccakUtf8(domain);
}
