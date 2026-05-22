#!/usr/bin/env node

const BASE_CHAIN_ID = 8453;
const OPERATOR_ACK_VALUE = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT";
const MAX_SINGLE_DEPOSIT_WEI = 100000000000000n;
const MAX_TOTAL_CAP_WEI = 1000000000000000n;
const REQUIRED_ENV_NAMES = Object.freeze([
  "FLOWMEMORY_PILOT_OPERATOR_ACK",
  "FLOWMEMORY_BASE8453_RPC_URL",
  "FLOWMEMORY_BASE8453_LOCKBOX_ADDRESS",
  "FLOWMEMORY_BASE8453_FROM_BLOCK",
  "FLOWMEMORY_BASE8453_TO_BLOCK",
  "FLOWMEMORY_PILOT_MAX_DEPOSIT_WEI",
  "FLOWMEMORY_PILOT_TOTAL_CAP_WEI",
  "FLOWMEMORY_PILOT_WITHDRAWAL_RECIPIENT",
  "FLOWMEMORY_PILOT_MAX_USD"
]);

const command = process.argv[2] ?? "env";
const args = parseArgs(process.argv.slice(3));

try {
  if (command === "env") {
    printJson({
      schema: "flowmemory.wallet_operator.base8453_env_names.v0",
      baseChainId: BASE_CHAIN_ID,
      operatorAckRequiredValue: OPERATOR_ACK_VALUE,
      requiredEnvNames: REQUIRED_ENV_NAMES,
      dryRunCommand: "npm run wallet:operator-bridge --prefix crypto -- env",
      liveValidationCommand: "npm run wallet:operator-bridge --prefix crypto -- validate --live",
      boundary: "Env names only. Secret values are read from the local shell and are never printed."
    });
  } else if (command === "validate") {
    const result = await validateOperatorEnv({ live: args.live === true || args.live === "true" });
    printJson(result);
    process.exitCode = result.valid ? 0 : 1;
  } else if (command === "prepare-deposit-evidence") {
    printJson(prepareDepositEvidence());
  } else if (command === "prepare-release-evidence") {
    printJson(prepareReleaseEvidence());
  } else {
    usage();
    process.exitCode = 1;
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}

async function validateOperatorEnv({ live }) {
  const errors = [];
  const envPresence = Object.fromEntries(REQUIRED_ENV_NAMES.map((name) => [name, hasEnv(name)]));
  const lockbox = envValue("FLOWMEMORY_BASE8453_LOCKBOX_ADDRESS");
  const lockboxAddressValid = !lockbox || isEthAddress(lockbox);
  if (!lockboxAddressValid) {
    errors.push("bad-lockbox-address");
  }
  const withdrawalRecipient = envValue("FLOWMEMORY_PILOT_WITHDRAWAL_RECIPIENT");
  const withdrawalRecipientValid = !withdrawalRecipient || isEthAddress(withdrawalRecipient);
  if (!withdrawalRecipientValid) {
    errors.push("bad-withdrawal-recipient");
  }
  const capResult = validateCaps();
  errors.push(...capResult.errors);
  const operatorAckPresent = envValue("FLOWMEMORY_PILOT_OPERATOR_ACK") === OPERATOR_ACK_VALUE;
  if (!operatorAckPresent && live) {
    errors.push("missing-operator-ack");
  }

  let chainIdValid = live ? false : null;
  if (live) {
    if (!hasEnv("FLOWMEMORY_BASE8453_RPC_URL")) {
      errors.push("missing-rpc-url");
    } else {
      chainIdValid = await validateBaseChainId(envValue("FLOWMEMORY_BASE8453_RPC_URL"));
      if (!chainIdValid) {
        errors.push("wrong-chain-id");
      }
    }
  }

  return {
    schema: "flowmemory.wallet_operator.base8453_validation.v0",
    valid: errors.length === 0,
    live,
    baseChainId: BASE_CHAIN_ID,
    envPresence,
    rpcConfigured: hasEnv("FLOWMEMORY_BASE8453_RPC_URL"),
    rpcValuePrinted: false,
    chainIdValid,
    lockboxAddressValid,
    withdrawalRecipientValid,
    capCheck: capResult.check,
    operatorAckPresent,
    dryRunCommands: dryRunCommands(),
    liveCommands: liveCommands(),
    errors: [...new Set(errors)]
  };
}

function prepareDepositEvidence() {
  const lockbox = args["lockbox-address"] || envValue("FLOWMEMORY_BASE8453_LOCKBOX_ADDRESS") || "<FLOWMEMORY_BASE8453_LOCKBOX_ADDRESS>";
  if (!lockbox.startsWith("<") && !isEthAddress(lockbox)) {
    throw new Error("lockbox address must be a 20-byte hex address");
  }
  return {
    schema: "flowmemory.wallet_operator.bridge_deposit_evidence_commands.v0",
    baseChainId: BASE_CHAIN_ID,
    lockboxAddressFormat: lockbox.startsWith("<") ? "placeholder" : "valid",
    requiredEnvNames: REQUIRED_ENV_NAMES,
    dryRunCommands: [
      "npm run wallet:operator-bridge --prefix crypto -- env",
      "npm run wallet:operator-bridge --prefix crypto -- validate"
    ],
    liveCommands: [
      "npm run wallet:operator-bridge --prefix crypto -- validate --live",
      "npm run flowmemory:real-value-pilot -- --Mode Live --Action Observe"
    ],
    evidenceOutputs: [
      "local-runtime/local/real-value-pilot/evidence/base8453-observation.json",
      "local-runtime/local/real-value-pilot/evidence/base8453-credit-pending.json",
      "local-runtime/local/real-value-pilot/evidence/base8453-handoff-pending.json"
    ],
    rpcValuePrinted: false,
    broadcast: false
  };
}

function prepareReleaseEvidence() {
  const recipient = args["base-recipient"] || envValue("FLOWMEMORY_PILOT_WITHDRAWAL_RECIPIENT") || "<FLOWMEMORY_PILOT_WITHDRAWAL_RECIPIENT>";
  if (!recipient.startsWith("<") && !isEthAddress(recipient)) {
    throw new Error("withdrawal recipient must be a 20-byte Base address");
  }
  return {
    schema: "flowmemory.wallet_operator.bridge_release_evidence_commands.v0",
    baseChainId: BASE_CHAIN_ID,
    recipientAddressFormat: recipient.startsWith("<") ? "placeholder" : "valid",
    requiredEnvNames: REQUIRED_ENV_NAMES,
    dryRunCommands: [
      "npm run wallet:operator-bridge --prefix crypto -- validate",
      "npm run wallet:e2e --prefix crypto"
    ],
    liveCommands: [
      "npm run wallet:operator-bridge --prefix crypto -- validate --live",
      "npm run flowmemory:real-value-pilot -- --Mode Live --Action Withdraw",
      "npm run flowmemory:real-value-pilot:export"
    ],
    evidenceOutputs: [
      "local-runtime/local/real-value-pilot/evidence/base8453-withdrawal-intent.json",
      "local-runtime/local/real-value-pilot/evidence/base8453-handoff-with-withdrawal.json"
    ],
    rpcValuePrinted: false,
    broadcast: false
  };
}

async function validateBaseChainId(rpcUrl) {
  let url;
  try {
    url = new URL(rpcUrl);
  } catch {
    throw new Error("FLOWMEMORY_BASE8453_RPC_URL must be an absolute HTTP(S) URL");
  }
  if (!["http:", "https:"].includes(url.protocol)) {
    throw new Error("FLOWMEMORY_BASE8453_RPC_URL must use HTTP(S)");
  }
  let response;
  try {
    response = await fetch(rpcUrl, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_chainId", params: [] })
    });
  } catch {
    throw new Error("could not read eth_chainId from FLOWMEMORY_BASE8453_RPC_URL; endpoint value was not printed");
  }
  const body = await response.json();
  if (body.error || typeof body.result !== "string" || !/^0x[0-9a-fA-F]+$/.test(body.result)) {
    throw new Error("eth_chainId returned an invalid response; endpoint value was not printed");
  }
  return Number.parseInt(body.result.slice(2), 16) === BASE_CHAIN_ID;
}

