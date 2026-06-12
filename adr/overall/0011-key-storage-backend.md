---
status: proposed
date: 2026-06-10
decision-makers: Stephan Andre, Maximilian Lenkeit, Anselme Tueno
consulted: Robin Winzler, Miyana Stange, Pawel Chmielewski, Damian Jankowski
---

# Key Storage Backend for the Crypto Broker Server

## Context and Problem Statement

The Crypto Broker Server is currently stateless — it stores no secrets and performs only hash and sign certificate operations.
To support symmetric encryption (e.g. AES-GCM), key material must persist securely across requests.
Different deployment environments require different key management systems (KMS), such as openBao or openKMS.
A single, hard-coded key storage implementation would limit the Crypto Broker's flexibility and adoption across diverse infrastructure setups.

## Decision Drivers

* Support for multiple key management backends (openBao, openKMS, etc.)
* Full key lifecycle management (generate, import, rotate, expire, delete/archive)
* Users should be able to choose which backend fits their environment
* Clean separation of concerns between cryptographic operations and key management
* Extensibility for future backend integrations

## Considered Options

* Separate Key Store Service
* Integrated Key Store
* Pluggable KMS Abstraction Layer

## Decision Outcome

Chosen option: "Pluggable KMS Abstraction Layer", because it provides a unified interface for key management while allowing different backend implementations to be swapped in depending on the deployment environment.

### Consequences

* Good, because users can decide which KMS backend to use based on their infrastructure
* Good, because new backends can be added without changing the Crypto Broker core logic
* Good, because the abstraction layer enforces a consistent key lifecycle across all backends
* Bad, because all key features (generate, import, expire, delete/archive, rotate) must be implemented for each backend
* Bad, because higher implementation and maintenance effort compared to a single integrated solution

### Confirmation

TBC

## Pros and Cons of the Options

### Separate Key Store Service

A dedicated key storage service (sidecar or external) that the Crypto Broker connects to via an internal API.

```
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

```
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

### Pluggable KMS Abstraction Layer

An abstraction layer within the Crypto Broker that defines a key management interface.
Multiple backend implementations (openBao, openKMS, file-based, etc.) can be plugged in via configuration.

```
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
                           │ openBao  │ │ openKMS │ │  File /  │
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

## Key Lifecycle

The following key lifecycle must be supported by every backend implementation:

```
 Generate ──> Store ──> Use ──> Expire ──> Delete/Archive
                ▲        │
                │        ▼
         Import └───── Rotate
```

| Phase | Description |
|-------|-------------|
| **Generate** | Backend can create a key per profile constraints (algorithm, size) |
| **Import** | External key material is imported into the backend (depending on profile constraints) |
| **Store** | Key persisted securely, associated with a key-id and metadata |
| **Use** | Key retrieved for encrypt/decrypt operations |
| **Rotate** | New key version created; old version retained for decryption |
| **Expire** | Key marked inactive after TTL or policy; no new encryptions allowed |
| **Delete/Archive** | Key material securely wiped or archived per policy |

## More Information

This ADR is referenced by [ADR 0012 — Encrypt/Decrypt API](0012-encrypt-decrypt-api.md), which defines how the Crypto Broker exposes encryption operations using the key storage backend described here.
