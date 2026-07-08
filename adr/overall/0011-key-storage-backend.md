---
status: proposed
date: 2026-06-10
decision-makers: Stephan Andre, Maximilian Lenkeit, Anselme Tueno
consulted: Robin Winzler, Miyana Stange, Pawel Chmielewski, Damian Jankowski
---

# Key Storage Backend for the Crypto Broker Server

## Context and Problem Statement

The Crypto Broker Server is currently stateless — it stores no secrets and performs only hash and sign certificate operations.
For other cryptographic operations which require longer-living materials a key management system (KMS) is needed.
There are fundamentally two ways to make this material available, and which one applies depends on who owns the cryptographic material and the responsibility for managing it (the Crypto Broker operator vs. the calling application):

* **Caller-managed (no KMS):** The application passes all required material (e.g. raw key, nonce, AAD, ...) with every call.
  In this mode the Crypto Broker stores nothing and effectively acts as a thin, algorithm-specific wrapper.
  Securely managing and persisting the key material is fully delegated to the caller, so no key storage backend is required.
* **Broker-managed (KMS-backed):** A KMS holds the key material on behalf of the application.
  This enables a more algorithm-agnostic API where the application supplies only a key-id (and optionally a minimal set of parameters), while the Crypto Broker derives or manages the remaining material (e.g. nonce, AAD) itself.
  This requires key material to persist securely across requests, and different deployment environments require different key management systems (KMS), such as OpenBao or OpenKCM.

Whether a KMS is used is therefore not a global, hard-coded property of the Crypto Broker but a per-**profile** decision:

* If a profile specifies **no KMS**, the Crypto Broker cannot store anything; for encrypt/decrypt operations the application must provide all material (raw key, nonce, AAD).
* If a profile specifies a **KMS**, a hybrid approach becomes possible: the application references key material via a key-id and the Crypto Broker provides/manages the remaining parameters (e.g. nonce, AAD).

This ADR therefore needs to decide how the Crypto Broker integrates an **optional** key storage backend, such that profiles requiring a KMS can select among multiple implementations, while profiles without a KMS keep the broker stateless.
A single, hard-coded key storage implementation would limit the Crypto Broker's flexibility and adoption across diverse infrastructure setups.

## Decision Drivers

* KMS support must be optional and selectable per profile (caller-managed vs. broker-managed)
* Support for multiple key management backends (OpenBao, OpenKCM, etc.)
* Users should be able to choose which backend fits their environment
* Clean separation of concerns between cryptographic operations and key management
* Extensibility for future backend integrations

## Considered Options

* Separate Key Store Service
* Integrated Key Store
* Pluggable KMS Abstraction Layer

## Decision Outcome

Chosen option: "Pluggable KMS Abstraction Layer", because it provides a unified interface for key management while allowing different backend implementations to be swapped in depending on the deployment environment.
The abstraction layer is engaged only when a profile selects a KMS; profiles without a KMS keep the Crypto Broker stateless and rely on caller-managed key material.

### Consequences

* Good, because users can decide which KMS backend to use based on their infrastructure
* Good, because KMS support stays optional and is driven per profile (caller-managed or broker-managed)
* Good, because new backends can be added without changing the Crypto Broker core logic
* Good, because the abstraction layer enforces a consistent key lifecycle across all backends
* Bad, because all key features (generate, import, expire, delete/archive, rotate) must be implemented for each backend
* Bad, because higher implementation and maintenance effort compared to a single integrated solution

### Confirmation

Confirmed by the stakeholders on 2026-06-17.

## Pros and Cons of the Options

### Separate Key Store Service

A dedicated key storage service (sidecar or external) that the Crypto Broker connects to via an internal API.

```ascii
┌─────────────┐  gRPC   ┌──────────────────┐  Internal API  ┌────────────────┐
│ Application │───────> │ Crypto Broker    │──────────────> │ Key Store      │
│             │         │ Server           │                │ Service        │
└─────────────┘         └──────────────────┘                └───────┬────────┘
                                                                    │
                                                                    ▼
                                                             ┌───────────────┐
                                                             │   Storage     │
                                                             │ (encrypted)   │
                                                             └───────────────┘
```

* Good, because the Crypto Broker Server remains stateless for crypto operations
* Good, because the key store can be scaled independently
* Neutral, because it could wrap existing solutions (HashiCorp Vault, K8s Secrets)
* Bad, because it introduces an additional service to deploy and secure
* Bad, because API needed for key retrieval
* Bad, because in a sidecar model, two sidecars would be needed

### Integrated Key Store

The Crypto Broker Server gains statefulness and manages keys internally in local storage.

```ascii
┌─────────────┐  gRPC   ┌──────────────────────────┐
│ Application │───────> │ Crypto Broker Server     │
│             │         │ + Integrated Key Store   │
└─────────────┘         └────────────┬─────────────┘
                                     │
                                     ▼
                             ┌───────────────┐
                             │ Local Storage │
                             │ (encrypted)   │
                             └───────────────┘
```

* Good, because it is simple to deploy (single binary, no extra service)
* Good, because no API for key retrieval needed
* Good, because it fits the sidecar model well (single sidecar)
* Bad, because the server becomes stateful, making horizontal scaling harder
* Bad, because it tightly couples key storage to the broker process
* Bad, because switching to a different storage backend requires changes in the server itself
* Bad, because it inevitably requires the party operating the Crypto Broker Server to be able to operate a key store securely

### Pluggable KMS Abstraction Layer

An abstraction layer within the Crypto Broker that defines a key management interface.
Multiple backend implementations (OpenBao, OpenKCM, file-based, etc.) can be plugged in via configuration.

```ascii
┌─────────────┐  gRPC   ┌──────────────────────────────────────┐
│ Application │───────> │ Crypto Broker Server                 │
│             │         │                                      │
└─────────────┘         │  ┌────────────────────────────────┐  │
                        │  │ Key Management Interface       │  │
                        │  └──────┬─────────┬───────────┬───┘  │
                        └─────────┼─────────┼───────────┼──────┘
                                  │         │           │
                                  ▼         ▼           ▼
                           ┌──────────┐ ┌─────────┐ ┌──────────┐
                           │ OpenBao  │ │ OpenKCM │ │  File /  │
                           │          │ │         │ │  Other   │
                           └──────────┘ └─────────┘ └──────────┘
```

* Good, because users can choose their preferred KMS backend
* Good, because new backends can be added without modifying the core server
* Good, because the interface enforces a consistent API for key operations across all backends
* Good, because it keeps the Crypto Broker Server itself lightweight
* Bad, because every key lifecycle operation must be implemented per backend
* Bad, because higher implementation and maintenance effort
* Bad, because backend-specific quirks may leak through the abstraction

## More Information

This ADR is referenced by [ADR 0012 — Encrypt/Decrypt API](0012-encrypt-decrypt-api.md), which defines how the Crypto Broker exposes encryption operations using the key storage backend described here.
