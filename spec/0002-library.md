# Crypto Broker Library Specification

## Overview

The Crypto Broker service provides remote cryptographic operations over gRPC, including:

- Hashing arbitrary binary data: `HashData` API
- Generating X.509 certificates based on Certificate Signing Requests (CSRs): `SignCertificate` API
- Signing arbitrary binary data: `SignData` API
- Verifying signatures over arbitrary binary data: `VerifyData` API
- Encrypting arbitrary binary data: `EncryptData` API
- Decrypting previously encrypted data: `DecryptData` API

This specification describes the behavior and message formats of the API endpoints for clients across any programming language.
The library does not perform cryptographic operations locally.
It delegates all such tasks to the Crypto Broker Server.

---

## Transport and Connection

- The communication uses gRPC over Unix domain sockets.
- The socket path is `/tmp/open-crypto-broker/crypto-broker-server.sock`
- The library is initialized by an instance of the provided language-specific library. Then, the APIs listed below can be called, which use the established unix socket connection to communicate with the server.

---

## gRPC Services

The Crypto Broker Server exposes two separate gRPC services, defined in [`cryptobroker/v1/messages.proto`](https://github.com/open-crypto-broker/crypto-broker-proto/tree/main/cryptobroker/v1/messages.proto):

- `CryptoService` — the production service used by client applications. It exposes the cryptographic operations as gRPC methods:
    - `HashData` — computes a cryptographic hash over arbitrary input.
    - `SignCertificate` — issues an X.509 certificate from a CSR.
    - `SignData` — produces a digital signature over arbitrary input.
    - `VerifyData` — verifies a digital signature over arbitrary input.
    - `EncryptData` — encrypts arbitrary input using authenticated symmetric encryption.
    - `DecryptData` — decrypts data previously produced by `EncryptData`.
- `CryptoDevService` — a development/diagnostics service that is not intended for production application use. It exposes:
    - `Benchmark` — runs a dedicated benchmark in the Crypto Broker server.
    - `FakeEndpoint` — a minimal endpoint used for testing and connectivity checks.

The split keeps the production cryptographic surface (`CryptoService`) separate from the development-only endpoints (`CryptoDevService`), which can be disabled in production deployments.

---

## APIs

When invoking any of the APIs, the application provides a Struct as a single parameter, which in turn contains the values listed below for the inputs of the respective API.
If necessary, optional input parameters can be added to each of the API functions.
The functions equally return a Struct containing API-specific values as well as additional metadata.

### Production APIs (`CryptoService`)

These APIs are provided by the production service `CryptoService` and expose the cryptographic operations used by client applications.

#### `HashData`

The `HashData` API function allows clients to compute cryptographic hashes over arbitrary data using an algorithm specified in a profile. The client-side function maps directly to the `HashData` RPC method of the `CryptoService` gRPC service.

##### `HashData` Input

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the profile (e.g., `Default`, `PCI-DSS`). |
| `input` | Bytes | Arbitrary input to be hashed. |
| `output_format` | Enum | *(Optional)* Output encoding of the hash value: `HEX` (default) or `RAW`. |
| `metadata` | Map | *(Optional)* Metadata about the Crypto Broker request/response. |

##### `HashData` Output

The `HashData` API returns a response body `HashDataResponse`, from which the following values can be extracted.
The hash value is returned in exactly one of the two fields depending on the requested `output_format`.

| Variable | Type | Description |
| --- | --- | --- |
| `hash_value_hex` | String | Hash value of the provided input bytes as a hexadecimal string. Set when `output_format` is `HEX`. |
| `hash_value_raw` | Bytes | Hash value of the provided input bytes as raw bytes. Set when `output_format` is `RAW`. |
| `descriptor` | Map | Self-describing descriptor of how the hash was produced (see [`CryptoDescriptor` message](#cryptodescriptor-message)). Should be persisted alongside the hash value. |
| `metadata` | Map | [`Metadata` message](#metadata-message) about the Crypto Broker request/response. |

#### `SignCertificate`

The `SignCertificate` API function allows clients to request a certificate by providing respective keys, certificates and Certificate Signing Requests (CSRs) and receive the signed certificate.
The client-side function maps directly to the `SignCertificate` RPC method of the `CryptoService` gRPC service.

##### `SignCertificate` Input

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the profile (e.g., `Default`, `PCI-DSS`). |
| `csr` | String | PEM-encoded CSR containing the public key of the subject. |
| `ca_cert` | String | PEM-encoded certificate of the issuer containing the matching public key. |
| `key_source` | Map | Signing key material, given as a [`SignKeySource`](#signkeysource-message). A single key for `legacy`/`post-quantum`, or a list of component keys for `hybrid`. |
| `valid_not_before` | Uint64 | *(Optional)* Validity start as a Unix timestamp (seconds since epoch). |
| `valid_not_after` | Uint64 | *(Optional)* Validity end as a Unix timestamp (seconds since epoch). |
| `subject` | String | *(Optional)* Custom Subject Distinguished Name provided by the application. |
| `crl_distribution_points` | List of Strings | *(Optional)* Custom CRL Distribution Point URLs provided by the application. Each URL must comply with [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986) |
| `output_format` | Enum | *(Optional)* Output encoding of the signed certificate: `DER` (default) or `PEM`. |
| `metadata` | Map | *(Optional)* [`Metadata` message](#metadata-message) about the Crypto Broker request/response. |

##### `SignCertificate` Output

The `SignCertificate` API returns a response body `SignCertificateResponse`, from which the following values can be extracted.
The signed certificate is returned in exactly one of the two fields depending on the requested `output_format`.

| Variable | Type | Description |
| --- | --- | --- |
| `pem` | String | PEM-encoded signed certificate. Set when `output_format` is `PEM`. |
| `der` | Bytes | DER-encoded signed certificate. Set when `output_format` is `DER`. |
| `descriptor` | Map | Self-describing descriptor of how the certificate was signed (see [`CryptoDescriptor` message](#cryptodescriptor-message)). Should be persisted alongside the certificate. |
| `metadata` | Map | [`Metadata` message](#metadata-message) about the Crypto Broker request/response. |

All other values like validity, signature algorithm etc. can be extracted from the certificate itself.

#### `SignData`

The `SignData` API function allows clients to produce a digital signature over arbitrary data using the signing mode and algorithms specified in a profile.
The client-side function maps directly to the `SignData` RPC method of the `CryptoService` gRPC service.

The profile selects one of three signing modes, enabling a controlled migration from traditional to post-quantum cryptography:

- `legacy` — a traditional signature only (e.g. RSA or ECDSA).
- `hybrid` — a composite signature binding a traditional algorithm **and** a post-quantum algorithm (ML-DSA); both component signatures must verify.
- `post-quantum` — a post-quantum signature only (e.g. ML-DSA or SLH-DSA).

The signing key is supplied via a `key_source` (see [`SignKeySource` message](#signkeysource-message)).
For `legacy` and `post-quantum` modes a single key is used; for `hybrid` mode two component keys are supplied (the traditional key and the ML-DSA key).
As with `EncryptData`, each key is either a `key_id` (KMS-backed) or `raw_key` (caller-managed), governed by whether the global settings define a key storage backend.

##### `SignData` Input

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the profile (e.g., `Default`, `PCI-DSS`). |
| `key_source` | Map | Signing key material, given as a [`SignKeySource`](#signkeysource-message). A single key for `legacy`/`post-quantum`, or a list of component keys for `hybrid`. |
| `input` | Bytes | Arbitrary input to be signed (e.g. an image, ZIP archive or PDF document). |
| `signature_format` | Enum | *(Optional)* Output encoding of the signature: `RAW` (default), `DER`, `PEM` or `CMS`. `CMS` produces an [RFC 5652](https://www.rfc-editor.org/rfc/rfc5652) SignedData structure. |
| `metadata` | Map | *(Optional)* [`Metadata` message](#metadata-message) about the Crypto Broker request/response. |

##### `SignData` Output

The `SignData` API returns a response body `SignDataResponse`, from which the following values can be extracted.

| Variable | Type | Description |
| --- | --- | --- |
| `signature` | Bytes | The digital signature over the provided input, encoded according to the requested `signature_format`. |
| `descriptor` | Map | Self-describing descriptor of how the signature was produced (see [`CryptoDescriptor` message](#cryptodescriptor-message)). Should be persisted alongside the signature. |
| `metadata` | Map | [`Metadata` message](#metadata-message) about the Crypto Broker request/response. |

#### `VerifyData`

The `VerifyData` API function allows clients to verify a digital signature previously produced by `SignData` (or by a compatible signer) over arbitrary data.
The client-side function maps directly to the `VerifyData` RPC method of the `CryptoService` gRPC service.

The caller provides the same signing mode via the profile and supplies the corresponding public key material via `key_source`.
For `hybrid` mode, both component public keys are supplied and both component signatures must verify for the result to be valid.

##### `VerifyData` Input

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the profile (e.g., `Default`, `PCI-DSS`). |
| `key_source` | Map | Public key material, given as a [`SignKeySource`](#signkeysource-message). A single key for `legacy`/`post-quantum`, or a list of component keys for `hybrid`. |
| `input` | Bytes | The original input over which the signature was produced. |
| `signature` | Bytes | The signature to verify, encoded according to `signature_format`. |
| `signature_format` | Enum | *(Optional)* Encoding of the supplied signature: `RAW` (default), `DER`, `PEM` or `CMS`. |
| `metadata` | Map | *(Optional)* [`Metadata` message](#metadata-message) about the Crypto Broker request/response. |

##### `VerifyData` Output

The `VerifyData` API returns a response body `VerifyDataResponse`, from which the following values can be extracted.

| Variable | Type | Description |
| --- | --- | --- |
| `valid` | Boolean | `true` if the signature is valid for the given input and key material, `false` otherwise. A malformed signature, key-source mismatch or unsupported algorithm is reported as an error rather than `false`. |
| `metadata` | Map | [`Metadata` message](#metadata-message) about the Crypto Broker request/response. |

#### `EncryptData`

The `EncryptData` API function allows clients to encrypt arbitrary data using an authenticated symmetric encryption algorithm specified in a profile.
The client-side function maps directly to the `EncryptData` RPC method of the `CryptoService` gRPC service.

The encryption key is supplied via a `key_source` (see [`KeySource` message](#keysource-message)).
The caller can either reference an externally provisioned key that the broker retrieves from a key storage backend (`key_id`) or supply raw key material inline (`raw_key`).
Encryption parameters are supplied via `encrypt_metadata`: the caller always provides the nonce, and optionally additional authenticated data (AAD).

##### `EncryptData` Input

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the profile (e.g., `Default`, `PCI-DSS`). |
| `key_source` | Map | Key material to use, given as a [`KeySource`](#keysource-message). Either a `key_id` (KMS-backed) or `raw_key` (caller-managed). |
| `plaintext` | Bytes | Arbitrary input to be encrypted. |
| `encrypt_metadata` | Map | Caller-supplied encryption parameters (see [`EncryptMetadata` message](#encryptmetadata-message)), e.g. nonce and AAD. |
| `metadata` | Map | *(Optional)* [`Metadata` message](#metadata-message) about the Crypto Broker request/response. |

##### `EncryptData` Output

The `EncryptData` API returns a response body `EncryptDataResponse`, from which the following values can be extracted.

| Variable | Type | Description |
| --- | --- | --- |
| `ciphertext` | Bytes | The encrypted data. |
| `cipher_metadata` | Map | Metadata accompanying the ciphertext (see [`CipherMetadata` message](#ciphermetadata-message)). Encapsulates the key identifier used and, where the caller must retain them, the nonce, AAD and authentication tag needed to decrypt later. |
| `descriptor` | Map | Self-describing descriptor of how the ciphertext was produced (see [`CryptoDescriptor` message](#cryptodescriptor-message)). Should be persisted alongside the ciphertext. |
| `metadata` | Map | [`Metadata` message](#metadata-message) about the Crypto Broker request/response. |

#### `DecryptData`

The `DecryptData` API function allows clients to decrypt data previously produced by `EncryptData`.
The client-side function maps directly to the `DecryptData` RPC method of the `CryptoService` gRPC service.

The caller provides the same `key_source` variant expected by the profile, and supplies the decryption parameters via `decrypt_metadata`, typically by echoing back the values from the `cipher_metadata` returned by `EncryptData`.

##### `DecryptData` Input

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the profile (e.g., `Default`, `PCI-DSS`). |
| `key_source` | Map | Key material to use, given as a [`KeySource`](#keysource-message). Either a `keyId` (KMS-backed) or `rawKey` (caller-managed). |
| `ciphertext` | Bytes | The encrypted data to be decrypted. |
| `decrypt_metadata` | Map | Caller-supplied decryption parameters (see [`DecryptMetadata` message](#decryptmetadata-message)), e.g. nonce, AAD and authentication tag. |
| `metadata` | Map | *(Optional)* [`Metadata` message](#metadata-message) about the Crypto Broker request/response. |

##### `DecryptData` Output

The `DecryptData` API returns a response body `DecryptDataResponse`, from which the following values can be extracted.

| Variable | Type | Description |
| --- | --- | --- |
| `plaintext` | Bytes | The decrypted data. |
| `metadata` | Map | [`Metadata` message](#metadata-message) about the Crypto Broker request/response. |

---

### Development APIs (`CryptoDevService`)

These APIs are provided by the development/diagnostics service `CryptoDevService`.
They are not intended for production application use and can be disabled in production deployments.

#### `Benchmark`

This API allows clients to run a dedicated benchmark in the Crypto Broker server.
It is provided by the development service `CryptoDevService` via the `Benchmark` method.

##### `Benchmark` Input

| Variable | Type | Description |
| --- | --- | --- |
| `metadata` | Map | *(Optional)* [`Metadata` message](#metadata-message) about the Crypto Broker request/response. |

##### `Benchmark` Output

| Variable | Type | Description |
| --- | --- | --- |
| `benchmark_results` | String | Results of the benchmark run. |
| `metadata` | Map | [`Metadata` message](#metadata-message) about the Crypto Broker request/response. |

---

### Health Checking

#### `HealthData`

gRPC itself has built-in support for [health checks](https://grpc.io/docs/guides/health-checking/).
The health service/messages are stored in a `third_party` folder.
Go does not need to generate source code from this protobuf messages, as Go already provide pre-generated code in a module.
All other languages need to include the `health.proto` file in the protobuf compiler include and input path in order to generate the necessary request and response messages.

---

## Utility messages

### `Metadata` message

Represents metadata associated with a Crypto Broker request or response.

| Variable | Type | Description |
| --- | --- | --- |
| `id` | String | ID of the request, given as a UUID v4 in String format. |
| `trace_context` | Map | *(Optional)* Trace context for manual propagation of distributed tracing information (see [`TraceContext`](#tracecontext-message)). |
| `deprecation` | Map | *(Optional)* Deprecation warning (see [`DeprecationWarning`](#deprecationwarning-message)). Set on every response produced with a deprecated profile. |

### `CryptoDescriptor` message

Self-describing record of how a stored cryptographic artifact was produced, returned by the record-producing APIs (`HashData`, `SignCertificate`, `SignData`, `EncryptData`).
Applications **should persist this crypto descriptor verbatim alongside the value**, so that the record stays verifiable and migratable even after the underlying profile changes, and without access to `Profiles.yaml`.
See the [Profile Change and Migration Guidance ADR](../adr/overall/0013-profile-change-migration-guidance.md) for the rationale.

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the profile that produced the artifact. |
| `operation` | String | The API that produced the artifact (e.g. `HashData`, `SignCertificate`, `SignData`, `EncryptData`). |
| `algorithm` | String | The concrete algorithm actually used (e.g. `sha3-512`, `ML-DSA-65`, `aes-128-gcm`). |

### `DeprecationWarning` message

Deprecation warning attached to every response produced with a deprecated profile, enabling the rolling-migration path described in the [Profile Change and Migration Guidance ADR](../adr/overall/0013-profile-change-migration-guidance.md). The values mirror the profile's [`Deprecation`](0001-profile.md#deprecation) metadata.

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the deprecated profile the response was produced with. |
| `replaced_by` | String | *(Optional)* Name of the successor profile the application should migrate to. |
| `deprecated_since` | String | *(Optional)* Date the profile was deprecated. |
| `remove_after` | String | *(Optional)* Sunset date after which the profile is removed. |
| `reason` | String | *(Optional)* Human-readable explanation of why the profile is deprecated. |

### `TraceContext` message

| Variable | Type | Description |
| --- | --- | --- |
| `trace_id` | String | Trace identifier of the distributed trace. |
| `span_id` | String | Span identifier within the trace. |
| `trace_flags` | String | Trace flags (e.g. sampling decision). |
| `trace_state` | String | Vendor-specific trace state. |
| `correlation_id` | String | Correlation identifier for the request. |

### `KeySource` message

The `KeySource` carries the key material for the `EncryptData` and `DecryptData` APIs.
Exactly one of the two fields must be set.
Which variant is valid is determined by the general settings: if there is no key storage backend (`KMS`) defined, `raw_key` is required.
If a `KMS` is defined in the general settings, `key_id` is expected.

| Variable | Type | Description |
| --- | --- | --- |
| `key_id` | String | Identifier of an externally provisioned key that the broker resolves and retrieves from the key storage backend. Set for profiles with a `KMS`. |
| `raw_key` | Bytes | Inline key material supplied by the caller. Set for caller-managed profiles without a `KMS`. |

### `SignKeySource` message

The `SignKeySource` carries the key material for the `SignCertificate`,`SignData`, `VerifyData` APIs.
Exactly one of the two fields must be set, determined by the profile's signing mode:

- `legacy` and `post-quantum` modes use `single`, a single [`KeySource`](#keysource-message).
- `hybrid` mode uses `componentKeys`, an ordered list of [`KeySource`](#keysource-message) entries — the traditional key followed by the ML-DSA key.

Each individual `KeySource` follows the same `key_id` vs. `raw_key` rule as above: a global setting without a `KMS` requires `raw_key`, a global setting with a `KMS` expects `key_id`.
In other words, the presence of a KMS in the global settings dictates which variant must be used.
For `SignData` the key material is the private (signing) key; for `VerifyData` it is the public (verification) key.

| Variable | Type | Description |
| --- | --- | --- |
| `single` | Map | A single [`KeySource`](#keysource-message). Used for `legacy` and `post-quantum` signing modes. |
| `component_keys` | List of Maps | An ordered list of [`KeySource`](#keysource-message) entries (traditional key, then ML-DSA key). Used for `hybrid` signing mode. |

### `ComponentKeys` message

An ordered list of [`KeySource`](#keysource-message) entries used for `hybrid` signing mode. The traditional key comes first, followed by the ML-DSA key.

| Variable | Type | Description |
| --- | --- | --- |
| `component_keys` | List of Maps | An ordered list of [`KeySource`](#keysource-message) entries (traditional key, then ML-DSA key). Used for `hybrid` signing mode. |

### `EncryptMetadata` message

Caller-supplied encryption parameters for the `EncryptData` API. The caller always supplies the nonce; neither the broker nor the KMS generates it.

| Variable | Type | Description |
| --- | --- | --- |
| `nonce` | Bytes | Nonce to use for encryption. Always supplied by the caller, which owns its uniqueness. |
| `aad` | Bytes | *(Optional)* Additional authenticated data to bind to the ciphertext. |

### `CipherMetadata` message

Metadata produced by `EncryptData` and returned alongside the ciphertext.
It encapsulates everything the caller may need besides the ciphertext itself: `keyId` is echoed for profiles with a `KMS`, while `nonce`, `aad` and `tag` are echoed back for the caller to retain and pass to `DecryptData`.

| Variable | Type | Description |
| --- | --- | --- |
| `key_id` | String | *(Optional)* The key identifier that was used, echoed back for KMS-backed profiles. Raw key material is never returned. |
| `nonce` | Bytes | The nonce actually used for encryption. |
| `aad` | Bytes | *(Optional)* The additional authenticated data bound to the ciphertext. |
| `tag` | Bytes | *(Optional)* The authentication tag produced by the authenticated encryption algorithm. |

## `DecryptMetadata` message

Caller-supplied decryption parameters for the `DecryptData` API, symmetric to [`EncryptMetadata`](#encryptmetadata-message).
The caller provides them, typically by echoing back the values from the `CipherMetadata` returned by `EncryptData`.

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
- SignData / VerifyData:
    - The provided `key_source` does not match the profile's signing mode (e.g. a single key supplied for a `hybrid` profile that expects component keys, or vice versa).
    - The provided `key_source` variant does not match the general settings for the KSM (e.g. `raw_key` supplied for a KSM configured setting, or vice versa).
    - The signing algorithm in the profile does not match the algorithm of the supplied or referenced key.
    - The length of a supplied or referenced key is out of the permitted profile boundaries.
    - VerifyData: the signature is malformed or cannot be parsed in the given `signatureFormat`.
- EncryptData / DecryptData:
    - The provided `key_source` variant does not match the general settings for the KSM (e.g. `raw_key` supplied for a KSM configured setting, or vice versa).
    - The length of the supplied or referenced key is out of the permitted profile boundaries.
    - The nonce required for the operation is missing (the caller must always supply it).
    - The referenced key identifier cannot be resolved by the key storage backend.
    - The ciphertext or authentication tag fails verification during decryption.
