# Profile Specification

This document describes the structure and semantics of the `profile.yaml` file. The file contains one or multiple profiles, each of which can configure settings related to cryptographic operations supported by the Crypto Broker. Profiles can optionally define behavior for one or more APIs, such as data hashing, data signing, and certificate generation.

---

## Fields

### Top-Level Fields (per profile)

| Field       | Type   | Description |
|-------------|--------|-------------|
| `Name`      | String | Name of the profile (e.g., `Default`, `PCI-DSS`). Must be unique. |
| `Settings`  | Map    | Global cryptographic settings, currently supports `CryptoLibrary`. |
| `API`       | Map    | Optional API-specific configuration sections. |

### Notes

- Not all APIs need to be defined in every profile.
- Unspecified sections, incomplete profiles or wrong usage of profile fields should throw an error.

---

## `Settings`

| Field            | Type   | Description |
|------------------|--------|-------------|
| `CryptoLibrary`  | String | The underlying cryptographic library to use (e.g., `openssl` or `native`). |

## API: `HashData`

Configures how data should be hashed.

| Field     | Type   | Description |
|-----------|--------|-------------|
| `HashAlg` | String | The hash algorithm to use (e.g., `SHA-512`, `SHA3-512`). |

## API: `SignHash`

Defines how a hash value of arbitrary data should be digitally signed.

| Field     | Type   | Description |
|-----------|--------|-------------|
| `SignAlg` | String | The signing algorithm to use (e.g., `RSA`). |

## API: `SignCertificate`

Defines settings for signing X.509 certificates.

| Field                     | Type            | Description |
|---------------------------|-----------------|-------------|
| `SignAlg`                 | String          | The signing algorithm used to sign the certificate (e.g., `RSA`). |
| `HashAlg`                 | String          | The hash algorithm used in the certificate signature (e.g., `SHA-256`). |
| `Validity`                | Map             | Specifies certificate validity period offsets. |
| `KeyConstraints`          | Map             | Defines allowed key size constraints per algorithm for the Subject key and the Issuer (CA) key. |
| `KeyUsage`                | List of Strings | List of set key usage flags (e.g., `digitalSignature`, `keyEncipherment`). |
| `ExtendedKeyUsage`        | List of Strings | List of set extended key usage identifiers (e.g., `clientAuth`). |
| `BasicConstraints`        | Map             | Indicates if the certificate is a CA and optionally specifies a path length constraint. |

> Note: A full list of valid strings for `KeyUsage` and `ExtendedKeyUsage` can be found in [RFC 5280 Section 4.2.1.3 Key Usage](https://datatracker.ietf.org/doc/html/rfc5280#section-4.2.1.3) and [RFC 5280 Section 4.2.1.12 Extended Key Usage](https://datatracker.ietf.org/doc/html/rfc5280#section-4.2.1.12).

---

### `Validity`

| Field                  | Type   | Description |
|------------------------|--------|-------------|
| `ValidNotBeforeOffset` | String | Relative time offset when the certificate becomes valid (e.g., `-1h`). |
| `ValidNotAfterOffset`  | String | Relative time offset after which the certificate expires (e.g., `8760h` for 1 year). |

> Note: Time offset formats (e.g., `-1h`, `8760h`) are expected to be strings compatible with Go duration parsing. Please refer to [time@go1.24.3 ParseDuration()](https://pkg.go.dev/time@go1.24.3#ParseDuration) for the syntax definition.

---

### `KeyConstraints`

| Field        | Type   | Description |
|--------------|--------|-------------|
| `Subject`    | Map    | This field specifies key constraints for the CSR's public key. |
| `Issuer`     | Map    | This field specifies key constraints for the CA's public key. |

### `Subject/Issuer`

| Field        | Type   | Description |
|--------------|--------|-------------|
| `<Algorithm>`| Map    | The key of this Map is a string identifier of the cryptographic algorithm (e.g. `RSA` or `ECDSA`). Each entry defines minimum and maximum allowable key sizes for that algorithm. |

> Note: Not all supported algorithms need to be listed. If the key's algorithm is absent, implementations should throw an error.

### `Algorithm Key Constraint Entry`

| Field       | Type   | Description |
|-------------|--------|-------------|
| `MinKeySize`| Int    | Minimum allowable key size in bits. |
| `MaxKeySize`| Int    | Maximum allowable key size in bits. |

---

### `BasicConstraints`

| Field              | Type    | Description |
|--------------------|---------|-------------|
| `CA`               | Boolean | Indicates whether the certificate is a Certificate Authority (e.g., `true` or `false`). |
| `PathLenConstraint`| Int     | *(Optional)* Specifies the maximum number of intermediate certificates that may follow this certificate in a valid certification path. Only applicable if `CA` is `true`. |

> Note: If `CA` is `false` and `PathLenConstraint` is configured, the implementation shall throw an error.
