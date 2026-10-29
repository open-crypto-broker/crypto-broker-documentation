# Client Test Scenario Catalogue

Use this catalogue when changing the Go or JavaScript client. Add scenarios to both libraries and record any language exception here.
Tests use local gRPC mocks; they check validation, request mapping and error handling, not server cryptography.
Every validation rejection must return an error without a gRPC call.
Coverage below describes the checked local baseline: `tested` means a public-operation test, `validator` means a direct validator test, and `missing` marks a gap. Compiler-only cases are described under language exceptions.

## Hash Fixture

Use the 11 UTF-8 bytes of `Hello world`, without a newline: `[]byte("Hello world")` in Go and `Buffer.from('Hello world')` in JS.
The mocked profile is `Default`, the response algorithm is `descriptor.algorithm = sha3-512` (Go: `Descriptor_.Algorithm`), and the reference HEX digest is:

```text
e2e1c9e522efb2495a178434c8bb8f11000ca23f1fd679058b7d7e141f0cf3433f94fc427ec0b9bebb12f327a3240021053db6091196576d5e6d9bd8fac71c0c
```

RAW output is the 64 bytes decoded from this digest. Both suites check the fixture against standard-library SHA3-512.
Validation fixtures do not need a cryptographic response.

## Language Exceptions

- Go payloads are structs passed by value. `nil` payloads and wrong field types cannot compile; use a zero-value payload to test missing required fields. JS must reject missing payloads and wrong runtime types.
- Go rejects nil hash input but accepts a non-nil empty slice. JS rejects missing input but accepts an empty `Uint8Array` or `Buffer`.
- Existing ID behavior differs for explicitly empty metadata IDs: JS generates an ID; Go preserves the empty ID when metadata is non-nil. This change tests omitted metadata and supplied non-empty IDs.
- Go timestamps use `*time.Time`; a provided zero time is rejected. JS uses uint64-compatible values and tests a bigint above uint64 range. These are language-specific rejection cases.
- Use named protobuf enum values. Go rejects UNSPECIFIED output formats; JS currently accepts that recognized zero value. Both clients reject unrecognized enum values. Valid Go fixtures must set a format explicitly.
- Go string limits count UTF-8 bytes; existing JS limits count UTF-16 code units. Shared length fixtures use ASCII. Unicode length behavior remains different.

Field names below use JS/protobuf spelling: for example, `csr` maps to Go `CSR`, and `metadata.traceContext.traceId` maps to Go `Metadata.TraceContext.TraceId`.

## HashData

| Category | Scenario | Expected outcome | Go / JS tests |
| --- | --- | --- | --- |
| validation | Missing payload, or a Go zero-value payload. | Reject before gRPC; Go reports the missing profile. | tested / tested |
| validation | Empty profile, or profile over 64 ASCII characters. | Reject with a profile error. | tested / tested |
| validation | Missing/nil input, or a string instead of bytes in JS. | Reject with an input error. | tested / tested |
| validation | Input exceeds 1 MiB. | Reject with an input error. | tested / tested |
| validation | Unrecognized output value. | Reject with an output-format error. | tested / tested |
| validation | Trace ID exceeds 32 ASCII characters. | Reject with a `metadata.traceContext.traceId` error. | tested / tested |
| happy-path | Canonical input with HEX or RAW output. | Forward input/profile/output format; return the reference digest and algorithm. | tested / tested |
| happy-path | Explicitly empty, non-nil byte input. | Accept it; the server computes the empty-input digest. | tested / tested |
| metadata | Metadata is omitted (`Metadata: nil` in Go). | Send a non-empty UUIDv4 ID in the outbound request. | tested / tested |
| metadata | A non-empty ID is supplied. | Preserve the ID in the outbound request. | tested / tested |
| error-propagation | gRPC returns an error. | Return the error; do not report a successful hash. | tested / tested |
| error-propagation | JS circuit breaker reaches its failure threshold. | Reject while open; allow a probe after the reset interval. | JS-specific / tested |

## SignCertificate

| Category | Scenario | Expected outcome | Go / JS tests |
| --- | --- | --- | --- |
| validation | Missing payload, or a Go zero-value payload. | Reject before gRPC. | tested / tested |
| validation | Empty profile, or profile over 64 ASCII characters. | Reject with a profile error. | tested / tested |
| validation | CSR, CA private key or CA certificate is missing or empty. | Reject with the field name. | tested / tested |
| validation | CSR, CA private key or CA certificate exceeds 64 KiB. | Reject with the field name. | tested / tested |
| validation | Subject exceeds 1024 ASCII characters. | Reject with a subject error. | tested / tested |
| validation | CRL distribution points exceed 16 entries, or an entry exceeds 2048 ASCII characters. | Reject with the field name or entry index. | tested / tested |
| validation | JS receives a non-string CRL entry. | Reject with the entry index; Go's compiler prevents this input. | compiler / tested |
| validation | Invalid timestamp value or unrecognized output value. | Reject with the field name. | tested / tested |
| happy-path | Valid fields with PEM output. | Return the mocked PEM certificate. | tested / tested |
| happy-path | Valid fields with DER output. | Return the mocked DER bytes. | tested / missing |
| metadata | Metadata is omitted. | Generate a UUIDv4 ID in the outbound request. | tested / tested |
| metadata | A non-empty ID is supplied. | Preserve the ID in the outbound request. | tested / tested |
| error-propagation | gRPC returns an error. | Return the error; do not report a successful certificate. | tested / missing |

