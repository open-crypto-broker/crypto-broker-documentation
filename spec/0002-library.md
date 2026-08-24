# Crypto Broker Library Specification

## Overview

The Crypto Broker service provides remote cryptographic operations over gRPC, including:

- Hashing arbitrary binary data: `HashData` API
- Generating X.509 certificates based on Certificate Signing Requests (CSRs): `SignCertificate` API
- Encrypting arbitrary binary data: `EncryptData` API
- Decrypting previously encrypted data: `DecryptData` API

This specification describes the behavior and message formats of the API endpoints for clients across any programming language. The library does not perform cryptographic operations locally. It delegates all such tasks to the Crypto Broker.

---

## Transport and Connection

- The communication uses gRPC over Unix domain sockets.
- The socket path is `/tmp/open-crypto-broker/crypto-broker-server.sock`
- The library is initialized by an instance of the provided language-specific library. Then, the APIs listed below can be called, which use the established unix socket connection to communicate with the server.

---

## gRPC Services

The Crypto Broker exposes two separate gRPC services, defined in `messages.proto`:

- `CryptoGrpc` — the production service used by client applications. It exposes the cryptographic operations as gRPC methods:
    - `HashData` — computes a cryptographic hash over arbitrary input.
    - `SignCertificate` — issues an X.509 certificate from a CSR.
    - `EncryptData` — encrypts arbitrary input using authenticated symmetric encryption.
    - `DecryptData` — decrypts data previously produced by `EncryptData`.
- `CryptoGrpcDev` — a development/diagnostics service that is not intended for production application use. It exposes:
    - `Benchmark` — runs a dedicated benchmark in the Crypto Broker server.
    - `FakeEndpoint` — a minimal endpoint used for testing and connectivity checks.

The split keeps the production cryptographic surface (`CryptoGrpc`) separate from the development-only endpoints (`CryptoGrpcDev`), which can be disabled in production deployments.

---

## APIs

When invoking any of the APIs, the application provides a Struct as a single parameter, which in turn contains the values listed below for the inputs of the respective API.
If necessary, optional input parameters can be added to each of the API functions.
The functions equally return a Struct containing API-specific values as well as additional metadata.

### Production APIs (`CryptoGrpc`)

These APIs are provided by the production service `CryptoGrpc` and expose the cryptographic operations used by client applications.

#### `HashData`

The `HashData` API function allows clients to compute cryptographic hashes over arbitrary data using an algorithm specified in a profile. The client-side function maps directly to the `HashData` RPC method of the `CryptoGrpc` gRPC service.

##### `HashData` Input

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the profile (e.g., `Default`, `PCI-DSS`). |
| `input` | Bytes | Arbitrary input to be hashed. |
| `outputFormat` | Enum | *(Optional)* Output encoding of the hash value: `HEX` (default) or `RAW`. |
| `metadata` | Map | *(Optional)* Metadata about the Crypto Broker request/response. |

##### `HashData` Output

The `HashData` API returns a response body `HashDataResponse`, from which the following values can be extracted. The hash value is returned in exactly one of the two fields depending on the requested `outputFormat`.

