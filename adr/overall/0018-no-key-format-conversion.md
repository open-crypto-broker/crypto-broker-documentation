---
status: proposed
date: 2026-11-19
decision-makers: Maximilian Lenkeit, Stephan Andre, Anselme Tueno
consulted: Robin Winzler, Miyana Stange, Pawel Chmielewski, Damian Jankowski
---

# No Key Format Conversion for Caller-Managed Keys

## Context and Problem Statement

The `SignCertificate`, `SignData` and `VerifyData` APIs accept caller-managed asymmetric keys as `raw_key`.
[ADR 0015](0015-sign-verify-data-api.md) defines the wire format: a DER-encoded PKCS #8 `OneAsymmetricKey` for private keys and a DER-encoded `SubjectPublicKeyInfo` for public keys.
It leaves open which input formats the applications may hand to the client libraries and what happens to keys in other formats.

Private keys exist in several formats in practice:

* PKCS #8 (`PRIVATE KEY`, [RFC 5958](https://www.rfc-editor.org/rfc/rfc5958)) — algorithm-independent, carries an algorithm identifier.
* PKCS #1 (`RSA PRIVATE KEY`, [RFC 8017](https://www.rfc-editor.org/rfc/rfc8017)) — RSA only.
* SEC 1 (`EC PRIVATE KEY`, [RFC 5915](https://www.rfc-editor.org/rfc/rfc5915)) — EC only.
* Encrypted PKCS #8 (`ENCRYPTED PRIVATE KEY`) and legacy encrypted PEM (`Proc-Type: 4,ENCRYPTED`).

Public keys exist as `SubjectPublicKeyInfo` (`PUBLIC KEY`), PKCS #1 (`RSA PUBLIC KEY`) or embedded in a certificate.
Each of them may be PEM- or DER-encoded.

Before this ADR, the [Library Specification](../../spec/0002-library.md#key-encoding) required the client libraries to accept PEM and DER and send them unchanged to the server.
The server implementation then worked as follows: it decodes PEM, tries the PKCS #1, PKCS #8 and SEC 1 parsers one after the other on unlabelled DER and on PEM blocks with unknown labels, accepts PKCS #1 public keys and certificates in place of a public key, and expects the CA key of `SignCertificate` as PEM.

The question is where — if anywhere — key format conversion should happen, and how much of the key the client libraries should inspect.

## Decision Drivers

* Minimize the code that handles plaintext private key material, in particular code that rewrites it
* Avoid security-relevant logic that has to be re-implemented in every client library
* The server is the trust boundary and has to validate every key anyway
* One unambiguous key format per API; no format guessing
* Applications that already hold PKCS #8 keys must not be affected
* Clear, actionable errors for applications that hold keys in other formats
* Avoid repeated work: a key converted once by the application does not need to be converted again on every request

## Considered Options

* **A — Server-side conversion:** the server accepts all common formats (PEM or DER; PKCS #1, SEC 1, PKCS #8) and normalizes them (status quo of the server implementation).
* **B — Client-side conversion with structure check:** the client libraries decode PEM, convert PKCS #1 and SEC 1 to PKCS #8 and check the DER structure; the server accepts PKCS #8 and `SubjectPublicKeyInfo` only.
* **C — PKCS #8 and `SubjectPublicKeyInfo` only, no conversion anywhere:** the application supplies the key in the target format, PEM- or DER-encoded; the client libraries only decode PEM; the server validates strictly.
* **D — DER only:** like C, but the client libraries do not decode PEM either.

## Decision Outcome

Chosen option: **C — PKCS #8 and `SubjectPublicKeyInfo` only, no conversion anywhere**, because it removes all conversion and hand-written DER inspection from both the server and the client libraries, while keeping the common case — an application holding a PEM-encoded PKCS #8 key — as simple as before.

* Private keys must be supplied as PKCS #8 `OneAsymmetricKey` (unencrypted, `v1` or `v2`), public keys as `SubjectPublicKeyInfo`.
  Keys in any other format are rejected; the application has to convert them once, e.g. at provisioning time.
* The client libraries accept the key PEM- or DER-encoded.
  They decode PEM (exactly one block with the label `PRIVATE KEY` or `PUBLIC KEY`, depending on the API) and pass DER through unchanged.
  They do not inspect, convert or validate the DER content.
* The server is the only component that parses the DER content.
  It uses exactly one parser per API, chosen by the expected format, and rejects everything else with an error that names the expected format.
  It does not decode PEM and does not guess formats.
* Rules that the client structure check enforced so far, in particular the seed-only form of ML-DSA private keys, are enforced by the server.

### Consequences

* Good, because no component of the Crypto Broker rewrites private key material
* Good, because ASN.1 parsing of key material happens in exactly one place, using the crypto library of the server, instead of once per client library
* Good, because the client libraries become thinner and easier to keep consistent across languages
* Good, because every API accepts exactly one key format, so there is no format guessing or parser differential
* Good, because the conversion is done once by the application instead on every request
* Bad, because applications holding PKCS #1 or SEC 1 keys have to convert them first (see [Migration for applications](#migration-for-applications))
* Bad, because malformed DER is no longer detected before the request is sent; the error comes from the server
* Bad, because the server implementation has to be made stricter, which is a breaking change for callers currently relying on the lenient parsing (PEM, PKCS #1, SEC 1, certificates as public keys, the `ML-DSA PRIVATE KEY` PEM label)

### Confirmation

* Server tests: for each API, a key in every rejected format (PEM, PKCS #1, SEC 1, encrypted PKCS #8, PKCS #1 public key, certificate, DER with trailing bytes, ML-DSA expanded and combined form) is rejected, and PKCS #8 `v1`/`v2` and `SubjectPublicKeyInfo` are accepted.
* Client tests: PEM with an allowed label is decoded; PEM with any other label, multiple blocks or PEM headers is rejected before sending; DER input reaches the server byte for byte unchanged.
* Code review: no client library contains an ASN.1/DER parser or format conversion for keys.

## Security Considerations

### Conversion code handles plaintext private keys

Converting PKCS #1 or SEC 1 to PKCS #8 means parsing a private key and re-encoding it.
A bug in this step can produce a different key than intended, write key bytes into error messages or logs, or leave additional copies of the key in memory that are never zeroized.
On the client, such a bug affects one application; on the server, it affects every caller of the deployment, and the server's memory holds keys of all of them.
With option C, no component rewrites keys, so this class of bugs does not exist.

### Format guessing increases the attack surface

Unlabelled DER does not say which format it is.
A server or library that tries several parsers one after the other exposes all of them to untrusted input and may interpret the same bytes differently than the caller intended (parser differential).
Accepting a certificate where a public key is expected additionally suggests a check of the certificate (validity, revocation, issuer) that does not take place.
Option C uses exactly one parser per API, selected by the API rather than by the input.

### Hand-written DER inspection in every client library

The structure check of option B has to be implemented separately in each client library, usually without a full ASN.1 library.
Hand-written DER parsing is a well-known source of bugs: length handling, long-form and indefinite lengths, BER instead of DER, trailing bytes, nested lengths that exceed the outer element.
Every additional client library adds another implementation with its own bugs.

The client check is also not a security control.
The gRPC socket can be used without the client library, so the server has to validate every key regardless.
The client check only produced earlier error messages, and it was a second definition of "valid key" that could drift from the server's.

### Server-side validation

Because the client libraries no longer inspect the key, the server must validate it completely before any cryptographic operation (see [Server Specification](../../spec/0003-server.md#raw-key-validation)):

* The input is a single DER element without trailing bytes; PEM and BER are rejected.
* Private keys are unencrypted PKCS #8 `OneAsymmetricKey` (`v1` or `v2`); public keys are `SubjectPublicKeyInfo`.
* The algorithm identifier of the key matches the algorithm of the profile.
* ML-DSA private keys use the seed-only form of [RFC 9881](https://www.rfc-editor.org/rfc/rfc9881); the expanded and the combined form are rejected explicitly, even if the crypto library could load them.
* Buffers holding decoded private key material are zeroized after use.

### PEM decoding in the client libraries

PEM decoding remains in the client libraries, because applications typically hold their keys as PEM.
It is limited to removing the encapsulation boundaries and decoding Base64 ([RFC 7468](https://www.rfc-editor.org/rfc/rfc7468)), which most platforms provide in their standard library.
The label check is a string comparison and does not interpret the key.
Requiring exactly one block without headers prevents ambiguous input, such as the `EC PARAMETERS` block that `openssl ecparam -genkey` writes before the key, or legacy encrypted PEM.

## Migration for applications

Applications that hold keys in another format convert them once, for example:

| Situation | Conversion |
| --- | --- |
| PKCS #1 or SEC 1 private key (`RSA PRIVATE KEY`, `EC PRIVATE KEY`) | `openssl pkcs8 -topk8 -nocrypt -in key.pem -out key-pkcs8.pem` |
| PKCS #1 public key (`RSA PUBLIC KEY`) | `openssl rsa -RSAPublicKey_in -in pub.pem -pubout -out pub-spki.pem` |
| Public key in a certificate | `openssl x509 -in cert.pem -pubkey -noout -out pub-spki.pem` |
| DER output instead of PEM | add `-outform DER` to the commands above |

Common sources of non-PKCS #8 keys are OpenSSL before 3.0 (`genrsa`), `openssl ecparam -genkey`, Go's `x509.MarshalPKCS1PrivateKey` and `x509.MarshalECPrivateKey` (instead of `x509.MarshalPKCS8PrivateKey`), Node.js `crypto` with `type: 'pkcs1'` or `type: 'sec1'` (instead of `type: 'pkcs8'`) and cert-manager, whose `privateKey.encoding` defaults to `PKCS1` and can be set to `PKCS8`.

## Pros and Cons of the Options

### A — Server-side conversion

* Good, because applications can send keys in any common format
* Bad, because the server rewrites private keys of all callers; a bug affects every application of the deployment
* Bad, because format guessing exposes several parsers to untrusted input
* Bad, because the conversion runs on every request
* Bad, because it contradicts [ADR 0015](0015-sign-verify-data-api.md), which keeps PEM and format detection out of the server

### B — Client-side conversion with structure check

* Good, because applications can supply PKCS #1 and SEC 1 keys
* Good, because malformed keys are rejected before the request is sent
* Neutral, because conversion bugs only affect the application using the faulty library
* Bad, because conversion and a hand-written DER parser have to be implemented, tested and maintained in every client library
* Bad, because the structure check does not replace the server validation and can drift from it
* Bad, because the conversion runs on every request

### C — PKCS #8 and `SubjectPublicKeyInfo` only, no conversion anywhere

* Good, because no component rewrites private key material
* Good, because only the server parses DER, with exactly one parser per API
* Good, because the client libraries only decode PEM, a small and well-supported operation
* Good, because PKCS #8 is the default output of current tooling
* Bad, because applications with PKCS #1 or SEC 1 keys have to convert them once
* Bad, because malformed DER is only detected by the server

### D — DER only

* Good, because the client libraries do not touch the key at all
* Bad, because almost every application holds PEM and would have to implement PEM decoding itself, i.e. the same code moves into every application instead of every client library
* Neutral, because PEM decoding does not interpret the key, so removing it from the client libraries does not improve security noticeably

## More Information

Refines the key encoding decision of the [SignData/VerifyData API ADR](0015-sign-verify-data-api.md) and also applies to the CA key of `SignCertificate`.
The resulting rules are specified in the [Library Specification](../../spec/0002-library.md#key-encoding) and the [Server Specification](../../spec/0003-server.md#raw-key-validation).
