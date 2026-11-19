---
status: proposed
date: 2026-11-16
decision-makers: Maximilian Lenkeit, Stephan Andre, Anselme Tueno
consulted: Robin Winzler, Miyana Stange, Pawel Chmielewski, Damian Jankowski
---

# Per-API Key Policy in Profiles

## Context and Problem Statement

[ADR 0016](0016-global-settings-crypto-library-kms.md) moves the `KMS` definition into the global `Settings` of `Profiles.yaml`.
Combined with the rule from [ADR 0011](0011-key-storage-backend.md) and [ADR 0012](0012-encrypt-decrypt-api.md) — *"no KMS → `raw_key` is required, KMS defined → `key_id` is expected"* — the presence of a single global setting switches **every API of every profile** into either caller-managed or broker-managed mode.
This leads to two problems:

1. **All or nothing.** A KMS is often only partially provisioned for a deployment: it may hold the AES key used by `EncryptData`, but not the CA key used by `SignCertificate`, or vice versa.
   With a global mode, defining a KMS forces all profiles and all APIs to use it, so such setups cannot be expressed.
   In addition, an application cannot fall back to supplying a raw key if the KMS is temporarily unavailable.
2. **No binding between key IDs and profiles.** The application selects a key by sending a `key_id`, and the broker resolves whatever identifier it receives.
   Nothing ensures that the key belongs to the requested profile and API.
   If `Payments` and `Reporting` both use KMS-backed `EncryptData`, a request for `Payments` can name the key intended for `Reporting` — by mistake, or by guessing the name — and the broker will use it.
   [ADR 0014](0014-kms.md) states this explicitly as a consequence: *"the broker does not map key IDs per application"*.

The question is how the profile can describe, per use case, **where** keys may come from and **which** keys may be used, while staying simple to read and validate.

## Decision Drivers

* Partial KMS provisioning must be expressible (some APIs KMS-backed, others caller-managed)
* Raw keys should remain usable, e.g. as a fallback when the KMS is unavailable, unless a profile explicitly forbids them
* A `key_id` must only be usable with the profile and API it was provisioned for (deny by default)
* `Profiles.yaml` should be an auditable inventory of the keys each use case can touch
* Key rotation must be possible without breaking decryption or verification of existing data
* The global KMS of [ADR 0016](0016-global-settings-crypto-library-kms.md) remains the single place for infrastructure configuration
* No change of the gRPC API (`KeySource` already carries `key_id` or `raw_key`)

## Considered Options

* **A — Global mode (status quo):** the presence of `Settings.KMS` decides the `KeySource` variant for all profiles.
* **B — Per-profile KMS:** each profile references its own KMS or none (Option C of [ADR 0016](0016-global-settings-crypto-library-kms.md)).
* **C — Per-API key policy with an explicit key-ID allow-list** *(recommended)*: the global KMS only defines the connection; each API section of a profile declares which key IDs it may use.
* **D — Per-API key namespace:** like C, but instead of a list the profile declares a key path prefix that the broker prepends to the supplied `key_id`.

## Decision Outcome

No option has been chosen yet; the decision is open for discussion by the decision-makers.

**Option C is recommended**, because it is the only option that meets all decision drivers: it solves partial provisioning and key binding with one small, explicit construct, keeps the global KMS from ADR 0016 unchanged, and makes every usable key visible in `Profiles.yaml`.
Option D is a possible later extension of C if maintaining exact key ID lists turns out to be impractical.

| Decision driver | A — Global mode | B — Per-profile KMS | C — Per-API allow-list | D — Per-API namespace |
| --- | --- | --- | --- | --- |
| Partial KMS provisioning | No | Per profile only | Yes, per API | Yes, per API |
| Raw key fallback | No (if a KMS is defined) | Only for profiles without KMS | Yes, configurable per API | Yes, configurable per API |
| `key_id` bound to profile and API | No | No | Yes, exact IDs | Yes, by prefix |
| Auditable key inventory | No | No | Yes | Partly (prefixes only) |
| Rotation without breaking decryption/verification | Not controlled | Not controlled | Yes, `DecryptOnlyKeyIds` / `VerifyOnlyKeyIds` | Not controlled |
| Single global KMS (ADR 0016) | Yes | No | Yes | Yes |
| No gRPC API change | Yes | Yes | Yes | Yes |

### Consequences

