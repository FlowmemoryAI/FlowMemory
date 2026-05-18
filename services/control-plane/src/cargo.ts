import { spawnSync, type SpawnSyncOptionsWithStringEncoding, type SpawnSyncReturns } from "node:child_process";
import { mkdirSync } from "node:fs";
import { isAbsolute, relative, resolve } from "node:path";

let cachedToolchain: string | null | undefined;

function uniqueCandidates(): string[] {
  const candidates = [
    process.env.FLOWCHAIN_RUSTUP_TOOLCHAIN,
    process.env.RUSTUP_TOOLCHAIN,
    "1.95.0-x86_64-pc-windows-gnu",
    "stable-x86_64-pc-windows-gnu",
    "stable-x86_64-pc-windows-msvc",
    "stable",
  ];
  return candidates.filter((entry, index): entry is string =>
    typeof entry === "string" &&
    entry.trim().length > 0 &&
    candidates.indexOf(entry) === index,
  );
}

export function resolveCargoToolchain(): string | null {
  if (cachedToolchain !== undefined) {
    return cachedToolchain;
  }

  const defaultCargo = spawnSync("cargo", ["--version"], {
    encoding: "utf8",
    windowsHide: true,
  });
  if (defaultCargo.status === 0) {
    cachedToolchain = null;
    return cachedToolchain;
  }

  for (const toolchain of uniqueCandidates()) {
    const probe = spawnSync("cargo", ["--version"], {
      encoding: "utf8",
      env: {
        ...process.env,
        RUSTUP_TOOLCHAIN: toolchain,
      },
      windowsHide: true,
    });
    if (probe.status === 0) {
      cachedToolchain = toolchain;
      return cachedToolchain;
    }
  }

  cachedToolchain = null;
  return cachedToolchain;
}

export function spawnCargoSync(
  args: string[],
  options: SpawnSyncOptionsWithStringEncoding,
): SpawnSyncReturns<string> {
  const toolchain = resolveCargoToolchain();
  const cwd = typeof options.cwd === "string" ? options.cwd : process.cwd();
  const configuredTargetDir = process.env.FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR;
  const defaultTargetDir = resolve(cwd, "devnet", "local", "cargo-target", "control-plane-runtime");
  const targetDir = configuredTargetDir !== undefined && configuredTargetDir.trim().length > 0
    ? resolve(cwd, configuredTargetDir)
    : defaultTargetDir;
  const tempDir = resolve(cwd, "devnet", "local", "tmp", `control-plane-${process.pid}`);
  const relativeTarget = relative(cwd, targetDir);
  if (relativeTarget === "" || relativeTarget.startsWith("..") || isAbsolute(relativeTarget)) {
    throw new Error("FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR must stay inside the repository.");
  }
  mkdirSync(targetDir, { recursive: true });
  mkdirSync(tempDir, { recursive: true });
  const env = {
    ...process.env,
    ...options.env,
    CARGO_TARGET_DIR: options.env?.CARGO_TARGET_DIR ?? process.env.CARGO_TARGET_DIR ?? targetDir,
    FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR: options.env?.FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR ?? targetDir,
    TEMP: options.env?.TEMP ?? process.env.TEMP ?? tempDir,
    TMP: options.env?.TMP ?? process.env.TMP ?? tempDir,
    ...(toolchain === null
      ? {}
      : {
          FLOWCHAIN_RUSTUP_TOOLCHAIN: toolchain,
          RUSTUP_TOOLCHAIN: toolchain,
        }),
  };

  return spawnSync("cargo", args, {
    ...options,
    env,
    encoding: options.encoding ?? "utf8",
    windowsHide: options.windowsHide ?? true,
  });
}

export function cargoDisplayCommand(args: string[]): string {
  const toolchain = resolveCargoToolchain();
  const cargo = toolchain === null ? "cargo" : `cargo +${toolchain}`;
  return `${cargo} ${args.join(" ")}`;
}
