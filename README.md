# Documentation of the Crypto Broker Client and Crypto Broker Server

This repository documents the Crypto Broker architecture, specifications and design decisions.
This project is part of the ApeiroRA project which provides cloud-based functionality for crypto agility, making cryptographic operations easy to use.
The Crypto Broker offloads cryptographic operations from applications by acting as a sidecar service.
Applications interact only with the Crypto Broker Client API.
The client transparently communicates with the Crypto Broker Server, which executes the cryptographic operations.
The code for the clients in various languages and the server itself is hosted in their respective repositories.

## Crypto Broker Clients

The Crypto Broker Client part is provided as an API-library for different programming languages.
The goal is to easily communicate and integrate the Crypto Broker Server as a sidecar.
Its purpose is to offer a simple and consistent API to applications and handle the communication with the Crypto Broker Server.

Currently available client implementations are:

- [Golang Client](https://github.com/open-crypto-broker/crypto-broker-client-go)
- [Node.js Client](https://github.com/open-crypto-broker/crypto-broker-client-js)

## Crypto Broker Server

The [Crypto Broker Server](https://github.com/open-crypto-broker/crypto-broker-server) creates a Unix Domain Socket and listens for incoming requests from the Crypto Broker Client.
When a request is received, the server processes it, verifies its validity and executes the cryptographic operation.
Eventually, the result of the cryptographic operation is sent back to the client as a response.
If an error occurs, the server notifies the client about the failed operation.

For the communication between the Crypto Broker Server and the Crypto Broker Client, [gRPC](https://grpc.io/) is used.
It is based on HTTP/2 and [Protobuf](https://protobuf.dev/).
The definition of the Protobuf structures is hosted in its [own repository](https://github.com/open-crypto-broker/crypto-broker-proto) and included as a Git Submodule in the Crypto Broker Server and Crypto Broker Client repositories.

## Architecture Documentation

The architectural design is documented in the `architecture/` directory following the [C4 model](https://c4model.com/).

- The C4 diagrams show how applications, clients and the server interact.
- The sequence diagram illustrates the lifecycle of a request and response.
- The server activity flowchart describes the internal server workflow.

## Architectural Decision Records (ADR)

The architectural decisions are recorded in the `adr/` directory.
In addition, the template for future ADRs is also located there.

## Specifications

Specifications for different parts of the Crypto Broker Server and Crypto Broker Client are recorded in the `spec/` directory.
These specifications are suitable entry points for developers, which want to integrate the Crypto Broker in their application.

## Deployment

The [deployment repository](https://github.com/open-crypto-broker/crypto-broker-deployment) describes and shows how the Crypto Broker Server and the different Crypto Broker Clients can be deployed to the specified targets.

## Support, Feedback, Contributing

This project is open to feature requests/suggestions, bug reports etc. via [GitHub issues](https://github.com/open-crypto-broker/crypto-broker-documentation/issues). Contribution and feedback are encouraged and always welcome. For more information about how to contribute, the project structure, as well as additional contribution information, see our [Contribution Guidelines](CONTRIBUTING.md).

## Security / Disclosure

If you find any bug that may be a security problem, please follow our instructions at [in our security policy](https://github.com/open-crypto-broker/crypto-broker-documentation/security/policy) on how to report it. Please do not create GitHub issues for security-related doubts or problems.

## Code of Conduct

We as members, contributors, and leaders pledge to make participation in our community a harassment-free experience for everyone. By participating in this project, you agree to abide by its [Code of Conduct](https://github.com/open-crypto-broker/.github/blob/main/CODE_OF_CONDUCT.md) at all times.

## Licensing

Copyright 2025 SAP SE or an SAP affiliate company and Open Crypto Broker contributors. Please see our [LICENSE](LICENSE) for copyright and license information. Detailed information including third-party components and their licensing/copyright information is available [via the REUSE tool](https://api.reuse.software/info/github.com/open-crypto-broker/crypto-broker-documentation).