| Variable | Type | Description |
| --- | --- | --- |
| `hashValueHex` | String | Hash value of the provided input bytes as a hexadecimal string. Set when `outputFormat` is `HEX`. |
| `hashValueRaw` | Bytes | Hash value of the provided input bytes as raw bytes. Set when `outputFormat` is `RAW`. |
| `hashAlgorithm` | String | Hash algorithm used to compute the hash value (e.g. `SHA-256` or `SHA3-256`). |
| `descriptor` | Map | Self-describing descriptor of how the hash was produced (see [`descriptor` message](#descriptor-message)). Should be persisted alongside the hash value. |
| `metadata` | Map | Metadata about the Crypto Broker request/response. |

#### `SignCertificate`

The `SignCertificate` API function allows clients to request a certificate by providing respective keys, certificates and Certificate Signing Requests (CSRs) and receive the signed certificate. The client-side function maps directly to the `SignCertificate` RPC method of the `CryptoGrpc` gRPC service.

##### `SignCertificate` Input

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the profile (e.g., `Default`, `PCI-DSS`). |
| `csr` | String | PEM-encoded CSR containing the public key of the subject. |
| `caPrivateKey` | String | PEM-encoded private key of the issuer used to sign the CSR. |
| `caCert` | String | PEM-encoded certificate of the issuer containing the matching public key. |
| `validNotBefore` | Uint64 | *(Optional)* Validity start as a Unix timestamp (seconds since epoch). |
| `validNotAfter` | Uint64 | *(Optional)* Validity end as a Unix timestamp (seconds since epoch). |
| `subject` | String | *(Optional)* Custom Subject Distinguished Name provided by the application. |
| `crlDistributionPoints` | List of Strings | *(Optional)* Custom CRL Distribution Point URLs provided by the application. Each URL must comply with [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986) |
| `outputFormat` | Enum | *(Optional)* Output encoding of the signed certificate: `DER` (default) or `PEM`. |
| `metadata` | Map | *(Optional)* Metadata about the Crypto Broker request/response. |

##### `SignCertificate` Output

The `SignCertificate` API returns a response body `SignCertificateResponse`, from which the following values can be extracted. The signed certificate is returned in exactly one of the two fields depending on the requested `outputFormat`.

| Variable | Type | Description |
| --- | --- | --- |
| `pem` | String | PEM-encoded signed certificate. Set when `outputFormat` is `PEM`. |
| `der` | Bytes | DER-encoded signed certificate. Set when `outputFormat` is `DER`. |
| `descriptor` | Map | Self-describing descriptor of how the certificate was signed (see [`descriptor` message](#descriptor-message)). Should be persisted alongside the certificate. |
| `metadata` | Map | Metadata about the Crypto Broker request/response. |

All other values like validity, signature algorithm etc. can be extracted from the certificate itself.

#### `EncryptData`

The `EncryptData` API function allows clients to encrypt arbitrary data using an authenticated symmetric encryption algorithm specified in a profile. The client-side function maps directly to the `EncryptData` RPC method of the `CryptoGrpc` gRPC service.

The encryption key is supplied via a `keySource` (see [`KeySource` message](#keysource-message)). The caller can either reference an externally provisioned key that the broker retrieves from a key storage backend (`keyId`) or supply raw key material inline (`rawKey`).
Encryption parameters are supplied via `encryptMetadata`: the caller always provides the nonce, and optionally additional authenticated data (AAD).

##### `EncryptData` Input

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the profile (e.g., `Default`, `PCI-DSS`). |
| `keySource` | Map | Key material to use, given as a [`KeySource`](#keysource-message). Either a `keyId` (KMS-backed) or `rawKey` (caller-managed). |
| `plaintext` | Bytes | Arbitrary input to be encrypted. |
| `encryptMetadata` | Map | Caller-supplied encryption parameters (see [`encryptMetadata` message](#encryptmetadata-message)), e.g. nonce and AAD. |
| `metadata` | Map | *(Optional)* Metadata about the Crypto Broker request/response. |

##### `EncryptData` Output

The `EncryptData` API returns a response body `EncryptDataResponse`, from which the following values can be extracted.

| Variable | Type | Description |
| --- | --- | --- |
| `ciphertext` | Bytes | The encrypted data. |
| `cipherMetadata` | Map | Metadata accompanying the ciphertext (see [`cipherMetadata` message](#ciphermetadata-message)). Encapsulates the key identifier used and, where the caller must retain them, the nonce, AAD and authentication tag needed to decrypt later. |
| `metadata` | Map | Metadata about the Crypto Broker request/response. |
| `descriptor` | Map | Self-describing descriptor of how the ciphertext was produced (see [`descriptor` message](#descriptor-message)). Should be persisted alongside the ciphertext. |

#### `DecryptData`

The `DecryptData` API function allows clients to decrypt data previously produced by `EncryptData`. The client-side function maps directly to the `DecryptData` RPC method of the `CryptoGrpc` gRPC service.

The caller provides the same `keySource` variant expected by the profile, and supplies the decryption parameters via `decryptMetadata`, typically by echoing back the values from the `cipherMetadata` returned by `EncryptData`.

##### `DecryptData` Input

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the profile (e.g., `Default`, `PCI-DSS`). |
| `keySource` | Map | Key material to use, given as a [`KeySource`](#keysource-message). Either a `keyId` (KMS-backed) or `rawKey` (caller-managed). |
| `ciphertext` | Bytes | The encrypted data to be decrypted. |
| `decryptMetadata` | Map | Caller-supplied decryption parameters (see [`decryptMetadata` message](#decryptmetadata-message)), e.g. nonce, AAD and authentication tag. |
| `metadata` | Map | *(Optional)* Metadata about the Crypto Broker request/response. |

##### `DecryptData` Output

The `DecryptData` API returns a response body `DecryptDataResponse`, from which the following values can be extracted.

| Variable | Type | Description |
| --- | --- | --- |
| `plaintext` | Bytes | The decrypted data. |
| `metadata` | Map | Metadata about the Crypto Broker request/response. |

---

### Development APIs (`CryptoGrpcDev`)

These APIs are provided by the development/diagnostics service `CryptoGrpcDev`. They are not intended for production application use and can be disabled in production deployments.

#### `BenchmarkData`

This API allows clients to run a dedicated benchmark in the Crypto Broker server. It is provided by the development service `CryptoGrpcDev` via the `Benchmark` method.

##### `BenchmarkData` Input

| Variable | Type | Description |
| --- | --- | --- |
| `metadata` | Map | *(Optional)* Metadata about the Crypto Broker request/response. |

##### `BenchmarkData` Output

| Variable | Type | Description |
| --- | --- | --- |
| `benchmarkResults` | String | Results of the benchmark run. |
| `metadata` | Map | Metadata about the Crypto Broker request/response. |

---

### Health Checking

#### `HealthData`

gRPC itself has built-in support for [health checks](https://grpc.io/docs/guides/health-checking/).
The health service/messages are stored in a `third_party` folder.
Go does not need to generate source code from this protobuf messages, as Go already provide pre-generated code in a module.
All other languages need to include the `health.proto` file in the protobuf compiler include and input path in order to generate the necessary request and response messages.

---

## Metadata message

`metadata`

| Variable | Type | Description |
| --- | --- | --- |
| `id` | String | ID of the request, given as a UUID v4 in String format. |
| `traceContext` | Map | *(Optional)* Trace context for manual propagation of distributed tracing information. |
| `deprecation` | Map | *(Optional)* Deprecation warning (see [`deprecation`](#deprecation)). Set on every response produced with a deprecated profile. |

### `traceContext`

| Variable | Type | Description |
| --- | --- | --- |
| `traceId` | String | Trace identifier of the distributed trace. |
| `spanId` | String | Span identifier within the trace. |
| `traceFlags` | String | Trace flags (e.g. sampling decision). |
| `traceState` | String | Vendor-specific trace state. |
| `correlationId` | String | Correlation identifier for the request. |

### `deprecation`

Deprecation warning attached to every response produced with a deprecated profile, enabling the rolling-migration path described in the [Profile Change and Migration Guidance ADR](../adr/overall/0013-profile-change-migration-guidance.md). The values mirror the profile's [`Deprecation`](0001-profile.md#deprecation) metadata.

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the deprecated profile the response was produced with. |
| `replacedBy` | String | *(Optional)* Name of the successor profile the application should migrate to. |
| `deprecatedSince` | String | *(Optional)* Date the profile was deprecated. |
| `removeAfter` | String | *(Optional)* Sunset date after which the profile is removed. |
| `reason` | String | *(Optional)* Human-readable explanation of why the profile is deprecated. |

---

## `descriptor` message

Self-describing record of how a stored cryptographic artifact was produced, returned by the record-producing APIs (`HashData`, `SignCertificate`, `EncryptData`).
Applications **should persist this descriptor verbatim alongside the value**, so that the record stays verifiable and migratable even after the underlying profile changes, and without access to `Profiles.yaml`.
See the [Profile Change and Migration Guidance ADR](../adr/overall/0013-profile-change-migration-guidance.md) for the rationale.

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the profile that produced the artifact. |
| `operation` | String | The API that produced the artifact (e.g. `HashData`, `SignCertificate`, `EncryptData`). |
| `algorithm` | String | The concrete algorithm actually used (e.g. `sha3-512`, `aes-gcm`). |

---

## `KeySource` message

The `keySource` carries the key material for the `EncryptData` and `DecryptData` APIs.
Exactly one of the two fields must be set.
Which variant is valid is determined by the profile: a profile without a key storage backend (`KMS`) requires `rawKey`, while a profile with a `KMS` expects `keyId`.

| Variable | Type | Description |
| --- | --- | --- |
| `keyId` | String | Identifier of an externally provisioned key that the broker resolves and retrieves from the key storage backend. Set for profiles with a `KMS`. |
| `rawKey` | Bytes | Inline key material supplied by the caller. Set for caller-managed profiles without a `KMS`. |

## `encryptMetadata` message

Caller-supplied encryption parameters for the `EncryptData` API. The caller always supplies the nonce; neither the broker nor the KMS generates it.

| Variable | Type | Description |
| --- | --- | --- |
| `nonce` | Bytes | Nonce to use for encryption. Always supplied by the caller, which owns its uniqueness. |
| `aad` | Bytes | *(Optional)* Additional authenticated data to bind to the ciphertext. |

## `cipherMetadata` message

Metadata produced by `EncryptData` and returned alongside the ciphertext.
It encapsulates everything the caller may need besides the ciphertext itself: `keyId` is echoed for profiles with a `KMS`, while `nonce`, `aad` and `tag` are echoed back for the caller to retain and pass to `DecryptData`.

| Variable | Type | Description |
| --- | --- | --- |
| `keyId` | String | *(Optional)* The key identifier that was used, echoed back for KMS-backed profiles. Raw key material is never returned. |
| `nonce` | Bytes | The nonce actually used for encryption. |
| `aad` | Bytes | *(Optional)* The additional authenticated data bound to the ciphertext. |
| `tag` | Bytes | *(Optional)* The authentication tag produced by the authenticated encryption algorithm. |

## `decryptMetadata` message

Caller-supplied decryption parameters for the `DecryptData` API, symmetric to [`encryptMetadata`](#encryptmetadata-message).
The caller provides them, typically by echoing back the values from the `cipherMetadata` returned by `EncryptData`.

| Variable | Type | Description |
| --- | --- | --- |
| `nonce` | Bytes | Nonce to use for decryption. |
| `aad` | Bytes | *(Optional)* Additional authenticated data bound to the ciphertext. |
| `tag` | Bytes | *(Optional)* The authentication tag to verify during decryption. |

---

## Examples

### Go

```go
cryptoLib, err := cryptobrokerclientgo.NewLibrary()
ctx = context.Background()
hashDataPayload := cryptobrokerclientgo.HashDataPayload{
    Profile: profile,
    Input: input
}
responseBody, err := cryptoLib.HashData(ctx, hashDataPayload)
hashValue := responseBody.hashValue
```

### Javascript

```javascript
const cryptoLib = new CryptoBrokerClient();
const hashDataPayload = {
    profile: profile,
    input: input
};
const responseBody = await cryptoLib.hashData(hashDataPayload);
const hashValue = responseBody.hashValue
```

---

## Errors

The API output contains an error if the cryptographic operation could not be executed successfully.
This may be caused by different circumstances.
On the client side, errors may be caused in the following scenarios:

- The profile is malformed, incomplete, contains erroneous values (e.g. unsupported algorithms) or could not be parsed. It should adhere to the profile structure specification.
- SignCertificate:
    - The signature algorithm in the profile does not match the algorithm of the private key given as a parameter.
    - The public key given in the CA certificate does not match the private key.
    - The requested certificate validity is out of the permitted profile boundaries.
    - The length of the issuer's private key or the subject's public key is out of the permitted profile boundaries.
- EncryptData / DecryptData:
    - The provided `keySource` variant does not match the profile (e.g. `rawKey` supplied for a profile that expects a `keyId`, or vice versa).
    - The length of the supplied or referenced key is out of the permitted profile boundaries.
    - The nonce required for the operation is missing (the caller must always supply it).
    - The referenced key identifier cannot be resolved by the key storage backend.
    - The ciphertext or authentication tag fails verification during decryption.
