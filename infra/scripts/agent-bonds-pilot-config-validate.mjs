#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import Ajv2020 from "ajv/dist/2020.js";

const root = process.cwd();
const defaultConfigPath = "fixtures/agent-bonds/pilot-config.template.json";
const schemaPath = resolve(root, "schemas/flowmemory/agent-bonds-pilot-config.schema.json");

function unique(values) {
  return new Set(values).size === values.length;
}

function validateRoleSeparation(config) {
  const issues = [];
  const owners = config.roles.multisigOwners;
  if (config.roles.threshold > owners.length) {
    issues.push("threshold cannot exceed multisig owner count");
  }
  if (!unique(owners)) {
    issues.push("multisigOwners must be unique");
  }
  if (!unique(config.roles.verifiers)) {
    issues.push("verifiers must be unique");
  }
  if (!unique(config.roles.confirmingVerifiers)) {
    issues.push("confirmingVerifiers must be unique");
  }
  if (config.roles.pauseGuardian === config.roles.resolutionAuthority) {
    issues.push("pauseGuardian and resolutionAuthority must differ");
  }
  if (owners.includes(config.roles.pauseGuardian)) {
    issues.push("pauseGuardian should be separate from multisig owners for public pilot separation");
  }
  for (const confirmer of config.roles.confirmingVerifiers) {
    if (config.roles.verifiers.includes(confirmer)) {
      issues.push(`confirming verifier ${confirmer} must differ from designated verifiers`);
    }
  }
  const maxPayout = BigInt(config.caps.maxPayoutPerTask);
  const maxExposure = BigInt(config.caps.maxOpenExposure);
  if (maxExposure < maxPayout) {
    issues.push("maxOpenExposure must be at least maxPayoutPerTask");
  }
  if (!config.custody.slitherPassed) {
    issues.push("slitherPassed must be true for public pilot config validation");
  }
  if (config.policy.requiredConfirmations < 1) {
    issues.push("requiredConfirmations must be at least 1 for production-shaped pilot policy");
  }
  return issues;
}

function main() {
  const configPath = resolve(root, process.argv[2] ?? defaultConfigPath);
  const schema = JSON.parse(readFileSync(schemaPath, "utf8"));
  const config = JSON.parse(readFileSync(configPath, "utf8"));
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  const validate = ajv.compile(schema);
  if (!validate(config)) {
    throw new Error(`Agent Bonds pilot config schema validation failed:\n${JSON.stringify(validate.errors, null, 2)}`);
  }
  const issues = validateRoleSeparation(config);
  if (issues.length > 0) {
    throw new Error(`Agent Bonds pilot config role/cap validation failed:\n- ${issues.join("\n- ")}`);
  }
  console.log(JSON.stringify({
    service: "flowmemory-agent-bonds-pilot-config-validate",
    configPath,
    threshold: config.roles.threshold,
    ownerCount: config.roles.multisigOwners.length,
    verifierCount: config.roles.verifiers.length,
    confirmingVerifierCount: config.roles.confirmingVerifiers.length,
    maxPayoutPerTask: config.caps.maxPayoutPerTask,
    maxOpenExposure: config.caps.maxOpenExposure,
    maxOpenTasks: config.caps.maxOpenTasks,
    ok: true,
  }, null, 2));
}

main();
