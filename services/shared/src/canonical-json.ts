type JsonValue = null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue | undefined };

function normalize(value: JsonValue): JsonValue {
  if (value === null || typeof value !== "object") {
    return value;
  }

  if (Array.isArray(value)) {
    return value.map((entry) => normalize(entry));
  }

  const output: { [key: string]: JsonValue } = {};
  for (const key of Object.keys(value).sort()) {
    const entry = value[key];
    if (entry !== undefined) {
      output[key] = normalize(entry);
    }
  }
  return output;
}

export function canonicalJson(value: JsonValue): string {
  return JSON.stringify(normalize(value));
}

