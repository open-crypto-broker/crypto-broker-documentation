# Crypto Broker Library Specification

## Overview

The Crypto Broker service provides remote cryptographic operations over gRPC, including:

- Hashing arbitrary binary data.
- Generating X.509 certificates based on Certificate Signing Requests (CSRs).

This specification describes the behavior and message formats of the API endpoints for clients across any programming language. The library does not perform cryptographic operations locally. It delegates all such tasks to the Crypto Broker.

---

## Transport and Connection

- The communication uses gRPC over Unix domain sockets.
- The socket path is `/tmp/cryptobroker.sock`
- The library is initialized by an instance of the provided language-specific library. Then, the APIs listed below can be called, which use the established unix socket connection to communicate with the server.

---

## APIs

When invoking any of the APIs, the application provides a Struct as a single parameter, which in turn contains the values listed below for the inputs of the respective API.
If necessary, optional input parameters can be added to each of the API functions.
The functions equally return a Struct containing API-specific values as well as additional metadata.

### `Status`

The `Status` API function helps determining a client the status of the Crypto Broker Server. gRPC itself has built-in support for [health checks](https://grpc.io/docs/guides/health-checking/).

#### `StatusData` Input

| Variable | Type | Description |
| --- | --- | --- |
| `service` | String | Name of the service, if defined. Otherwise an empty string "" means the health of the complete Crypto Broker. |
| `metadata` | Map | *(Optional)* Metadata about the Crypto Broker request/response. |

#### `StatusData` Output

The `Status` API returns a response body `StatusResponse` with following content:

| Variable | Type | Description |
| --- | --- | --- |
| `status` | String | Status of the Crypto Broker service or complete server. |
| `metadata` | Map | Metadata about the Crypto Broker request/response. |

### `HashData`

The `HashData` API function allows clients to compute cryptographic hashes over arbitrary data using an algorithm specified in a profile. Internally it accesses the `Hash` method on the `CryptoBroker` gRPC service.

#### `HashData` Input

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the profile (e.g., `Default`, `PCI-DSS`). |
| `input` | Bytes | Arbitrary input to be hashed. |
| `metadata` | Map | *(Optional)* Metadata about the Crypto Broker request/response. |

> Note: The `outputSize` parameter for the SHAKE XOF is currently out of scope and not considered here. Whether this parameter is part of the API call or the profile configuration is for further study.

#### `HashData` Output

The `HashData` API returns a response body `HashResponse`, from which the following values can be extracted.

| Variable | Type | Description |
| --- | --- | --- |
| `hashValue` | String | Hash value of the provided input bytes. |
| `hashAlgorithm` | String | Hash algorithm used to compute the hash value (e.g. `SHA-256` or `SHA3-256`). |
| `metadata` | Map | Metadata about the Crypto Broker request/response. |

---

### `SignCertificate`

The `SignCertificate` API function allows clients to request a certificate by providing respective keys, certificates and Certificate Signing Requests (CSRs) and receive the signed certificate. Internally it accesses the `Sign` method on the `CryptoBroker` gRPC service.

#### `SignCertificate` Input

| Variable | Type | Description |
| --- | --- | --- |
| `profile` | String | Name of the profile (e.g., `Default`, `PCI-DSS`). |
| `csr` | String | PEM-encoded CSR containing the public key of the subject. |
| `caPrivateKey` | String | PEM-encoded private key of the issuer used to sign the CSR. |
| `caCert` | String | PEM-encoded certificate of the issuer containing the matching public key. |
| `validNotBeforeOffset` | String | *(Optional)* Validity start request as an offset to the current time. |
| `validNotAfterOffset` | String | *(Optional)* Validity end request as an offset to the current time. |
| `subject` | String | *(Optional)* Custom Subject Distinguished Name provided by the application. |
| `crlDistributionPoints` | List of Strings | *(Optional)* Custom CRL Distribution Point URLs provided by the application. |
| `metadata` | Map | *(Optional)* Metadata about the Crypto Broker request/response. |

> Note: Time offset formats for `validNotBeforeOffset` and `validNotAfterOffset` (e.g., `-1h`, `8760h`) are expected to be strings compatible with Go duration parsing. Please refer to [time@go1.24.3 ParseDuration()](https://pkg.go.dev/time@go1.24.3#ParseDuration) for the syntax definition.

#### `Options` Input

Additional options which are not necessarily send to the Crypto Broker. For example local configuration options for the client can be specified.

| Variable | Type | Description |
| --- | --- | --- |
| `encoding` | String | *(Optional)* Define how the signed certificate shall be encoded. Default is PEM. Alternatives: Base64 |

#### `SignCertificate` Output

The `SignCertificate` API returns a response body `SignResponse`, from which the following values can be extracted.

| Variable | Type | Description |
| --- | --- | --- |
| `signedCertificate` | String | PEM-encoded signed certificate. All other values like validity, signature algorithm etc. can be extracted from the certificate itself. |
| `metadata` | Map | Metadata about the Crypto Broker request/response. |

---

## Metadata message

`metadata`

| Variable | Type | Description |
| --- | --- | --- |
| `id` | String | ID of the request, given as a UUID v4 in String format. |
| `createdAt` | String | Date of the request creation, given as an UTC timestamp following [RFC 3339](https://datatracker.ietf.org/doc/html/rfc3339) (per [RFC 9557](https://datatracker.ietf.org/doc/html/rfc9557) clarifications). |

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
