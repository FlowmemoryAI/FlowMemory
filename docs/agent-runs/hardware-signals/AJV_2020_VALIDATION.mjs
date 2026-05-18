import fs from "node:fs";
import path from "node:path";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const ajv = new Ajv2020({ allErrors: true, strict: false });
addFormats(ajv);

const readJson = (file) => JSON.parse(fs.readFileSync(file, "utf8"));

function validateDoc(schemaFile, doc, label) {
  const schema = readJson(schemaFile);
  const validate = ajv.compile(schema);
  if (!validate(doc)) {
    console.error(label);
    console.error(validate.errors);
    process.exitCode = 1;
    return;
  }
  console.log(`valid: ${label}`);
}

const raw = readJson("hardware/fixtures/flowrouter_sample_seed42.json");
for (const [name, packet] of Object.entries(raw.packets)) {
  validateDoc(path.join("hardware/simulator/schemas", `${name}.schema.json`), packet, `packet:${name}`);
}

validateDoc(
  "hardware/simulator/schemas/flowchain_operator_signals.schema.json",
  readJson("fixtures/hardware/flowrouter_local_alpha_seed42.json"),
  "operator-signals",
);

validateDoc(
  "schemas/flowmemory/hardware-control-plane-handoff.schema.json",
  readJson("fixtures/hardware/flowrouter_control_plane_handoff_seed42.json"),
  "control-plane-handoff",
);

validateDoc(
  "hardware/simulator/schemas/negative_validation_report.schema.json",
  readJson("fixtures/hardware/flowrouter_negative_validation_seed42.json"),
  "negative-validation-report",
);

if (process.exitCode) {
  process.exit(process.exitCode);
}
