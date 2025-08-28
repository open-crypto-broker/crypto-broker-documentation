# Crypto Broker Server Specification

## Overview

The Crypto Broker service provides remote cryptographic operations over gRPC, including:

- Hashing arbitrary binary data.
- Signing X.509 certificates based on Certificate Signing Requests (CSRs).

This specification describes the components, packages, methods and the behavior and processing logic implemented by the Crypto Broker server.
The server does not expose cryptographic functionality directly, instead it validates requests against predefined external profiles and delegates approved operations to an underlying cryptographic backend using the native `Go` crypto library.

---

## Transport and Connection

- The server listens for gRPC requests over a Unix domain socket.
- The socket path is `/tmp/cryptobroker.sock`

The server expects connections from clients using a compatible language-specific Crypto Broker library.
All incoming requests are validated, logged, and processed in accordance with the security policies defined in the provided profiles.
The Crypto Broker returns a response to the requested cryptographic operation or an error if the request could not be handled due to an internal failure.
Verbose error handling is implemented, such that (in case of an erorr) the client is notified which part of the Crypto Broker operation failed.

---

## Packages, Components and Structure

There are three main directories that are relevant for the Crypto Broker Server. The `cmd/` and `internal/` directories contain the implementation and all used packages, whereas the `profiles/` directory contains the `Profiles.yaml` file, listing all supported profile.

The Crypto Broker server contains the following packages:

- `main` -> `(cmd/server/)`
- `api` -> `(internal/)`
- `c10y` -> `(internal/)`
- `di` -> `(internal/)`
- `env` -> `(internal/)`
- `profile` -> `(internal/)`
- `protobuf` -> `(internal/)`

The contents of the packages are described below.

## `main`

### Description

This package contains the `server.go` code, which marks the entry point for the Crypto Broker server.
The server performs the following steps:

1. Initializes the dependency container (logger, server logic, profile loading).
1. Ensures the socket directory exists (`/tmp`).
1. Opens a Unix socket at `/tmp/cryptobroker.sock`.
1. Starts a gRPC server and registers the Crypto Broker service.
1. Waits for system signals `SIGTERM` to gracefully shut down.
1. Cleans up the Unix socket file after shutdown.

### Constants and Configurations

| Name            | Type   | Description |
|---------------------|--------|-------------|
| `baseDir`           | `string` | Base directory for socket file: `/tmp`. |
| `defaultSocketPath` | `string` | Full path of the Unix socket file: `/tmp/cryptobroker.sock`. |
| `defaultProfiles`   | `string` | Name of the YAML file containing profile definitions: `Profiles.yaml`. |

---

## `api`

### Description

This package implements the API endpoints that are exposed to the Crypto Broker service.
More specifically, it defines the functions `Hash()` and `Sign()`, which are invoked by incoming requests.
These functions then in turn invoke the internal `hash()` and `sign()` functions, that call cryptographic functions from the `c10y` package to execute the operation.
This package also orchestrates profile retrieval and input validation, i.e., parsing cryptographic files and checking their correctness.

### Dependencies

The `api` package depends on the following internal packages:

| Package | Purpose |
|--------|---------|
| `c10y` | Interface to the cryptographic backend libraries (e.g., hashing, signing, validation). |
| `profile` | Loads and validates the profiles. |
| `protobuf` | Contains the gRPC service definitions and message types. |

### Type Definitions

The `CryptoBrokerServer` struct represents the core server object handling cryptographic operations via gRPC, whereas the `NewCryptoBrokerServer` constructor creates a new instance of the `CryptoBrokerServer`.

### `CryptoBrokerServer`

| Field | Type   | Description |
|----------|--------|-------------|
| logger   | `*log.Logger`  | Logger used for server-side logging. |
| -   | `protobuf.CryptoBrokerServer`  | Server API for the gRPC Crypto Broker service. |
| cryptographicEngineNative | `*c10y.LibraryNative`  | A reference to the Go native crypto engine implementation. |

### `NewCryptoBrokerServer`

This is the constructor for the `CryptoBrokerServer` struct.

