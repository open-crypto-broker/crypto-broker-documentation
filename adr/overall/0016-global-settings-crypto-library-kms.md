---
status: proposed
date: 2026-09-18
decision-makers: Maximilian Lenkeit, Stephan Andre, Anselme Tueno
consulted: Robin Winzler, Miyana Stange, Pawel Chmielewski, Damian Jankowski
---

# Global Settings for Crypto Library and KMS

## Context and Problem Statement

The `Profiles.yaml` file originally defined the cryptographic library (`CryptoLibrary`) and the optional key storage backend (`KMS`) **per profile**, inside each profile's `Settings` block.
In practice these two values are infrastructure/deployment concerns rather than per-use-case cryptographic policy: which crypto library is available (e.g. `native` vs. `openssl`) and which KMS is reachable (e.g. `OpenBao`) are properties of the environment the Crypto Broker runs in, not of an individual algorithm profile.

Requiring every profile to repeat `CryptoLibrary` (and optionally `KMS`) leads to duplication and to configurations that are easy to get inconsistent (e.g. two profiles pointing at different libraries or key stores by accident).

This ADR decides whether `CryptoLibrary` and `KMS` should be **global settings** that apply to all profiles, or remain **per-profile** settings.
It also has to address the open question: what happens if an application legitimately needs a *different* KMS for *different* profiles?

## Decision Drivers

* Reduce duplication and configuration drift across profiles
* Keep infrastructure/deployment concerns (library, key store) separate from cryptographic policy (algorithms, key sizes)
* Keep the model simple to reason about and validate at startup
* Still have the option if per-profile key stores become a real requirement

## Considered Options

* **A — Global settings:** define `CryptoLibrary` and `KMS` once at the top of `Profiles.yaml`; all profiles inherit them.
* **B — Per-profile settings:** keep `CryptoLibrary` and `KMS` inside each profile's `Settings` block.
* **C — Global default with per-profile override:** define global values, but allow an individual profile to override them.

## Decision Outcome

Chosen option: **A — Global settings**, because the crypto library and key store are deployment-level properties shared by all profiles, and bundling them removes duplication and a class of misconfiguration.
A single deployment of the Crypto Broker is assumed to run against one crypto library and (at most) one KMS.

If a genuine need arises for different key stores per profile, we can migrate to **Option C** (global default + per-profile override) without breaking existing files: the global block stays the source of truth and an override is purely additive.
We deliberately defer that complexity until there is a concrete requirement (YAGNI).

### Consequences

* Good, because each `Profiles.yaml` declares the library and key store exactly once
* Good, because profiles focus purely on cryptographic policy, improving readability
* Good, because startup validation is simpler — one library/KMS to resolve instead of N
* Bad, because a single deployment can no longer use two different KMS backends for two different profiles (see [Different KMS per profile](#different-kms-per-profile))
* Bad, because it is a breaking change to the file format and requires updating the loader, all example/test profiles and dependent ADRs ([0011](0011-key-storage-backend.md), [0012](0012-encrypt-decrypt-api.md), [0015](0015-sign-verify-data-api.md))

### Confirmation

To be confirmed by the stakeholders.

## Different KMS per profile

The main concern with going global is: *what if an application wants profile `A` backed by KMS `X` and profile `B` backed by KMS `Y`?*

Assessment:

* With **Option A**, this is not expressible within one `Profiles.yaml`. The workaround is to run **two Crypto Broker deployments**, each with its own global `KMS`. Since a KMS is a heavy piece of infrastructure with its own auth boundary, running separate broker instances per key store is often the cleaner isolation anyway.
* If the requirement turns out to be common, **Option C** covers it: the global `KMS` acts as the default and a profile may set its own `KMS` to override it.
This keeps the common case (one KMS) simple while allowing the exception.
* The same reasoning applies to `CryptoLibrary`, but a per-profile library is far less likely to be needed, so it can stay strictly global.

## Pros and Cons of the Options

### A — Global settings

```yaml
Settings:
  CryptoLibrary: native
  KMS: openbao        # optional
Profiles:
  - Name: Default
    API: { ... }
```

* Good, because no duplication; one place to change the library or key store
* Good, because it matches the deployment reality (one environment, one library/KMS)
* Good, because it keeps profiles free of infrastructure concerns
* Bad, because it cannot express more than one KMS within a single deployment
* Neutral, because it is a breaking format change (one-time migration)

### B — Per-profile settings

```yaml
Profiles:
  - Name: Default
    Settings:
      CryptoLibrary: native
      KMS: openbao
    API: { ... }
```

* Good, because each profile can pick its own library and KMS
* Bad, because `CryptoLibrary`/`KMS` are repeated in every profile
* Bad, because profiles can silently disagree, creating confusing or invalid setups
* Bad, because it mixes deployment concerns into cryptographic policy

### C — Global default with per-profile override

```yaml
Settings:
  CryptoLibrary: native
  KMS: openbao          # default for all profiles
Profiles:
  - Name: Special
    Settings:
      KMS: openkcm       # overrides the default for this profile only
    API: { ... }
```

* Good, because it supports the multi-KMS case without duplicating the common value
* Good, because it is backward compatible with Option A (override is additive)
* Bad, because it reintroduces two places to look and more validation rules (precedence, conflicts)
* Bad, because it is more complex than the current requirements justify

## More Information

Supersedes the per-profile placement of `Settings` described earlier in the [Profile Specification](../../spec/0001-profile.md).
Related: [Key Storage Backend ADR](0011-key-storage-backend.md), [Key Resolution ADR](0014-kms.md), [EncryptData/DecryptData API ADR](0012-encrypt-decrypt-api.md), [SignData/VerifyData API ADR](0015-sign-verify-data-api.md).
