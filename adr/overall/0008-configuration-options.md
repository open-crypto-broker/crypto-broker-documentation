---
status: "proposed"
date: 2025-10-06
decision-makers: Stephan Andre, Maximilian Lenkeit, Anselme Tueno
consulted: Pawel Chmielewski, Miyana Stange, Robin Winzler
informed: Erwin Margewitsch
---

# Configuration Options for Crypto Broker Server

## Context and Problem Statement

The `crypto-broker-server` currently discovers profiles via an environment variable `CRYPTO_BROKER_PROFILES_DIR` that points to a directory which acts as safe root directory that contains `Profiles.yaml` (please see [os.Root](https://pkg.go.dev/os@go1.25.1#Root), [Travelsal-resistant file APIs](https://go.dev/blog/osroot)). At startup, the server validates that the provided path is absolute and readable and then reads a predefined profiles file (`Profiles.yaml`) from this directory.

We plan to improve configurability for different deployment environments (local development, Cloud Foundry sidecar, Kubernetes with ConfigMaps/Secrets) and offer a clear precedence model. We also want to assess options for immutable builds, dynamic reloading, and secure handling of configuration.

Problem question: What configuration sources and precedence should the server support to balance security, portability, and simplicity?

## Decision Drivers

* Security (handle secrets safely) and least-privilege access (possibly avoid overexposing filesystem)
* Operational ergonomics across K8s, Cloud Foundry, and VMs
* No requirement to preserve backward compatibility with `CRYPTO_BROKER_PROFILES_DIR`
* Clear, deterministic precedence of multiple configuration sources
* Observability of which source is used, with explicit error messages and validation
* Simplicity of implementation and low maintenance overhead

## Considered Options

* Keep current model: environment variable pointing to a directory (`CRYPTO_BROKER_PROFILES_DIR`) containing `Profiles.yaml`
* Environment variable pointing directly at a profile file (e.g., `CRYPTO_BROKER_PROFILES_FILE`)
* Environment variable carrying the full YAML content inline (e.g., `CRYPTO_BROKER_PROFILES_YAML`)
* Command-line flags (e.g., `--profiles-dir`, `--profiles-file`, `--profiles-yaml`)
* Config file with OS/XDG search order of conventional locations as a fallback
* Embedded defaults using `go:embed` for non-production convenience
* Kubernetes and Cloud Foundry alignment: ConfigMap/Secret mounts or env injection

### Additional aspects worth consideration

* Build-time injection via `-ldflags` into exported variables (immutable-by-build)
* Dynamic reload (e.g., SIGHUP)

## Threat Model

Currently, the Crypto Broker server reads the Profiles.yaml file at startup and parses every profile in this file.
An application can then use one of these profiles to execute the APIs with different cryptographic algorithms.
An attacker might want to change the algorithms for the API functions to algorithms which are known to be weak or already broken (e.g. MD5).
For this downgrade attack vector it is crucial that an attacker cannot easily change the configuration on-the-fly or without notification.
It is advisable to choose an option which allows to audit which persons made changes to the profiles.

## Decision Outcome

The current implementation is sufficient:
The Crypto Broker server gets the path to the folder where the `Profiles.yaml` is stored via the environment variable `CRYPTO_BROKER_PROFILES_DIR`.
At the moment there is no need to adjust the current behavior.
In future it can be the case that the profiles shall be downloaded from an external source.
Then this ADR will be updated.

## Pros and Cons of the Options

### Keep current: `CRYPTO_BROKER_PROFILES_DIR` only

#### Good, because

* Simple and already implemented, least code change.
* Security boundaries are clear (read-only directory, absolute path).

#### Neutral, because

* Works well with file mounts in containers.

#### Bad, because

* Inflexible in environments where direct file mounts are inconvenient.
* No inline/env or CLI options for quick testing.

### Env var pointing to a file: `CRYPTO_BROKER_PROFILES_FILE`

#### Good, because

* Directly supports K8s/CF mounts to a single file; easy to audit permissions.

#### Neutral, because

* Similar security model to directory but narrower scope.

#### Bad, because

* Still requires a file to exist; not ideal for pure-env deployments.

### Env var with inline YAML: `CRYPTO_BROKER_PROFILES_YAML`

#### Good, because

* No filesystem dependency; fits CF manifests and secrets-in-env patterns.

#### Neutral, because

* Convenient for small configs only.

#### Bad, because

* Risk of logs/inspection leaking configuration from environment.
* Harder to manage large multi-line YAML and rotation.

### Build-time injection via `-ldflags`

#### Good, because

* Immutable binaries with embedded defaults; reproducible behavior.

#### Bad, because

* Rebuild required for config changes; not flexible for ops.

### Command-line flags

#### Good, because

* Local dev and debugging ergonomics; explicit over implicit.

#### Neutral, because

* Common practice for Go services.

#### Bad, because

* Another surface to document and test.

### Config file + XDG/OS default search

#### Good, because

* Sensible defaults for bare-metal environments.

#### Neutral, because

* Rarely used in containerized production.

#### Bad, because

* Might surprise users if undocumented; must be low precedence.

### Embedded defaults (`go:embed`) behind opt-in

#### Good, because

* Zero-setup for demos and quickstarts.

#### Bad, because

* Risky if accidentally enabled in prod; must require explicit flag or similar mechanism.

Please see [embed](https://pkg.go.dev/embed) for more info.

### Dynamic reload (SIGHUP/inotify)

SIGHUP is one of the POSIX signals (short for Signal Hang Up) sent to a process when its controlling terminal is closed or disconnected.
Today, it’s commonly used to tell daemons or background services to reload their configuration files without restarting.

#### Good, because

* Enables seamless rotation without restarts.

#### Neutral, because

* Only for advanced operators.

#### Bad, because

* Complexity and potential for partial failure; requires rollback logic and strong validation.
