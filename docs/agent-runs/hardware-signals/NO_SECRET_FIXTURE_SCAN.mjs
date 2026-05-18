import fs from "node:fs";

const fixturePaths = [
  "hardware/fixtures/flowrouter_sample_seed42.json",
  "fixtures/hardware/flowrouter_local_alpha_seed42.json",
  "fixtures/hardware/flowrouter_control_plane_handoff_seed42.json",
  "fixtures/hardware/flowrouter_negative_validation_seed42.json",
];

const secretShapedPatterns = [
  new RegExp("BEGIN PRIVATE " + "KEY"),
  new RegExp("PRIVATE_" + "KEY="),
  /MNEMONIC=/,
  /SEED_PHRASE=/,
  /RPC_URL=/,
  /API_KEY=/,
  /WEBHOOK_URL=/,
  /sk_live_/,
  /sk-proj-/,
  /https:\/\/hooks\.slack\.com\/services\//,
];

let failed = false;
for (const filePath of fixturePaths) {
  const body = fs.readFileSync(filePath, "utf8");
  for (const pattern of secretShapedPatterns) {
    if (pattern.test(body)) {
      console.error(`secret-shaped fixture content: ${filePath}: ${pattern}`);
      failed = true;
    }
  }
}

if (failed) {
  process.exit(1);
}

console.log(`no secret-shaped strings in ${fixturePaths.length} generated hardware fixture files`);
