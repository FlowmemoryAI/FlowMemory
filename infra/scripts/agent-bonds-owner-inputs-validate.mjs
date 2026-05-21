#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import Ajv2020 from "ajv/dist/2020.js";

const root = process.cwd();
const schemaPath = resolve(root, "schemas/flowmemory/agent-bonds-owner-inputs.schema.json");
const defaultConfigPath = "fixtures/agent-bonds/owner-inputs.template.json";
const zeroAddress = /^0x0{40}$/i;

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function isPending(value) {
  return typeof value === "string" && /PENDING/i.test(value);
}

function main() {
  const configPath = resolve(root, process.argv[2] ?? defaultConfigPath);
  const schema = readJson(schemaPath);
  const config = readJson(configPath);
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  const validate = ajv.compile(schema);
  if (!validate(config)) {
    throw new Error(`Agent Bonds owner inputs schema validation failed:\n${JSON.stringify(validate.errors, null, 2)}`);
  }

  const issues = [];
  for (const [name, value] of Object.entries(config.contracts)) {
    if (typeof value === "string" && zeroAddress.test(value)) {
      issues.push(`contracts.${name} must be a real deployed address`);
    }
  }
  for (const [name, value] of Object.entries(config.roles)) {
    if (Array.isArray(value)) {
      for (const [index, entry] of value.entries()) {
        if (typeof entry === "string" && zeroAddress.test(entry)) {
          issues.push(`roles.${name}[${index}] must be a real operator address`);
        }
      }
    } else if (typeof value === "string" && zeroAddress.test(value)) {
      issues.push(`roles.${name} must be a real operator address`);
    }
  }
  if (config.roles.threshold > config.roles.multisigOwners.length) {
    issues.push("roles.threshold cannot exceed multisigOwners length");
  }
  if (new Set(config.roles.multisigOwners).size !== config.roles.multisigOwners.length) {
    issues.push("roles.multisigOwners must be unique");
  }
  if (config.roles.designatedVerifier === config.roles.confirmingVerifier) {
    issues.push("roles.confirmingVerifier must differ from roles.designatedVerifier");
  }
  if (config.roles.pauseGuardian === config.roles.resolutionAuthority) {
    issues.push("roles.pauseGuardian must differ from roles.resolutionAuthority");
  }
  if (BigInt(config.caps.maxOpenExposure) < BigInt(config.caps.maxPayoutPerTask)) {
    issues.push("caps.maxOpenExposure must be at least caps.maxPayoutPerTask");
  }
  for (const [name, value] of Object.entries(config.signoffs)) {
    if (isPending(value)) {
      issues.push(`signoffs.${name} must be filled with a real person or firm`);
    }
  }

  if (issues.length > 0) {
    throw new Error(`Agent Bonds owner inputs validation failed:\n- ${issues.join("\n- ")}`);
  }

  console.log(JSON.stringify({
    service: "flowmemory-agent-bonds-owner-inputs-validate",
    configPath,
    ok: true,
  }, null, 2));
}

main();
