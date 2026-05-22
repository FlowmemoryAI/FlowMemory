# Future zk And Proof-Carrying Receipt Roadmap

Status: research draft.

This roadmap identifies what could become proof-carrying and what should remain verifier-attested in the MVP.

## MVP Must Remain Verifier-Attested

The MVP should rely on deterministic verifier reports, not zk proofs, for:

- chain finality policy and reorg handling
- RPC/indexer data source agreement
- URI and storage locator policy
- artifact availability sampling
- worker behavior and model output quality
- storage provider claims
- key registry and verifier set governance
- challenge response review

These claims can be signed, challenged, and replayed. They are not trustless.

## First Proof Candidates

Good early zk candidates have small, deterministic public inputs:

- Merkle inclusion for artifact chunks.
- Artifact root recomputation from a manifest hash and chunk openings.
- Receipt consistency from `observationId`, `eventArgsHash`, `artifactRoot`, and `storageReceiptCommitment`.
- Verifier report consistency for a fixed set of boolean checks.
- Rootflow aggregation of ordered receipt hashes.

## Harder Proof Candidates

These require more research:

- proving a full transaction receipt/log was canonical without trusting an indexer
- proving off-chain data availability over time
- proving model output correctness
- proving private metadata policy compliance
- proving hardware identity without a trusted manufacturing or key enrollment process

## Proof-Carrying Receipt Shape

A future proof-carrying receipt should keep the v0 receipt hash as a stable public input:

```text
public inputs:
  schemaId
  chainId
  observationId
  eventArgsHash
  receiptHash
  artifactRoot
  storageReceiptCommitment
  verifierPolicyHash
  reportSchemaHash
```

Witnesses may include:

- event args
- artifact manifest
- Merkle opening path
- storage receipt opening
- check result details
- worker or verifier signature preimages

The proof should not force private artifact bytes public unless the challenge or disclosure policy requires it.

## Recursive Aggregation Path

1. Prove one receipt is internally consistent.
2. Prove a batch of receipts share an accepted schema and verifier policy.
3. Prove a Rootflow checkpoint aggregates a batch.
4. Attach the checkpoint to a Rootfield state commitment.
5. Consider local runtime/network settlement only after proof cost, data availability, and governance are understood.

## Go/No-Go Criteria

Before implementing zk circuits, FlowMemory should have:

- accepted observation identity
- accepted receipt and report schemas
- deterministic verifier reference implementation
- cross-language test vectors
- exact public input list
- exact witness privacy rules
- proof system choice and setup assumptions
- cost model versus ordinary verifier replay
- challenge model for failed or missing proofs

Until those exist, zk is research, not product or protocol infrastructure.
