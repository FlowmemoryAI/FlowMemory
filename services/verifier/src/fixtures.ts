import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import type { ArtifactResolverFixture } from "./verifier.ts";
import { buildTaskScoutFixture, buildTaskScoutVerifierArtifacts } from "../../flowmemory/src/agent-memory.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));

export function loadVerifierArtifactFixture(): ArtifactResolverFixture {
  const path = join(__dirname, "../fixtures/artifacts.json");
  const fixture = JSON.parse(readFileSync(path, "utf8")) as ArtifactResolverFixture;
  const taskScoutFixture = buildTaskScoutFixture();
  return {
    ...fixture,
    artifactsByUri: {
      ...fixture.artifactsByUri,
      ...buildTaskScoutVerifierArtifacts(taskScoutFixture),
    },
  };
}
