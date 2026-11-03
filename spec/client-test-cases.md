# Client Test Scenario Catalogue

Use this catalogue when changing the Go or JavaScript client. Add scenarios to both libraries and record any language exception here.
Every validation rejection must return an error without a gRPC call.

## Hash Fixture

Use the 11 UTF-8 bytes of `Hello world`, without a newline: `[]byte("Hello world")` in Go and `Buffer.from('Hello world')` in JS.
The mocked profile is `Default`, the response algorithm is `descriptor.algorithm = sha3-512` (Go: `Descriptor_.Algorithm`), and the reference HEX digest is:

```text
e2e1c9e522efb2495a178434c8bb8f11000ca23f1fd679058b7d7e141f0cf3433f94fc427ec0b9bebb12f327a3240021053db6091196576d5e6d9bd8fac71c0c
```

RAW output is the 64 bytes decoded from this digest.

## Language Exceptions

- Go payloads are structs passed by value. `nil` payloads and wrong field types cannot compile; use a zero-value payload to test missing required fields. JS must reject missing payloads and wrong runtime types.
- Go rejects nil hash input but accepts a non-nil empty slice. JS rejects missing input but accepts an empty `Uint8Array` or `Buffer`.
- Existing ID behavior differs for explicitly empty metadata IDs: JS generates an ID; Go preserves the empty ID when metadata is non-nil.
- Go timestamps use `*time.Time`; a provided zero time is rejected. JS uses uint64-compatible values and tests a bigint above uint64 range.
- Use named protobuf enum values. Go rejects UNSPECIFIED output formats; JS currently accepts that recognized zero value. Both clients reject unrecognized enum values. Valid Go fixtures must set a format explicitly.
- Go string limits count UTF-8 bytes; existing JS limits count UTF-16 code units. Shared length fixtures use ASCII. Unicode length behavior remains different.

Field names below use JS/protobuf spelling: for example, `csr` maps to Go `CSR`, and `metadata.traceContext.traceId` maps to Go `Metadata.TraceContext.TraceId`.

## HashData

| Category | Scenario | Expected outcome |
| --- | --- | --- |
| validation | Missing payload, or a Go zero-value payload. | Reject before gRPC; Go reports the missing profile. |
| validation | Empty profile, or profile over 64 ASCII characters. | Reject with a profile error. |
| validation | Missing/nil input, or a string instead of bytes in JS. | Reject with an input error. |
| validation | Input exceeds 1 MiB. | Reject with an input error. |
| validation | Unrecognized output value. | Reject with an output-format error. |
| validation | Trace ID exceeds 32 ASCII characters. | Reject with a `metadata.traceContext.traceId` error. |
| happy-path | Canonical input with HEX or RAW output. | Forward input/profile/output format; return the reference digest and algorithm. |
| happy-path | Explicitly empty, non-nil byte input. | Accept it; the server computes the empty-input digest. |
| metadata | Metadata is omitted (`Metadata: nil` in Go). | Send a non-empty UUIDv4 ID in the outbound request. |
| metadata | A non-empty ID is supplied. | Preserve the ID in the outbound request. |
| error-propagation | gRPC returns an error. | Return the error; do not report a successful hash. |
| error-propagation | JS circuit breaker reaches its failure threshold. | Reject while open; allow a probe after the reset interval. |

## SignCertificate

| Category | Scenario | Expected outcome |
| --- | --- | --- |
| validation | Missing payload, or a Go zero-value payload. | Reject before gRPC. |
| validation | Empty profile, or profile over 64 ASCII characters. | Reject with a profile error. |
| validation | CSR or CA certificate is missing or empty. | Reject with the field name. |
| validation | Go CA private key is missing or empty; JS key source is missing. | Reject with the field name. |
| validation | CSR, CA certificate or Go CA private key exceeds 64 KiB; JS key ID exceeds 64 ASCII characters. | Reject with the field name. |
| validation | Subject exceeds 1024 ASCII characters. | Reject with a subject error. |
| validation | CRL distribution points exceed 16 entries, or an entry exceeds 2048 ASCII characters. | Reject with the field name or entry index. |
| validation | JS receives a non-string CRL entry. | Reject with the entry index; Go's compiler prevents this input. |
| validation | Invalid timestamp value or unrecognized output value. | Reject with the field name. |
| happy-path | Valid fields with PEM output. | Return the mocked PEM certificate. |
| happy-path | Valid fields with DER output. | Return the mocked DER bytes. |
| metadata | Metadata is omitted. | Generate a UUIDv4 ID in the outbound request. |
| metadata | A non-empty ID is supplied. | Preserve the ID in the outbound request. |
| error-propagation | gRPC returns an error. | Return the error; do not report a successful certificate. |

## HealthData

| Category | Scenario | Expected outcome |
| --- | --- | --- |
| validation | No application payload is required. | Send an empty health-check request. |
| happy-path | Server reports SERVING. | Return the language's serving status. |
| metadata | Standard gRPC health protocol. | No Crypto Broker request ID is required. |
| error-propagation | Health RPC fails. | Return UNKNOWN instead of raising the RPC error. |

## Other Operations

| Operation | Category | Scenario | Expected outcome |
| --- | --- | --- | --- |
| EncryptData | validation | Invalid key source, required fields/types, or protobuf size limits. | Reject before gRPC. |
| EncryptData | happy-path | Valid key and plaintext. | Return mocked ciphertext and cipher metadata. |
| EncryptData | metadata | Metadata is omitted. | Generate a request ID. |
| EncryptData | error-propagation | gRPC fails. | Return the error. |
| DecryptData | validation | Invalid key source, required fields/types, or protobuf size limits. | Reject before gRPC. |
| DecryptData | happy-path | Valid key and ciphertext. | Return mocked plaintext. |
| DecryptData | metadata | Metadata is omitted. | Generate a request ID. |
| DecryptData | error-propagation | gRPC fails. | Return the error. |
| SignData | validation | Invalid profile, input, key source, metadata or signature format. | Reject before gRPC. |
| SignData | happy-path | Valid key and input. | Return mocked signature bytes. |
| SignData | metadata | Metadata is omitted. | Generate a request ID. |
| SignData | error-propagation | gRPC fails. | Return the error. |
| VerifyData | validation | Invalid profile, input, key source, metadata, signature or format. | Reject before gRPC. |
| VerifyData | happy-path | Valid input and signature. | Return the mocked validity flag. |
| VerifyData | metadata | Metadata is omitted. | Generate a request ID. |
| VerifyData | error-propagation | gRPC fails. | Return the error. |