function validateCaps() {
  const errors = [];
  const maxDeposit = parseOptionalUint("FLOWMEMORY_PILOT_MAX_DEPOSIT_WEI");
  const totalCap = parseOptionalUint("FLOWMEMORY_PILOT_TOTAL_CAP_WEI");
  if (maxDeposit === null || totalCap === null) {
    errors.push("missing-cap-values");
  } else {
    if (maxDeposit <= 0n || maxDeposit > MAX_SINGLE_DEPOSIT_WEI) {
      errors.push("bad-max-deposit-cap");
    }
    if (totalCap <= 0n || totalCap > MAX_TOTAL_CAP_WEI || totalCap < maxDeposit) {
      errors.push("bad-total-cap");
    }
  }
  return {
    errors,
    check: {
      configured: maxDeposit !== null && totalCap !== null,
      maxDepositWei: maxDeposit?.toString() ?? null,
      totalCapWei: totalCap?.toString() ?? null,
      maxSingleDepositLimitWei: MAX_SINGLE_DEPOSIT_WEI.toString(),
      totalCapLimitWei: MAX_TOTAL_CAP_WEI.toString()
    }
  };
}

function parseOptionalUint(name) {
  const value = envValue(name);
  if (!value) {
    return null;
  }
  if (!/^[0-9]+$/.test(value)) {
    return -1n;
  }
  return BigInt(value);
}

function dryRunCommands() {
  return [
    "npm run wallet:operator-bridge --prefix crypto -- env",
    "npm run wallet:operator-bridge --prefix crypto -- validate",
    "npm run wallet:operator-bridge --prefix crypto -- prepare-deposit-evidence",
    "npm run wallet:operator-bridge --prefix crypto -- prepare-release-evidence"
  ];
}

function liveCommands() {
  return [
    "npm run wallet:operator-bridge --prefix crypto -- validate --live",
    "npm run flowmemory:real-value-pilot -- --Mode Live --Action Observe",
    "npm run flowmemory:real-value-pilot -- --Mode Live --Action Withdraw"
  ];
}

function hasEnv(name) {
  return envValue(name) !== "";
}

function envValue(name) {
  return process.env[name] ?? "";
}

function isEthAddress(value) {
  return /^0x[0-9a-fA-F]{40}$/.test(value);
}

function parseArgs(argv) {
  const parsed = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith("--")) {
      continue;
    }
    const key = arg.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith("--")) {
      parsed[key] = true;
    } else {
      parsed[key] = next;
      i += 1;
    }
  }
  return parsed;
}

function printJson(value) {
  console.log(JSON.stringify(value, null, 2));
}

function usage() {
  console.error(`Usage:
  node src/operator-bridge-cli.js env
  node src/operator-bridge-cli.js validate [--live]
  node src/operator-bridge-cli.js prepare-deposit-evidence [--lockbox-address <0x...>]
  node src/operator-bridge-cli.js prepare-release-evidence [--base-recipient <0x...>]`);
}
