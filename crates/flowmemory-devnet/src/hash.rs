use serde::Serialize;
use serde_json::{Map, Value};
use sha3::{Digest, Keccak256};

pub fn keccak_hex(bytes: &[u8]) -> String {
    let mut hasher = Keccak256::new();
    hasher.update(bytes);
    format!("0x{}", hex::encode(hasher.finalize()))
}

pub fn hash_json<T: Serialize>(domain: &str, value: &T) -> String {
    let canonical = canonical_json(value);
    keccak_hex(format!("{domain}:{canonical}").as_bytes())
}

pub fn canonical_json_hash<T: Serialize>(value: &T) -> String {
    let canonical = canonical_json(value);
    keccak_hex(canonical.as_bytes())
}

pub fn canonical_json<T: Serialize>(value: &T) -> String {
    let value = serde_json::to_value(value).expect("serializable value");
    let normalized = normalize_value(value);
    serde_json::to_string(&normalized).expect("canonical JSON serialization")
}

pub fn normalize_value(value: Value) -> Value {
    match value {
        Value::Array(entries) => Value::Array(entries.into_iter().map(normalize_value).collect()),
        Value::Object(entries) => {
            let mut keys: Vec<String> = entries.keys().cloned().collect();
            keys.sort();

            let mut output = Map::new();
            for key in keys {
                if let Some(value) = entries.get(&key) {
                    output.insert(key, normalize_value(value.clone()));
                }
            }
            Value::Object(output)
        }
        scalar => scalar,
    }
}
