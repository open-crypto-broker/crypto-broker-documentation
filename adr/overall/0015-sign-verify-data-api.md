---
status: proposed
date: 2026-08-21
decision-makers: Stephan Andre, Maximilian Lenkeit, Anselme Tueno
consulted: Robin Winzler, Miyana Stange, Pawel Chmielewski, Damian Jankowski
---

# SignData/VerifyData API for the Crypto Broker Server

## Context and Problem Statement

The Crypto Broker Server currently supports `HashData`, `SignCertificate`, `EncryptData` and `DecryptData` operations via its gRPC interface.
It has no way to produce or verify a digital signature over arbitrary application data (e.g. images, ZIP archives, PDF documents).
To provide this capability, new `SignData` and `VerifyData` RPCs must be added.

Beyond the plain signing operation, the design must account for the ongoing migration to post-quantum cryptography (PQC).
Applications need a smooth transition path that does not force an immediate, all-or-nothing switch from traditional to post-quantum signatures.
The API should therefore offer three signing modes:

* **Legacy** — a traditional signature algorithm only (RSA or ECDSA/EdDSA per [FIPS 186-5](https://csrc.nist.gov/pubs/fips/186-5/final)).
* **Hybrid** — a composite signature that binds a traditional algorithm **and** a post-quantum algorithm (ML-DSA) into a single, atomic signature, so a verifier must validate both components.
* **Post-quantum** — a post-quantum signature algorithm only (ML-DSA per [FIPS 204](https://csrc.nist.gov/pubs/fips/204/final), or SLH-DSA per [FIPS 205](https://csrc.nist.gov/pubs/fips/205/final)).

Like the encryption APIs, signing requires key material. The choice of key input is coupled to whether a key storage backend (KMS) is configured for the active profile, as defined in [ADR 0011](0011-key-storage-backend.md) and [ADR 0014](0014-kms.md). We therefore reuse the `KeySource` model introduced for [EncryptData/DecryptData](0012-encrypt-decrypt-api.md).
Hybrid mode is special: it needs **two** component keys (one traditional, one ML-DSA), so the request must be able to carry a list of key sources.

## Decision Drivers

* Applications need to sign and verify arbitrary opaque data, not just certificates
* Crypto-agility and a PQC migration path must be preserved: legacy, hybrid and post-quantum modes selectable via the profile
* The API must follow established standards (see [More Information](#more-information))
* Key input must work both with and without a KMS, reusing the existing `KeySource` model (caller-managed raw key vs. broker-resolved key id)
* Hybrid mode must carry two component keys (traditional + ML-DSA) under a single request field
* Callers should be able to choose the signature output format
* Records must stay verifiable and migratable across profile changes via the self-describing `descriptor`
* The API should extend the existing gRPC service (`CryptoGrpc`) consistently with the other operations

## Considered Options

* Single fixed signing algorithm (no modes)
* Profile-driven signing with three modes (legacy / hybrid / post-quantum) under one pair of RPCs
* A separate pair of RPCs per mode

## Proposed Solution

"Profile-driven signing with three modes under one pair of RPCs", because it keeps the client-facing surface small and stable while the profile drives the algorithm choice and migration, mirroring how the other Crypto Broker APIs already work.

The API follows the pattern:

```text
signData(profile, sign-key-source, data, [signature-format]) => signature + descriptor
verifyData(profile, sign-key-source, data, signature, [signature-format]) => valid
```

* The **signing mode** (`legacy`, `hybrid`, `post-quantum`) and the concrete algorithms are defined in the profile's `SignData` section, not chosen by the caller. This preserves crypto-agility and lets an operator migrate from legacy to hybrid or post-quantum profiles.
* `sign-key-source` reuses the [`KeySource`](0012-encrypt-decrypt-api.md) `oneof` (`key_id` for KMS-backed profiles, `raw_key` for caller-managed profiles). For **hybrid** mode it carries a list of component keys (`componentKeys`): the traditional key and the ML-DSA key. Legacy and post-quantum modes use a single key.
* `signature-format` is a caller-selectable enum (`RAW`, `DER`, `PEM`, `CMS`). `CMS` produces an [RFC 5652](https://www.rfc-editor.org/rfc/rfc5652) SignedData structure; the others carry the bare signature value in the requested encoding.
* `signData` returns a `descriptor` (profile, operation, concrete algorithm) so the caller can persist it alongside the signature and stay migratable, consistent with the other record-producing APIs.
* `verifyData` returns a boolean `valid` result; a malformed signature or key-source mismatch is reported as a verbose error rather than a silent `false`.

Hybrid mode is realized as a **composite** signature following the *Composite ML-DSA* specification (draft-ietf-lamps-pq-composite-sigs): the traditional and ML-DSA signatures are combined and both must verify ("AND" semantics).
This gives the application defense-in-depth during the PQC transition — it stays secure as long as at least one of the two underlying algorithms remains unbroken.

### Consequences

* Good, because applications gain a standards-based way to sign and verify arbitrary data
* Good, because the three modes provide a controlled, profile-driven PQC migration path
* Good, because reusing `KeySource` keeps signing consistent with encryption and covers both the KMS and no-KMS cases
* Good, because the caller-selectable `signature-format` supports both bare-signature and CMS-container use cases
* Good, because the returned `descriptor` keeps signatures verifiable and migratable across profile changes
* Neutral, because hybrid mode depends on *Composite ML-DSA*, which is still an IETF Internet-Draft (not yet an RFC); the OIDs were early-allocated and the wire format may still change
* Bad, because hybrid mode roughly doubles signature size and signing/verification cost, and requires managing two component keys
* Bad, because supporting three modes and four output formats increases validation and test surface

### Confirmation

To be confirmed by the stakeholders.

## Pros and Cons of the Options

### Single fixed signing algorithm (no modes)

The profile defines exactly one signing algorithm and the API always uses it. No notion of legacy/hybrid/post-quantum.

* Good, because it is the simplest to implement and document
* Bad, because it offers no PQC migration path — switching algorithms is a breaking change for every stored signature
* Bad, because it cannot express defense-in-depth hybrid signatures

### Profile-driven signing with three modes under one pair of RPCs

The profile selects the mode and algorithms; a single `SignData`/`VerifyData` pair serves all three.

* Good, because the client-facing surface stays small and stable across the migration
* Good, because it mirrors the existing profile-driven, crypto-agile design of the other APIs
* Good, because hybrid mode enables defense-in-depth during the transition
* Bad, because the server must handle three modes and, for hybrid, two component keys and a composite algorithm
* Neutral, because it depends on the still-evolving *Composite ML-DSA* draft for the hybrid mode

### A separate pair of RPCs per mode

Distinct RPCs such as `SignDataLegacy`, `SignDataHybrid`, `SignDataPQ`.

* Good, because each RPC has a narrowly typed, mode-specific request
* Bad, because it triples the service surface and pushes algorithm/mode selection into client code, undermining crypto-agility
* Bad, because migrating an application between modes requires client code changes rather than a profile change

## More Information

The API is designed to follow these standards:

* **Legacy signing** — [FIPS 186-5](https://csrc.nist.gov/pubs/fips/186-5/final) (RSA, ECDSA, EdDSA), [RFC 8017](https://www.rfc-editor.org/rfc/rfc8017) (RSASSA-PSS / PKCS#1), [RFC 6979](https://www.rfc-editor.org/rfc/rfc6979) (deterministic ECDSA), [RFC 8032](https://www.rfc-editor.org/rfc/rfc8032) (EdDSA).
* **Post-quantum signing** — [FIPS 204](https://csrc.nist.gov/pubs/fips/204/final) (ML-DSA) with [RFC 9881](https://www.rfc-editor.org/rfc/rfc9881) (X.509 identifiers) and [RFC 9882](https://www.rfc-editor.org/rfc/rfc9882) (ML-DSA in CMS); [FIPS 205](https://csrc.nist.gov/pubs/fips/205/final) (SLH-DSA) with [RFC 9909](https://www.rfc-editor.org/rfc/rfc9909).
* **Hybrid (composite) signing** — draft-ietf-lamps-pq-composite-sigs (*Composite ML-DSA*), with terminology from [RFC 9794](https://www.rfc-editor.org/rfc/rfc9794). [RFC 9763](https://www.rfc-editor.org/rfc/rfc9763) describes the alternative non-composite (parallel certificate) approach that was not chosen.
* **Signature container** — [RFC 5652](https://www.rfc-editor.org/rfc/rfc5652) (CMS SignedData) for the `CMS` output format.

This ADR reuses the `KeySource` model from [ADR 0012 — Encrypt/Decrypt API](0012-encrypt-decrypt-api.md) and depends on the key storage backend defined in [ADR 0011](0011-key-storage-backend.md) and [ADR 0014](0014-kms.md).
