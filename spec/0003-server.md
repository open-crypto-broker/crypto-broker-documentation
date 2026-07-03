# Crypto Broker Server Specification

## Overview

The Crypto Broker server provides remote cryptographic operations over gRPC, including:

- Hashing arbitrary binary data.
- Signing X.509 certificates based on Certificate Signing Requests (CSRs).

This specification describes the observable behavior and processing contract of the Crypto Broker server: the services it exposes, how it processes and validates requests, the security guarantees it provides, and how it can be operated and observed.

It is intentionally implementation-agnostic. It does not describe the internal package layout, data structures or function signatures of any particular implementation, so that it remains valid as the implementation evolves. The reference implementation is written in `Go`; implementation-specific details are documented in the [Crypto Broker Server repository](https://github.com/open-crypto-broker/crypto-broker-server).

The server does not expose cryptographic functionality directly. Instead, it validates every request against a predefined profile and delegates approved operations to an underlying cryptographic backend.

---

## Transport and Connection

- The server listens for gRPC requests over a Unix domain socket.
- The socket path is `/tmp/open-crypto-broker/crypto-broker-server.sock`.
- The socket is created with owner-only permissions (`0600`), restricting access to the user running the server.
- On startup, the server ensures the socket directory exists and removes any stale socket file left behind by a previous run. On shutdown, the socket file is cleaned up.

The server expects connections from clients using a compatible language-specific Crypto Broker library, as described in the [Crypto Broker Library Specification](https://github.com/open-crypto-broker/crypto-broker-documentation/blob/main/spec/0002-library.md).
All incoming requests are validated, logged, and processed in accordance with the security policies defined in the applicable profile.
The server returns a response to the requested cryptographic operation, or an error if the request could not be handled.
Error reporting is verbose: in case of failure, the client is informed which stage of the operation failed (see [Error Handling](#error-handling)).

---

## Exposed gRPC Services

The server exposes the gRPC services defined in the shared Protobuf definitions. The message formats for every request and response are specified in the [Crypto Broker Library Specification](https://github.com/open-crypto-broker/crypto-broker-documentation/blob/main/spec/0002-library.md) and are not repeated here.

### Production service (`CryptoGrpc`)

The production service is always available and exposes the cryptographic operations used by client applications:

- `HashData` — computes a cryptographic hash over arbitrary input using the algorithm defined in the selected profile.
- `SignCertificate` — issues an X.509 certificate from a CSR using the credentials and constraints defined in the selected profile.

### Development service (`CryptoGrpcDev`)

The development/diagnostics service exposes endpoints that are **not** intended for production application use:

- `Benchmark` — runs a dedicated benchmark inside the server.
- `FakeEndpoint` — a minimal endpoint used for testing and connectivity checks.

This service is only registered when the server is started in a development environment (see [Configuration](#configuration)). In production deployments it is disabled and not reachable.

### Health checking

The server registers the standard [gRPC health checking service](https://grpc.io/docs/guides/health-checking/), which clients and orchestrators can use to probe server readiness and liveness.

---

## Request Processing Model

Every production cryptographic request is processed through the following stages:

1. **Receive** — the request is received over the gRPC connection. Message size limits are enforced before further processing (see [Input Validation and Constraints](#input-validation-and-constraints)).
1. **Resolve profile** — the profile named in the request is retrieved from the set of profiles loaded at startup. An unknown profile name results in an error.
1. **Validate input** — the request payload is validated against the rules of the resolved profile. This includes parsing cryptographic material (CSR, CA certificate, private key) and checking it against profile constraints.
1. **Execute** — the approved operation is delegated to the cryptographic backend, which performs the hashing or certificate signing using the algorithm and parameters selected by the profile.
1. **Respond** — the result is packaged into the corresponding response message together with request metadata and returned to the client. On failure, a verbose error is returned instead.

The server does not perform cryptographic operations that are not authorized by a profile, and it never selects algorithms or parameters that are not permitted by the resolved profile.

---

## Profiles

Profiles are the central policy mechanism of the server. Each profile defines which cryptographic operations are allowed and under which constraints (algorithms, key-size limits, certificate validity boundaries, key usages, and so on). The profile structure is defined in the [Crypto Broker Profile Specification](https://github.com/open-crypto-broker/crypto-broker-documentation/blob/main/spec/0001-profile.md).

- Profiles are loaded and validated once at startup from a YAML file (`Profiles.yaml`). The directory containing this file is provided via configuration.
- Loading fails fast: if the file cannot be read, parsed, or if any profile is invalid or references unsupported values, the server does not start.
- At request time, a profile is retrieved by its name. Requests that reference an unknown profile are rejected.
- Profile names are validated and bounded in length.

---

## Input Validation and Constraints

The server validates requests at two levels before any cryptographic operation is performed.

### Transport-level limits

- Incoming and outgoing gRPC message sizes are bounded to protect the server from oversized payloads.
- The number of concurrent streams is bounded and configurable.

### Profile-level validation

Depending on the requested operation, the server validates that:

- The requested profile exists and is valid.
- The requested algorithm is supported and permitted by the profile.
- For `SignCertificate`:
    - The CSR, CA certificate and CA private key are well-formed and can be parsed.
    - The CA public key matches the CA private key.
    - The signature algorithm in the profile is compatible with the provided key.
    - The subject's public key and the issuer's private key satisfy the key-size constraints defined in the profile.
    - The requested certificate validity lies within the boundaries permitted by the profile.

Requests that violate any of these rules are rejected with a verbose error identifying the failed check.

---

## Supported Algorithms

The following algorithms are supported by the server. A given request may only use an algorithm if the selected profile permits it.

### Hashing (`HashData`)

- SHA-256, SHA-384, SHA-512
- SHA-512/256
- SHA3-256, SHA3-384, SHA3-512
- SHAKE128, SHAKE256 (extendable-output functions with a fixed output size)

### Certificate signing (`SignCertificate`)

- Signature algorithms: RSA, ECDSA
- Hash algorithms used for signing: SHA-256, SHA-384, SHA-512

---

## Security Posture

The server is designed to enforce cryptographic policy and to minimize exposure:

- **Access control** — the Unix domain socket is created with owner-only permissions (`0600`), so only the user running the server may connect.
- **Policy enforcement** — no cryptographic operation is performed unless it is explicitly permitted by a profile. Algorithms, key sizes and certificate validity are constrained by the profile.
- **Resource limits** — request and response message sizes and the number of concurrent streams are bounded to reduce the impact of abusive or malformed traffic.
- **Reduced production surface** — the development service (`CryptoGrpcDev`) is only registered in development environments and is disabled in production.
- **Sensitive material handling** — sensitive key material is zeroized in memory once it is no longer needed.

### FIPS 140 mode

The reference implementation can be built and run in a FIPS 140 mode, in which cryptographic operations are performed by a FIPS-validated cryptographic module rather than the default, unvalidated implementation. This is governed by two independent levers:

- **Build time** — selection of the FIPS-validated cryptographic module linked into the binary.
- **Runtime** — whether the FIPS module is merely enabled or strictly enforced.

The server reports its FIPS mode status on startup so operators can confirm the deployed configuration. Detailed guidance on enabling and enforcing FIPS 140 is provided in the server repository's [FIPS documentation](https://github.com/open-crypto-broker/crypto-broker-server/blob/main/docs/fips.md).

---

## Observability

The server is instrumented for distributed tracing and metrics using [OpenTelemetry](https://opentelemetry.io/):

- **Tracing** — incoming requests are traced. Trace context and correlation identifiers supplied by the client (via request metadata) are propagated, allowing requests to be correlated across services.
- **Metrics** — operational and system metrics are collected and can be exported to an OTLP-compatible backend.
- **Cross-cutting request handling** — trace-context propagation, correlation-ID handling, structured request logging and panic recovery are applied uniformly to incoming requests.

Exporters, sampling and related behavior are configurable. See the server repository's [observability documentation](https://github.com/open-crypto-broker/crypto-broker-server/blob/main/docs/otel.md) for details.

---

## Configuration

The server is configured entirely through environment variables. These control, among other things, the environment mode (production vs. development), the profiles directory, logging behavior, observability exporters, and resource limits.

The full and authoritative list of environment variables is maintained alongside the implementation in the server repository's [environment variable documentation](https://github.com/open-crypto-broker/crypto-broker-server/blob/main/docs/envs.md). It is intentionally not duplicated here to avoid drift.

---

## Error Handling

Error reporting is verbose and stage-aware: the client is told which part of the operation failed. Errors are returned when, for example:

- the specified profile is missing or invalid;
- input data is malformed (e.g. an invalid CSR, certificate or key);
- input data does not adhere to profile rules (e.g. key-size or validity constraints);
- the requested algorithm is unknown or unsupported by the profile;
- a cryptographic operation fails.

---

## Activity Flow

1. **Startup**
    - The server loads and validates profiles from `Profiles.yaml`.
    - Observability (tracing and metrics) is initialized and the cryptographic backend is prepared.
    - The socket directory (`/tmp/open-crypto-broker`) is ensured and any stale socket file is removed.
    - A gRPC server is started, listening on the Unix socket at `/tmp/open-crypto-broker/crypto-broker-server.sock`, with request interceptors and message-size limits applied.
    - The production service and the health service are registered. In a development environment, the development service is additionally registered.

1. **Requests**
    - A client sends a `HashData` or `SignCertificate` request via gRPC.
    - The server enforces message-size limits, retrieves the referenced profile and validates the input against it.
    - The server selects the cryptographic algorithm and parameters based on the profile and performs the operation.
    - The server returns the response (hash value or signed certificate) together with metadata, or a verbose error.

1. **Error handling**
    - Errors are returned as described in [Error Handling](#error-handling).

1. **Shutdown**
    - On receiving a termination signal, the server gracefully stops serving, closes the socket, cleans up the socket file and releases resources.

---

## Running the Crypto Broker server

To run the Crypto Broker server, build an executable binary of the server (for example via `task build-go`, which places the binary in the `bin` directory) and start it, providing the directory that contains the profiles:

```bash
CRYPTO_BROKER_PROFILES_DIR=/full/path/to/profiles/ ./bin/cryptobroker-server
```

For detailed instructions on building, configuring and running the server, refer to the [Crypto Broker Server repository](https://github.com/open-crypto-broker/crypto-broker-server).