#### Input Parameters

| Name    | Type   | Description |
|-------------|--------|-------------|
| `c10yNative` | `*c10y.LibraryNative` | A reference to the Go native crypto engine implementation. |
| `logger` | `*log.Logger` | Logger used for server-side logging. |

#### Output

| Type   | Description |
|--------|-------------|
| `*CryptoBrokerServer`  | An instance of the Crypto Broker server. |

### Methods

### `Hash`

This API function loads the profile specified in `req.Profile`, uses the algorithm defined in the profile to hash the `req.HashInput`, logs the time taken by the operation and returns a `*protobuf.HashResponse`.

#### Input Parameters

| Name    | Type   | Description |
|-------------|--------|-------------|
| `ctx` | `*context.Context`  | Request context (used for timeouts, etc.). |
| `req` | `*protobuf.HashRequest`  | Input message containing the profile name and data to hash. |

#### Output

| Type   | Description |
|--------|-------------|
| `*protobuf.HashResponse`  | Hash output packed into a struct containing the hash value and the hash algorithm. |

### `Sign`

This API function loads the profile specified in `req.Profile`, parses and validates the CSR and signing key, validates key constraints as specified in the profile, signs the CSR using the provided CA credentials and profile-defined options, logs the execution time and returns a `*protobuf.SignResponse`.

#### Input Parameters

| Name    | Type   | Description |
|-------------|--------|-------------|
| `ctx` | `*context.Context`  | Request context (used for timeouts, etc.). |
| `req` | `*protobuf.SignRequest`  | Contains the CSR, CA certificate, signing key, and profile name. |

#### Output

| Type   | Description |
|--------|-------------|
| `*protobuf.SignResponse`  | Signed certificate packed into a struct. |

### `hash`

This is an internal helper function. It computes a hash of the given data using the algorithm defined in the profile.

#### Input Parameters

| Name    | Type   | Description |
|-------------|--------|-------------|
| `data` | `[]byte`  | Data to be hashed. |
| `p` | `profile.Profile`  | The selected cryptographic profile. |

#### Output

| Type   | Description |
|--------|-------------|
| `c10y.Hash`  | Computed hash. |
| `error`  | Error string if the operation fails. |

#### Supported Hash Algorithms

- SHA-256
- SHA-384
- SHA-512
- SHA3-256
- SHA3-384
- SHA3-512
- SHA-512/256
- SHAKE128 (currently hardcoded to 16 byte output size)
- SHAKE256 (currently hardcoded to 32 byte output size)

### `sign`

This is an internal helper function. It computes a hash of the given data using the algorithm defined in the profile.

#### Input Parameters

| Name    | Type   | Description |
|-------------|--------|-------------|
| `clientInput` | `signClientInput`  | Struct containing PEM-encoded CSR, CA certificate, and CA private key. |
| `p` | `profile.Profile`  | The selected cryptographic profile. |

#### Output

| Type   | Description |
|--------|-------------|
| `[]byte`  | Signed certificate. |
| `error`  | Error string if the operation fails. |

---

## `c10y`

### Description

This package contains the logic that invokes cryptographic operations from the `Go` native cryptographic library.
In particular, the `SignCertificate` API invokes functions from the `crypto/x509` library, whereas `HashData` invokes standard hash functions.
Furthermore, all cryptographically relevant structs and variables are defined in this package.
In addition, helper functions to parse cryptographically relevant files and map profile/application input to cryptographical primitives are implemented here.

### Constants and Configurations