## Benchmark

| Category | Scenario | Expected outcome | Go / JS tests |
| --- | --- | --- | --- |
| validation | Metadata ID exceeds 128 ASCII characters. | Reject with a `metadata.id` error before gRPC. | tested / tested |
| happy-path | Server returns valid benchmark JSON. | Go returns parsed results; JS returns the response with the JSON string. | tested / tested |
| metadata | Metadata is omitted. | Generate a UUIDv4 request ID. | tested / tested |
| error-propagation | gRPC returns an error. | Return the error. | tested / missing |
| error-propagation | Server returns malformed JSON. | Go returns a decode error; JS leaves decoding to the caller. | tested / caller-owned |

## HealthData

| Category | Scenario | Expected outcome | Go / JS tests |
| --- | --- | --- | --- |
| validation | No application payload is required. | Send an empty health-check request. | protocol / protocol |
| happy-path | Server reports SERVING. | Return the language's serving status. | tested / tested |
| metadata | Standard gRPC health protocol. | No Crypto Broker request ID is required. | protocol / protocol |
| error-propagation | Health RPC fails. | Return UNKNOWN instead of raising the RPC error. | tested / tested |

## Other Current Operations

`helper` means shared Go metadata-helper coverage; `partial` means only some grouped validation cases have tests in that library. These gaps do not expand the implementation scope of issue #407.

| Operation | Category | Scenario | Expected outcome | Go / JS tests |
| --- | --- | --- | --- | --- |
| EncryptData | validation | Invalid key source, required fields/types, or protobuf size limits. | Reject before gRPC. | partial / partial |
| EncryptData | happy-path | Valid key and plaintext. | Return mocked ciphertext and cipher metadata. | tested / tested |
| EncryptData | metadata | Metadata is omitted. | Generate a request ID. | tested / tested |
| EncryptData | error-propagation | gRPC fails. | Return the error. | tested / missing |
| DecryptData | validation | Invalid key source, required fields/types, or protobuf size limits. | Reject before gRPC. | partial / partial |
| DecryptData | happy-path | Valid key and ciphertext. | Return mocked plaintext. | tested / tested |
| DecryptData | metadata | Metadata is omitted. | Generate a request ID. | tested / tested |
| DecryptData | error-propagation | gRPC fails. | Return the error. | tested / missing |
| SignData | validation | Invalid profile, input, key source, metadata or signature format. | Reject before gRPC. | partial / tested |
| SignData | happy-path | Valid key and input. | Return mocked signature bytes. | tested / tested |
| SignData | metadata | Metadata is omitted. | Generate a request ID. | helper / tested |
| SignData | error-propagation | gRPC fails. | Return the error. | missing / missing |
| VerifyData | validation | Invalid profile, input, key source, metadata, signature or format. | Reject before gRPC. | partial / partial |
| VerifyData | happy-path | Valid input and signature. | Return the mocked validity flag. | tested / tested |
| VerifyData | metadata | Metadata is omitted. | Generate a request ID. | helper / tested |
| VerifyData | error-propagation | gRPC fails. | Return the error. | missing / missing |

## Scope and Test Locations

The required cross-language scenarios above cover HashData, SignCertificate, Benchmark and HealthData for issue #407.
Field size limits come from the shared protobuf `PayloadLimits` enums; use those constants in new fixtures. Other metadata size checks have direct Go validator tests. Limits are 128 for ID, 32 for trace ID, 16 for span ID, 2 for trace flags, 512 for trace state, and 128 for correlation ID; they are maximum lengths, not exact W3C identifier lengths.
The coverage column records the remaining public-test gaps. Other trace-field limits have direct Go tests but no matching JS regression tests on this baseline.
Go's FakeEndpoint has no public JS counterpart. The newer operations above are an inventory of existing behavior; their implementation is unchanged by this issue.

Go tests are in `hash_data_test.go`, `sign_certificate_test.go`, `benchmark_test.go`, `payload_limits_test.go`, `metadata_test.go` and `health_test.go`. The issue uses the former names `hash_test.go` and `sign_test.go`.
JS tests are split by operation under `src/lib/tests/client.*.test.ts`, with shared mocks in `client.test-setup.ts` and helpers in `client.test-utils.ts`.
Run `go test ./...` in the Go client and `npm test -- --runInBand` in the JS client.
