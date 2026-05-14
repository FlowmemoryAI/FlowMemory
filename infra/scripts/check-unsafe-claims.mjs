#!/usr/bin/env node
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const root = process.cwd();
const scanRoots = ["README.md", "docs", "contracts", "marketing"].filter((entry) => existsSync(join(root, entry)));

const forbiddenClaims = [
  { name: "production-ready", pattern: /\bproduction[- ]ready\b/i },
  { name: "mainnet-ready", pattern: /\bmainnet[- ]ready\b/i },
  { name: "production launch", pattern: /\bproduction\s+launch\b/i },
  { name: "mainnet launch", pattern: /\bmainnet\s+launch\b/i },
  { name: "production mainnet", pattern: /\bproduction[- ]mainnet\b/i },
  { name: "production deployment", pattern: /\bproduction\s+deployment\b/i },
  { name: "production L1", pattern: /\bproduction\s+L1\b/i },
  { name: "production verifier network", pattern: /\bproduction\s+verifier\s+network\b/i },
  { name: "production Uniswap hook", pattern: /\bproduction\s+Uniswap\s+v4\s+hook\b|\bproduction\s+hook\s+deployment\b/i },
  { name: "production bridge", pattern: /\bproduction\s+bridge\b/i },
  { name: "production custody", pattern: /\bproduction\s+(wallet\s+)?custody\b/i },
  { name: "audited", pattern: /\baudited\b/i },
  { name: "free storage", pattern: /\bfree\s+storage\b|\bstorage\s+is\s+free\b/i },
  { name: "AI on-chain", pattern: /\bAI\s+(runs|running)\s+on[- ]chain\b|\bon[- ]chain\s+AI\b/i },
  { name: "fully trustless", pattern: /\bfully\s+trustless\b|\bfull\s+trustless\b/i },
  { name: "ISP replacement", pattern: /\breplaces?\s+ISPs?\b/i },
  { name: "normal internet bandwidth", pattern: /\bnormal\s+internet\s+bandwidth\b/i },
];

const allowedLineContext =
  /\b(not|no|never|cannot|can't|do not|does not|without|before|blocked|forbid|forbidden|reject|rejected|avoid|out of scope|non-goal|non-goals|boundary|boundaries|guardrail|guardrails|unsafe claim|not allowed|gated|later gated|blocked until|must not|remain blocked)\b/i;
const allowedHeadingContext =
  /\b(not|non-goal|non-goals|blocked|reject|rejected|guardrail|guardrails|boundary|boundaries|out of scope|conceptual|not implemented|gated|later gated|do not|unsafe|what not to claim|avoid)\b/i;
const startsGuardedList =
  /\b(not allowed|claims that remain blocked|current launch target is not|reject or send back|stop and ask|what not to claim|avoid)\b/i;

function listFiles(entry) {
  const path = join(root, entry);
  if (statSync(path).isFile()) {
    return [path];
  }

  const files = [];
  const stack = [path];
  while (stack.length > 0) {
    const current = stack.pop();
    for (const child of readdirSync(current, { withFileTypes: true })) {
      const childPath = join(current, child.name);
      if (child.isDirectory()) {
        stack.push(childPath);
      } else if (/\.(md|mdx|txt)$/i.test(child.name)) {
        files.push(childPath);
      }
    }
  }
  return files;
}

const violations = [];
for (const file of scanRoots.flatMap(listFiles)) {
  const rel = relative(root, file).replaceAll("\\", "/");
  const lines = readFileSync(file, "utf8").split(/\r?\n/);
  let headingAllowsForbiddenClaims = false;
  let guardedListLinesRemaining = 0;

  lines.forEach((line, index) => {
    const lineContext = [lines[index - 1] ?? "", line, lines[index + 1] ?? ""].join(" ");
    if (/^#{1,6}\s+/.test(line)) {
      headingAllowsForbiddenClaims = allowedHeadingContext.test(line);
    }
    if (allowedHeadingContext.test(line) || startsGuardedList.test(line)) {
      guardedListLinesRemaining = 25;
    }

    for (const claim of forbiddenClaims) {
      if (!claim.pattern.test(line)) {
        continue;
      }
      if (allowedLineContext.test(lineContext) || headingAllowsForbiddenClaims || guardedListLinesRemaining > 0) {
        continue;
      }
      violations.push(`${rel}:${index + 1}: ${claim.name}: ${line.trim()}`);
    }

    if (guardedListLinesRemaining > 0) {
      guardedListLinesRemaining -= 1;
    }
  });
}

if (violations.length > 0) {
  console.error("Unsafe FlowMemory launch claims found:");
  for (const violation of violations) {
    console.error(`- ${violation}`);
  }
  console.error("Rewrite the claim with an explicit boundary, or move it under a guardrail/non-goal section.");
  process.exit(1);
}

console.log(`Checked launch claims in ${scanRoots.join(", ")}.`);
