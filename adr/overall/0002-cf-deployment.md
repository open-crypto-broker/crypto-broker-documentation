---
status: accepted
date: 2025-04-09
decision-makers: Stephan Andre, Maximilian Lenkeit, Anselme Tueno
consulted: Arturo Guridi, Pawel Chmielewski, Robin Winzler, Daniel Becker
informed: Erwin Margewitsch
---

# Options for Cloud Foundry (CF) deployment

## Context and Problem Statement

This ADR focuses on the deployment strategy of the Crypto Broker in CF. Deployment of an application and the Crypto Broker as a sidecar can be achieved in two different ways for CF. One option is to push the complete source folder to CF, compile it there and start executing it. Another option is to compile the source code locally and push the binaries to CF. There are pros and cons for both options, which are described in this ADR.

## Decision Drivers

* A reliable, robust, fast, secure and easy deployment method should be used

## Considered Options

* Deploy pre-compiled executable binaries to CF
* Deploy source code and let CF build and run the executables

## Decision Outcome

Chosen option: Deploy pre-compiled executable binaries to CF.

### Consequences

* Good, because deploying a pre-compiled binary can be signed and ensures that nobody is able to alter the source code of the Crypto Broker. Also, it is easier to deploy to other applications.
* Bad, because a local compilation is needed before deployment.

### Confirmation

* Confirmed by: Maximilian Lenkeit

## Pros and Cons of the Options

### Deploy pre-compiled executable binaries to CF

#### Description

This option intends to build the binaries from the source code, e.g. on a local machine, before deploying to CF.

#### Pros

* The CF instance does not have to build the executables from the source code on its own.
    * Less files need to be transferred.
    * Fast deployment.
* Go version not dependent on CF buildpack, no reproducibility risks as the Crypto Broker executable is compiled beforehand.
* Possible to sign the binary file.
* Easier to use for other applications.
* No modification of the source code possible.

#### Cons

* Less flexible, as the binaries have to be created before deployment (or stored in a repository) and then re-uploaded.
* Local compilation environment needed (Go compiler etc.).
* Can result in large files if compiled binaries are big.

### Deploy source code and let CF build and run the executables

#### Description

This option intends to deploy the source code (e.g. from the GitHub repository) to CF and let CF build the executables from the provided source code. Eventually, CF will run the built executables.

#### Pros

* No local compilation needed
    * Binaries do not have to be built or stored anywhere as only the source code is deployed to CF.
* Flexibility in deployment, no need to re-upload binaries on changes.
* Friendly for CI/CD pipelines that build on push.

#### Cons

* Before running the Crypto Broker, the CF instance needs to build the executables from the source code, leading to slower deployments.
* Risk of incompatible dependencies when building in CF
    * Qualification/testing of the artifact: resolving dependencies on CF does not give a 100% guarantee that the software was previously tested in exact that combination.
    * Can violate SAP product standards.
* More files need to be transferred.
* Signing of the compiled artifact not so easily possible.

## More Information
