# Crypto Broker Library Specification

## Overview

The Crypto Broker service provides remote cryptographic operations over gRPC, including:

- Hashing arbitrary binary data: `HashData` API
- Generating X.509 certificates based on Certificate Signing Requests (CSRs): `SignCertificate` API

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
| `metadata` | Map | Metadata about the Crypto Broker request/response. |

All other values like validity, signature algorithm etc. can be extracted from the certificate itself.

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

### `traceContext`

| Variable | Type | Description |
| --- | --- | --- |
| `traceId` | String | Trace identifier of the distributed trace. |
| `spanId` | String | Span identifier within the trace. |
| `traceFlags` | String | Trace flags (e.g. sampling decision). |
| `traceState` | String | Vendor-specific trace state. |
| `correlationId` | String | Correlation identifier for the request. |

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