This package contains the definition of strings defining the supported key usages and extended key usages, as well as constant identifiers for supported algorithms.
Key Usage identifiers are aligned with the respective string identifiers in  [RFC 5280 Section 4.2.1.3](https://datatracker.ietf.org/doc/html/rfc5280#section-4.2.1.3) and Extended Key Usage are aligned with [RFC 5280 Section 4.2.1.12](https://datatracker.ietf.org/doc/html/rfc5280#section-4.2.1.12).
Hash algorithm identifiers are derived from [FIPS 180-4](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf) for SHA2 and [FIPS 202](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.202.pdf) for SHA3.
Signature algorithm identifiers are `rsa` and `ecdsa`.

### Dependencies

The `c10y` package depends on the following packages:

| Package | Purpose |
|--------|---------|
| `crypto` | ECDSA, RSA, X.509, and PKIX support. |
| `encoding` | ASN.1 and PEM support. |

### Type Definitions

The types `Hash`, `Algorithm` and `Operation` are strings.
The following types are structs with the listed attributes.

### `SignAPIOpts`

This struct holds parameters provided by the application.

| Field | Type | Decription |
|------|------|-----------|
| CACert | `*x509.Certificate` | Holds the CA certificate. |
| PrivateKey | `any` | Holds the CA private key. Can be an ECDSA or RSA key, as per currently supported signing algorithms. |
| CSR | `*x509.CertificateRequest` | Holds the CSR. |
| Subject | `pkix.Name` | Holds an optionally provided Subject, given by the application. |

### `SignProfileOpts`

This struct holds parameters provided by the profile.

| Field | Type | Decription |
|------|------|-----------|
| SignatureAlgorithm | `x509.SignatureAlgorithm` | Holds the signature algorithm to be applied in the certificate signing operation. |
| Validity | `SignProfileValidity` | Holds the certificate validity period given in the profile. |
| KeyUsage | `SignProfileOptsKeyUsage` | Holds the key usage extension given in the profile. |
| ExtendedKeyUsage | `SignProfileExtendedKeyUsage` | Holds the extended key usage extension given in the profile. |
| BasicConstraints | `SignProfileBasicConstraints` | Holds the basic constraints extension given in the profile. |

### `SignProfileValidity`

| Field | Type | Decription |
|------|------|-----------|
| NotBefore | [`time.Duration`](https://pkg.go.dev/time#Duration) | Holds the notBefore attribute of the X.509 certificate. |
| NotAfter | [`time.Duration`](https://pkg.go.dev/time#Duration) | Holds the notAfter attribute of the X.509 certificate. |

### `SignProfileOptsKeyUsage`

| Field | Type | Decription |
|------|------|-----------|
| Flags | `[]x509.KeyUsage` | Holds bitmap of the combined key usages. |

### `SignProfileBasicConstraints`

| Field | Type | Decription |
|------|------|-----------|
| IsCA | `bool` | Holds configuration whether the generated certificate is a CA. |
| PathLenConstraint | `int` | Holds the path length constraint of the generated certificate if it is a CA. |

### `SignProfileExtendedKeyUsage`

| Field | Type | Decription |
|------|------|-----------|
| Usages | `[]x509.ExtKeyUsage` | Holds a set of extended key usages. |

### `BitSizeConstraints`

| Field | Type | Decription |
|------|------|-----------|
| MinKeySize | `int` | Holds the minimum allowed key size. |
| MaxKeySize | `int` | Holds the maximum allowed key size. |

### Methods

### `ParseX509Cert`

Parses a PEM-encoded X.509 certificate.

#### Input Parameters

| Name    | Type   | Description |
|-------------|--------|-------------|
| `rawCert` | `[]byte`  | PEM-encoded certificate bytes. |

#### Output

| Type   | Description |
|--------|-------------|
| `*x509.Certificate`  | Parsed certificate. |
| `error`  | Error string if the operation fails. |

### `ParsePrivateKeyFromPEM`

Parses a PEM-encoded private key, supporting RSA (PKCS#1 & PKCS#8) and ECDSA keys.

#### Input Parameters

| Name    | Type   | Description |
|-------------|--------|-------------|
| `key` | `[]byte`  | PEM-encoded key bytes. |

#### Output

| Type   | Description |
|--------|-------------|
| `any`  | Parsed private key as `*rsa.PrivateKey` or `*ecdsa.PrivateKey`. |
| `error`  | Error string if the operation fails. |

### `MapKeyUsageToExtension`

Encodes a key usage flag into a `pkix.Extension` structure.

#### Input Parameters

| Name    | Type   | Description |
|-------------|--------|-------------|
| `usage` | `x509.KeyUsage`  | Set of key usages. |

#### Output

| Type   | Description |
|--------|-------------|
| `pkix.Extension`  | Key usages mapped from X.509 format to a bitstring, encoded in ASN.1 and then put into an extension. |
| `error`  | Error string if the operation fails. |

### `MapStringToKeyUsage`

Maps a string keyword to an `x509.KeyUsage`.

#### Input Parameters

| Name    | Type   | Description |
|-------------|--------|-------------|
| `in` | `string`  | String identifier of a key usage. |

#### Output

| Type   | Description |
|--------|-------------|
| `x509.KeyUsage`  | Key usage mapped to the respective `x509` constant. |
| `error`  | Error string if the operation fails. |

### `MapExtKeyUsage`

Maps a string keyword to an `x509.ExtKeyUsage`.

#### Input Parameters

| Name    | Type   | Description |
|-------------|--------|-------------|
| `in` | `string`  | String identifier of an extended key usage. |

#### Output

| Type   | Description |
|--------|-------------|
| `x509.ExtKeyUsage`  | Extended key usage mapped to the respective `x509` constant. |
| `error`  | Error string if the operation fails. |

### `ComposeSignatureAlgorithm`

Determines a valid `x509.SignatureAlgorithm` from a signature and hash algorithm pair.

#### Input Parameters

| Name    | Type   | Description |
|-------------|--------|-------------|
| `signAlg` | `Algorithm`  | String identifier of a signature algorithm. |
| `hashAlg` | `Algorithm`  | String identifier of a hash algorithm. |

#### Output

| Type   | Description |
|--------|-------------|
| `x509.SignatureAlgorithm`  | Combined signature algorithm consisting of a hash and signature algorithm. |
| `error`  | Error string if the operation fails or the combination is not supported. |

#### Supported Hash/Sign Algorithms

The supported hash algorithms for certificate generation are `SHA-256`, `SHA-384` and `SHA-512`.
As per signature algorithms, the server currently supports `RSA` and `ECDSA`.

### `ValidatePublicKey`/`ValidatePrivateKey`

Validates a public/private key against configured bit size constraints.

#### Input Parameters

| Name    | Type   | Description |
|-------------|--------|-------------|
| `pubKey`/`privKey` | `any` | RSA/ECDSA public/private key as `*rsa.PublicKey`/`*rsa.PrivateKey` or `*ecdsa.PublicKey`/`*ecdsa.PrivateKey`. |
| `constraintsByAlg` | `map[Algorithm]BitSizeConstraints`  | Key length constraints per algorithm. |

#### Output

| Type   | Description |
|--------|-------------|
| `error`  | Error string if the operation fails or the given key is not adhering to key constraints given in the profile. Returns `nil` if checks are passed. |

### `SignCertificate`

Generates and signs a new X.509 certificate using the native Go cryptographic library (`crypto/x509`). This function combines parameters from the profile and API input to produce a valid certificate. It uses `x509.CreateCertificate()` under the hood, providing a template of the type `x509.Certificate` filled with values from the input parameters.

#### Input Parameters

| Name    | Type   | Description |
|-------------|--------|-------------|
| `profileOpts` | `SignProfileOpts` | Certificate signing configuration provided by the profile. |
| `apiOpts` | `SignAPIOpts`  | Certificate signing configuration provided by API parameters. |

#### Output

| Type   | Description |
|--------|-------------|
| `[]byte`  | Signed certificate bytes. |
| `error`  | Error string if the operation fails. |

### All implemented internal `Hash` Functions

All implemented hashing methods provide support for the supported hash functions, implemented using Go's standard `crypto` and `golang.org/x/crypto/sha3` packages.

#### Input Parameters

| Name    | Type   | Description |
|-------------|--------|-------------|
| `dataToHash` | `[]byte` | Data to be hashed. |

#### Output

| Type   | Description |
|--------|-------------|
| `Hash`  | Hash value as lowercase hexadecimal hash string. |
| `error`  | Error string if the operation fails. |

---

## `di`

### Description

This package defines the `Container` struct, which is used to instantiate the server and expose the gRPC endpoints.
It wires together different server dependencies like the logger, the cryptographic engine and the profiles.
This is the internal entry point after the entry from the `main` package has been executed.
From there, it receives the names of the available profiles and calls the `profile` package to load the profiles from the yaml file.
It returns an instance of the API server together with the instantiated cryptographical library in `c10y`.

### Dependencies

The `di` package depends on the following internal packages:

| Package | Purpose |
|--------|---------|
| `api` | Supplies the gRPC service with the defined API endpoints. |
| `c10y` | Interface to the cryptographic backend libraries (e.g., hashing, signing, validation). |
| `profile` | Loads and validates the profiles. |

### Type Definitions

The `Container` struct holds dependencies required to run the server, whereas the `NewContainer` constructor creates a new instance of the `Container`.

### `Container`

| Field    | Type   | Description |
|-------------|--------|-------------|
| `Server` | `*api.CryptoBrokerServer` | An instance of the gRPC implementation of the Crypto Broker server API. |
| `Logger` | `*log.Logger` | Logger used for server-side logging. |

### `NewContainer`

This is the constructor for the `Container` struct.

#### Input Parameters

| Name    | Type   | Description |
|-------------|--------|-------------|
| `profiles` | `string` | Path to the `Profiles.yaml` file containing the list of profiles. |

#### Output

| Type   | Description |
|--------|-------------|
| `*Container`  | A fully initialized dependency container. |

---

## `env`

### Description

This package defines environment variables used by the Crypto Broker.

### Constants and Configurations

Currently, the `env.go` file contains the constant `CRYPTO_BROKER_PROFILES_DIR`, which holds the OS path to the directory of the `Profiles.yaml` file.

---

## `profile`

### Description

This package implements the profile concept.
The file `profile.go` defines the structs for profile contents, while `LoadProfiles()` in `general.go` validates the provided yaml file and calls `mapToProfile()` in `raw_profile.go` on each contained profile separately to fill in the `Profile` struct and return a map with all profiles names and their contents to the Crypto Broker instance.
In addition, while loading a profile in `raw_profile.go`, the Crypto Broker server validates any given API parameters by checking whether they are allowed by profile rules, such as key constraints for private and public keys and certificate validity.
Loading the profile is the first step of the activity diagram, which on successful completion, continues with the socket creation.

### Dependencies

The `profile` package depends on the following packages:

| Package | Purpose |
|--------|---------|
| `crypto/x509` | Mainly for X.509 support in order to map strings to the respective (extended) key usage. |
| `c10y` | Integration of internal cryptography package. |
| `env` | Environment value for profile path. |

### Type Definitions

### `Profile`

Represents a cryptographic profile, including metadata and API specifications.

| Field     | Type            | Description                                 |
|-----------|-----------------|---------------------------------------------|
| `Name`    | `string`        | The name of the profile.                    |
| `Settings`| `ProfileSettings` | Global configuration settings for the profile.   |
| `API`     | `ProfileAPI`    | Specifies supported cryptographic functions, currently including `HashData` and `SignCertificate`. |

### `ProfileSettings`

Defines configuration settings for a profile.

| Field            | Type     | Description                            |
|------------------|----------|----------------------------------------|
| `CryptoLibrary`  | `string` | Name of the crypto library to be used. |

### `ProfileAPI`

Defines the APIs exposed by a profile for cryptographic operations.

| Field             | Type                     | Description                         |
|-------------------|--------------------------|-------------------------------------|
| `SignCertificate` | `ProfileAPISignCertificate` | Configuration for certificate signing. |
| `HashData`        | `ProfileAPIHashData`     | Configuration for hashing.          |
| `SignData`        | `ProfileAPISignData`     | Configuration for data signing.     |

### `ProfileAPIHashData`

Specifies the hash algorithm for data hashing.

| Field     | Type         | Description                |
|-----------|--------------|----------------------------|
| `HashAlg` | `c10y.Algorithm` | Hashing algorithm used.  |

### `ProfileAPISignData`

Specifies the signing algorithm for data signing.

| Field     | Type         | Description                  |
|-----------|--------------|------------------------------|
| `SignAlg` | `c10y.Algorithm` | Signing algorithm used.   |

### `ProfileAPISignCertificate`

Defines settings used during X.509 certificate signing.

| Field                | Type                                           | Description                                   |
|----------------------|------------------------------------------------|-----------------------------------------------|
| `SignAlg`            | `c10y.Algorithm`                               | Algorithm for signing.                        |
| `HashAlg`            | `c10y.Algorithm`                               | Algorihtm for hashing.                       |
| `SignatureAlgorithm` | `x509.SignatureAlgorithm`                      | X.509 signature algorithm including hashing and signing algorithm.                    |
| `Validity`           | `ProfileAPISignCertificateValidity`            | Defines validity period offsets.              |
| `KeyConstraints`     | `ProfileAPISignCertificateKeyConstraints`      | Key size constraints.                         |
| `KeyUsage`           | `ProfileAPISignCertificateKeyUsage`            | X.509 key usage flags.                        |
| `ExtendedKeyUsage`   | `ProfileAPISignCertificateExtendedKeyUsage`    | X.509 extended key usages.                    |
| `BasicConstraints`   | `ProfileAPISignCertificateBasicConstraints`    | X.509 basic constraints settings.             |

### `ProfileAPISignCertificateValidity`

Specifies the certificate validity window as time offsets.

| Field            | Type           | Description                          |
|------------------|----------------|--------------------------------------|
| `NotBeforeOffset`| [`time.Duration`](https://pkg.go.dev/time#Duration) | Time before current for start validity. |
| `NotAfterOffset` | [`time.Duration`](https://pkg.go.dev/time#Duration) | Time after current for end validity. |

### `ProfileAPISignCertificateKeyConstraints`

Key size constraints for certificate subject and issuer.

| Field    | Type                                                  | Description               |
|----------|-------------------------------------------------------|---------------------------|
| `Subject`| `map[c10y.Algorithm]c10y.BitSizeConstraints`          | Subject key size constraints. |
| `Issuer` | `map[c10y.Algorithm]c10y.BitSizeConstraints`          | Issuer key size constraints.  |

### `ProfileAPISignCertificateKeyUsage`

Defines the set of allowed X.509 key usages.

| Field  | Type               | Description         |
|--------|--------------------|---------------------|
| `Flags`| `[]x509.KeyUsage`  | X.509 key usage flags. |

### `ProfileAPISignCertificateExtendedKeyUsage`

Defines allowed X.509 extended key usages.

| Field  | Type                  | Description              |
|--------|-----------------------|--------------------------|
| `Usages`| `[]x509.ExtKeyUsage` | X.509 extended usages.   |

### `ProfileAPISignCertificateBasicConstraints`

Defines basic constraints for certificate signing.

| Field               | Type   | Description                                  |
|---------------------|--------|----------------------------------------------|
| `CA`                | `bool` | Defines whether the generated certificate is a CA certificate. |
| `PathLenConstraint` | `int`  | Path length constraint for CA certificates.  |

### Raw Profile Values

All of the above structs are also implemented for raw profile values parsed from the YAML encoded file, as specified in the [Profile Specification](https://github.tools.sap/apeirora-crypto-agility/crypto-broker-documentation/blob/main/spec/0002-profile-structure.md).
These raw profile structs consist of only Go native `string`, `bool` and `int` data types.
The profile is firstly parsed via the raw profile structs and then mapped to the strongly-typed internal profile struct containing more sophisticated data types.

### Methods

### `init`

Initializes the `profilesRootDir` by reading an environment variable that specifies the absolute OS path to the directory containing profile files.

### `LoadProfiles`

Parses and validates YAML-formatted profiles from the provided filename. Sets the global `profiles` map with parsed and validated entries.

#### Input Parameters

| Name         | Type     | Description                                         |
|------------------|----------|-----------------------------------------------------|
| profilesFileName | `string`   | Name of the profile YAML file in the root directory, currently set to `Profiles.yaml`.|

#### Output

| Type  | Description                                     |
|-------|-------------------------------------------------|
| error | Error if file reading, parsing, or validation fails. Otherwise `nil`. |

### `Retrieve`

Returns a specific profile by its name from the global `profiles` map, which contains all parsed profiles from `Profiles.yaml`.

#### Input Parameters

| Name | Type   | Description             |
|----------|--------|-------------------------|
| name     | string | Name of the profile to retrieve.|

#### Output

| Type    | Description                                         |
|---------|-----------------------------------------------------|
| Profile | The corresponding Profile object if it exists.     |
| error   | Error if profiles are not loaded or name is unknown.|

### `mapToProfile`

Transforms a `rawProfile` parsed from YAML into a validated, strongly-typed `Profile`.

#### Input Parameters

| Name | Type       | Description                      |
|----------|------------|----------------------------------|
| p        | rawProfile | The raw profile parsed from YAML.|

#### Output

| Type    | Description                                         |
|---------|-----------------------------------------------------|
| Profile | A validated  profile.             |
| error   | An error if validation fails or transformation fails.|

### `validate`

The `validate` method can be applied to multiple instances of Crypto Broker parameters, in order to verify its validity.
Any profile entries that are not supported by the implementation throw an error.
Types where this method is applicable are:

- `rawProfile`
- `rawProfileSettings`
- `rawProfileAPI`
- `rawProfileAPISignData`
- `rawProfileAPISignCertificate`
- `rawProfileAPISignCertificateValidity`
- `rawProfileAPISignCertificateKeyConstraints`
- `rawProfileAPISignCertificateKeyUsage`
- `rawProfileAPISignCertificateExtendedKeyUsage`
- `rawProfileAPISignCertificateBasicConstraints`

#### Output

| Type  | Description                          |
|-------|--------------------------------------|
| error | Aggregated validation error if any. Otherwise returns `nil`. |

## `protobuf`

### Description

This package defines the gRPC interface exposed to the API and the request/response messages for gRPC.
It contains the gRPC service itself together with request/response messages and registration logic.
The output of this package are marshaled/unmarshaled protobuf messages.

A complete list of defined Protobuf messages as well as their structure and contents for different APIs can be found in the [Crypto Broker Library Specification](https://github.tools.sap/apeirora-crypto-agility/crypto-broker-documentation/blob/main/spec/0003-library.md).

---

## Activity flow

1. Startup

    - Server loads profiles from `Profiles.yaml`
    - Dependepncy injection container initializes logger and cryptographic engine
    - gRPC server is started, listening on a Unix socket on `/tmp/cryptobroker.sock`.

1. Requests

    - Client sends `HashRequest`/`SignRequest` via gRPC.
    - API retrieves the specified profile.
    - Server validates input data/CSR, CA certificate and private signing key.
    - Server selected cryptographic engine and algorithm based on the profile.
    - Hashes data/signs certificate.
    - Returns `HashResponse`/`SignResponse` with hash value/signed certificate and metadata.

1. Error Handling

    - Errors are returned if:
        - the specified profile is missing or invalid.
        - input data is malformed (e.g. invalid CSR).
        - input data does not adhere to profile rules (e.g. key constraints).
        - input data specifies an unknown/unsupported algorithm.
        - a cryptographic operation fails.

1. Shutdown

    - On receiving a termination signal, the server gracefully stops, closes the socket and cleans up resources.

---

## Using the Crypto Broker server

In order to execute the Crypto Broker server, you have to create an executable binary of the server.
With the command `task build-go`, the executable file is created in the `bin` directory.
From there, start the server via

```bash
CRYPTO_BROKER_PROFILES_DIR=/full/path/to/profiles/ ./bin/cryptobroker-server
```

For a detailed instruction on how to run the server and other ways to execute it, please refer to the [Crypto Broker Server README.md](https://github.tools.sap/apeirora-crypto-agility/crypto-broker-server).
