#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const zeroAddress = /^0x0{40}$/i;
const pendingPattern = /PENDING/i;

function readJson(path) {
  return JSON.parse(readFileSync(resolve(root, path), "utf8"));
}

function isMissingAddress(value) {
  return typeof value !== "string" || zeroAddress.test(value);
}

function isPending(value) {
  return typeof value !== "string" || pendingPattern.test(value);
}

function item(name, status, value, note = null) {
  return { name, status, value, note };
}

function main() {
  const ownerInputsPath = process.argv[2] ?? "fixtures/agent-bonds/owner-inputs.template.json";
  const liveReferencesPath = process.argv[3] ?? "fixtures/agent-bonds/discovered-live-references.json";
  const ownerInputs = readJson(ownerInputsPath);
  const liveReferences = readJson(liveReferencesPath);

  const contractItems = Object.entries(ownerInputs.contracts).map(([name, value]) =>
    item(`contracts.${name}`, isMissingAddress(value) ? "missing" : "present", value),
  );

  const multisigOwners = ownerInputs.roles.multisigOwners.map((value, index) =>
    item(`roles.multisigOwners[${index}]`, isMissingAddress(value) ? "missing" : "present", value),
  );
  const roleItems = [
    ...multisigOwners,
    ...Object.entries(ownerInputs.roles)
      .filter(([name]) => name !== "multisigOwners" && name !== "threshold")
      .map(([name, value]) => item(`roles.${name}`, isMissingAddress(value) ? "missing" : "present", value)),
    item("roles.threshold", ownerInputs.roles.threshold >= 2 ? "present" : "invalid", ownerInputs.roles.threshold),
  ];

  const signoffItems = Object.entries(ownerInputs.signoffs).map(([name, value]) =>
    item(`signoffs.${name}`, isPending(value) ? "missing" : "present", value),
  );

  const unresolved = [
    ...contractItems.filter((entry) => entry.status !== "present"),
    ...roleItems.filter((entry) => entry.status !== "present"),
    ...signoffItems.filter((entry) => entry.status !== "present"),
  ];

  const knownLiveAddress = liveReferences?.deployer?.address ?? null;
  const knownReferenceMatches = [];
  if (knownLiveAddress) {
    if (ownerInputs.roles.requester === knownLiveAddress) {
      knownReferenceMatches.push("roles.requester matches discovered live canary deployer");
    }
    if (ownerInputs.roles.multisigOwners.includes(knownLiveAddress)) {
      knownReferenceMatches.push("one multisig owner slot matches discovered live canary deployer");
    }
  }

  console.log(JSON.stringify({
    service: "flowmemory-agent-bonds-owner-inputs-status",
    ownerInputsPath: resolve(root, ownerInputsPath),
    liveReferencesPath: resolve(root, liveReferencesPath),
    knownLiveAddress,
    knownReferenceMatches,
    counts: {
      contractsPresent: contractItems.filter((entry) => entry.status === "present").length,
      rolesPresent: roleItems.filter((entry) => entry.status === "present").length,
      signoffsPresent: signoffItems.filter((entry) => entry.status === "present").length,
      unresolved: unresolved.length,
    },
    contracts: contractItems,
    roles: roleItems,
    signoffs: signoffItems,
    unresolved,
  }, null, 2));
}

main();
