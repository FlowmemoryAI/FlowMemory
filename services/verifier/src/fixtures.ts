import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import type { ArtifactResolverFixture } from "./verifier.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));

export function loadVerifierArtifactFixture(): ArtifactResolverFixture {
  const path = join(__dirname, "../fixtures/artifacts.json");
  return JSON.parse(readFileSync(path, "utf8")) as ArtifactResolverFixture;
}