The consequences of each option are listed in [Pros and Cons of the Options](#pros-and-cons-of-the-options) and will be moved here once an option is chosen.

### Confirmation

To be confirmed by the stakeholders.
If Option C is chosen, the implementation is confirmed by server tests covering accepted and rejected key IDs, `DecryptOnlyKeyIds` / `VerifyOnlyKeyIds`, `AllowRawKey`, and the startup validation rules.

## Pros and Cons of the Options

### A — Global mode (status quo)

The presence of `Settings.KMS` decides for all profiles and APIs which `KeySource` variant is accepted.

```yaml
Settings:
  CryptoLibrary: native
  KMS:                  # defined → every API of every profile expects key_id
    Client: openbao
    Config: openbao.yaml
Profiles:
  - Name: Payments
    API:
      EncryptData:
        EncryptAlg: aes-gcm
        KeySize: 256
```

* Good, because it is the simplest model
* Bad, because a KMS cannot be used for only some APIs or profiles
* Bad, because there is no raw-key fallback once a KMS is defined
* Bad, because any `key_id` in the KMS can be used with any profile

### B — Per-profile KMS

Each profile may reference its own KMS or none; profiles without a KMS are caller-managed.

```yaml
Settings:
  CryptoLibrary: native
Profiles:
  - Name: Payments
    Settings:
      KMS:              # this profile expects key_id for all of its APIs
        Client: openbao
        Config: openbao.yaml
    API: { ... }
  - Name: Reporting     # no KMS → raw_key only
    API: { ... }
```

* Good, because profiles can opt in or out of the KMS individually
* Bad, because it reintroduces infrastructure configuration into profiles, which [ADR 0016](0016-global-settings-crypto-library-kms.md) deliberately removed
* Bad, because a profile still cannot use the KMS for one API but not another
* Bad, because it does not bind key IDs to profiles

### C — Per-API key policy with an explicit key-ID allow-list

#### Separation of concerns

| Concern | Location | Meaning |
| --- | --- | --- |
| KMS connection (infrastructure) | Global `Settings.KMS` | *A KMS is reachable using this client and configuration.* It no longer determines the `KeySource` variant. |
| Key policy (cryptographic policy) | `KeySource` block in each key-consuming API section of a profile | *This API accepts these key IDs from the KMS and/or raw keys from the caller.* |

#### Profile format

Every API section that consumes key material (`EncryptData`, `SignData`, `SignCertificate`) may contain an optional `KeySource` block.
The name mirrors the `KeySource` message of the gRPC API it governs.

```yaml
Settings:
  CryptoLibrary: native
  KMS:                                      # optional; connection only
    Client: openbao
    Config: openbao.yaml
    Cache: false
Profiles:
  - Name: Payments
    API:
      EncryptData:                          # also governs DecryptData
        EncryptAlg: aes-gcm
        KeySize: 256
        KeySource:
          KeyIds: [payments-aes-2026]       # usable for EncryptData and DecryptData
          DecryptOnlyKeyIds: [payments-aes-2025]   # rotated out: DecryptData only
          AllowRawKey: false                # strict: no application-provided raw key allowed
      SignCertificate:
        # ...
        KeySource:
          KeyIds: [payments-issuing-ca]     # AllowRawKey defaults to true
  - Name: Reporting
    API:
      EncryptData:
        EncryptAlg: aes-gcm
        KeySize: 256
        # no KeySource block: caller-managed, raw keys only
```

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `KeyIds` | List of Strings | empty | Key IDs that may be resolved through the global KMS for all operations governed by the API section. |
| `DecryptOnlyKeyIds` | List of Strings | empty | `EncryptData` section only. Key IDs accepted by `DecryptData` but rejected by `EncryptData`. Used for key rotation. |
| `VerifyOnlyKeyIds` | List of Strings | empty | `SignData` section only. Key IDs accepted by `VerifyData` but rejected by `SignData`. Used for key rotation. |
| `AllowRawKey` | Boolean | `true` | Whether the caller may supply key material inline via `raw_key`. |

#### Request-time behaviour

| Request `KeySource` | Accepted if |
| --- | --- |
| `key_id` | The ID is listed in `KeyIds` of the API section, or — for `DecryptData` / `VerifyData` only — in `DecryptOnlyKeyIds` / `VerifyOnlyKeyIds`. |
| `raw_key` | `AllowRawKey` is `true` (the default). |

* Without a `KeySource` block, the API accepts raw keys only; every `key_id` is rejected.
* The allow-list check happens **before** any KMS call or cache lookup, so a rejected ID never reaches the KMS.
* In `hybrid` signing mode, each component `key_id` must be allowed individually.
* For `SignCertificate`, the allowed `key_id` references the CA private key; the matching CA certificate is retrieved from the KMS under the same ID, as described in the [Library Specification](../../spec/0002-library.md).
* A key ID that is not allowed and a disallowed `raw_key` are rejected with gRPC `PermissionDenied`.
  The error names the profile and API, but neither the allow-list nor whether the key exists in the KMS.
* The broker never falls back from `key_id` to `raw_key` on its own. If the KMS is unavailable, the request fails; the application may retry with a `raw_key` if the profile allows it.

#### Startup validation

The server refuses to start if:

* a `KeySource.KeyIds`, `DecryptOnlyKeyIds` or `VerifyOnlyKeyIds` list is non-empty but no global `Settings.KMS` is defined, or the global `KMS` lacks `Client` or `Config`;
* a key ID does not match `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$` (at most 64 characters, matching the existing `key_id` payload limit; no `/`, so a key ID cannot address other paths in the KMS);
* a key ID appears more than once within one `KeySource` block, e.g. in both `KeyIds` and `DecryptOnlyKeyIds`;
* the same key ID is used by sections of **different** APIs (e.g. `EncryptData` and `SignCertificate`), which would violate the one-key-one-purpose principle ([NIST SP 800-57 Part 1, Section 5.2](https://csrc.nist.gov/pubs/sp/800/57/pt1/r5/final));
* `AllowRawKey` is `false` and all key ID lists are empty, which would make the API unusable;
* `DecryptOnlyKeyIds` or `VerifyOnlyKeyIds` is used in a section other than `EncryptData` or `SignData`.

Using the same key ID for the same API in several profiles is allowed.
This is intended for the rolling migration of [ADR 0013](0013-profile-change-migration-guidance.md), where a deprecated profile and its successor need to access the same key.

A global `KMS` that no profile references is valid; the server may log a warning.

#### Key rotation

`DecryptOnlyKeyIds` (and `VerifyOnlyKeyIds`) make rotation explicit:

1. Provision the new key in the KMS, e.g. `payments-aes-2027`.
2. Add it to `KeyIds` next to the current key and roll out the profile.
3. Switch the application to the new key ID for `EncryptData`.
4. Move the old key ID from `KeyIds` to `DecryptOnlyKeyIds`. From now on, the old key can no longer encrypt.
5. Once all data has been re-encrypted or has expired, remove the old key ID from the profile.

#### Security considerations

The Crypto Broker runs as a sidecar of a single application and the request selects the profile by name; the broker does not authenticate which part of an application sends a request.
The allow-list is therefore **not an isolation boundary between applications** — an application can always choose another profile.
This applies to all considered options.
What the allow-list provides is:

* binding of each key to the cryptographic policy of its profile and API (algorithm, key size, certificate constraints), so it cannot be used under a different policy by accident;
* deny-by-default behaviour for guessed or mistyped key IDs;
* an auditable inventory of key usage in `Profiles.yaml`, subject to the same change-management controls as the rest of the file.

Isolation between applications remains the responsibility of the deployment: one broker per application and KMS credentials that are scoped to the keys of that application (e.g. an OpenBao policy per deployment).
Both layers are intended to be used together.

`AllowRawKey` defaults to `true` so that applications can fall back to caller-managed keys.
Profiles whose keys must never be handled by the application should set `AllowRawKey: false`.

#### Pros and cons

* Good, because a single KMS can be used by some APIs while others stay caller-managed, so partial provisioning is supported
* Good, because applications can fall back to raw keys unless the profile forbids it
* Good, because a `key_id` is only resolved for the profile and API it is listed for
* Good, because `Profiles.yaml` lists every key ID the broker may resolve, which simplifies audits
* Good, because exact matching is easy to validate and has no ambiguous patterns
* Good, because key rotation is explicit and old keys can be restricted to decryption or verification
* Good, because the gRPC API and the client libraries do not change
* Good, because a per-profile KMS (Option B) or a key namespace (Option D) can still be added later as optional fields of the `KeySource` block
* Neutral, because existing profiles keep working for raw keys; profiles that use `key_id` need a `KeySource` block
* Bad, because adding or rotating a key requires a profile change and a restart of the server
* Bad, because it is not an isolation boundary between applications and must not be presented as one
* Bad, because with the default `AllowRawKey: true`, a KMS-backed API also accepts raw keys unless the operator restricts it

### D — Per-API key namespace

Like Option C, but instead of a list of key IDs, the API section declares a key path prefix that the broker prepends to the supplied `key_id`.

```yaml
EncryptData:
  KeySource:
    KeyPath: payments/aes/    # app sends "2026", broker resolves "payments/aes/2026"
```

* Good, because keys can be added or rotated without a profile change
* Good, because applications cannot address keys outside their namespace
* Bad, because the profile no longer shows which keys are actually used
* Bad, because every key in the namespace can be used for all operations, so a rotated-out key cannot be restricted to decryption or verification
* Bad, because the security depends on the key layout in the KMS and on correct path handling in every KMS client
* Neutral, because it can be added later as an extension of the `KeySource` block if exact lists turn out to be impractical

## More Information

If Option C is chosen:

* It refines [ADR 0011](0011-key-storage-backend.md), [ADR 0012](0012-encrypt-decrypt-api.md) and [ADR 0015](0015-sign-verify-data-api.md): the `KeySource` variant is no longer determined by the presence of a global KMS, but by the `KeySource` block of the API section.
* It refines [ADR 0014](0014-kms.md): `rawKey` remains usable when a KMS is configured (now controlled by `AllowRawKey`), and key IDs are mapped per profile and API.
* It builds on [ADR 0016](0016-global-settings-crypto-library-kms.md): the global `Settings.KMS` only defines the connection to the KMS.
* The profile format is specified in the [Profile Specification](../../spec/0001-profile.md#keysource); the request handling in the [Library Specification](../../spec/0002-library.md#keysource-message) and the [Server Specification](../../spec/0003-server.md#profile-level-validation).
