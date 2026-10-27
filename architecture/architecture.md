# Crypto Broker - Architecture Description

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Repositories Overview](#repositories-overview)
4. [Communication Architecture](#communication-architecture)
5. [Performance Evaluation](#performance-evaluation)
6. [FIPS 140-3 Mode](#fips-140-3-mode)
7. [Deployment Architecture](#deployment-architecture)
8. [Resilience and Fault Tolerance](#resilience-and-fault-tolerance)

---

## Overview

The Crypto Broker is a cryptographic service that provides crypto agility by offloading cryptographic operations from applications.
It can be deployed in any environment—cloud, on-premises, or local—as long as the core deployment requirements are met:
the server and client must run on the same host but in separate processes, communicating via Unix domain sockets.
It follows a sidecar pattern where applications delegate cryptographic operations to a dedicated server component,
enabling centralized crypto policy management, easy algorithm updates, and compliance with regulatory requirements such as FIPS 140-3.

### Key Features

- **Crypto Agility**: Switch cryptographic algorithms without code changes, responding quickly to security vulnerabilities and compliance requirements
- **Centralized Cryptographic Operations**: Profile-based configuration for consistent crypto policy management across applications
- **Multi-Language Support**: Client libraries available in Go and JavaScript/Node.js (with more languages planned)
- **FIPS 140-3 Compliance**: Built-in support for FIPS 140-3 validated cryptographic modules
- **Cloud-Native**: Containerized architecture deployable via Kubernetes or Cloud Foundry
- **High Performance**: Optimized communication via gRPC over Unix domain sockets
- **Observability**: OpenTelemetry tracing support for distributed observability

---

## System Architecture

The Crypto Broker follows the [C4 model](https://c4model.com/) for architectural documentation. The system consists of multiple repositories, each serving a specific purpose:

### C1-System Context

The System Context diagram shows the highest-level view of the [Crypto Agility](https://apeirora.eu/content/impact/security-kms/) project. Users interact with the system to perform cryptographic operations. This abstraction hides the internal complexity of how cryptographic services are delivered, focusing on the external boundary of the system.

![System Context Diagram](c4/c1-system.md)

### C2-Container View

The Container diagram reveals the internal structure of the CryptoAgility system. It shows two primary containers: the Application (which integrates the client library) and the Crypto Broker server. This illustrates the sidecar pattern where both containers run on the same host, with the application using the Crypto Broker to handle all cryptographic operations. Users interact directly with the application, which transparently delegates crypto tasks to the server.

![Container Diagram](c4/c2-container.md)

### Sequence Diagram

The Request Flow sequence diagram illustrates both the deployment model and the complete lifecycle of a cryptographic operation request. The diagram shows two separate containers/processes (Client-Container and Server-Container) representing the sidecar deployment pattern.

**Communication within containers** (inside the colored boxes) occurs through direct function calls:

- Application → Crypto Broker client: In-process API call
- Crypto Broker server → Crypto Provider: In-process crypto function invocation

**Communication between containers** (crossing box boundaries) uses Inter-Process Communication (IPC) via gRPC over Unix domain sockets:

- Crypto Broker client → Crypto Broker server: gRPC request serialization and Unix socket transmission
- Crypto Broker server → Crypto Broker client: gRPC response serialization and Unix socket transmission

This architecture clearly separates the application/client container from the cryptographic server container, enabling independent deployment, restart, and scaling while maintaining high-performance local communication.

![Sequence Diagram](sequence.md)

---

## Repositories Overview

### 1. Crypto Broker Server

**Repository**: `crypto-broker-server`

The Crypto Broker Server is the core component that:

- Creates a Unix Domain Socket at `/tmp/open-crypto-broker/crypto-broker-server.sock` and listens for incoming requests
- Processes and validates cryptographic operation requests from clients
- Executes cryptographic operations using Go's crypto libraries
- Returns results or error notifications to clients
- Supports multiple cryptographic profiles for different compliance requirements

**Key Capabilities**:

- **Hash Operations**: SHA-2, SHA-3 family algorithms
- **Certificate Signing**: Generate X.509 certificates from CSRs
- **Health Checks**: gRPC health check protocol support
- **Benchmarking**: Built-in performance testing capabilities
- **OpenTelemetry**: Distributed tracing for observability

**Configuration**:

- Profile-based cryptographic policy configuration (YAML)
- Environment variable configuration for logging, paths, and telemetry
- FIPS 140-3 mode enabled at build-time

### 2. Crypto Broker Client

**Repositories**: `crypto-broker-client-go`, `crypto-broker-client-js`

The Crypto Broker Clients are librariies that provide a simple, consistent API across programming languages. They:

- Abstract the complexity of gRPC communication
- Establish and manage Unix socket connections
- Provide idiomatic APIs for each language
- Handle request serialization and response deserialization
- Support retry policies and error handling

**Available Implementations**:

- **Go Client**: Native Go library for Go applications
- **JavaScript/Node.js Client**: TypeScript-based library for Node.js applications

**API Operations**:

- `HealthCheck()`: Server health status
- `HashData()`: Compute cryptographic hashes
- `SignCertificate()`: Generate signed X.509 certificates
- `BenchmarkData()`: Run performance benchmarks

### 3. Crypto Broker CLI

**Repositories**: `crypto-broker-cli-go`, `crypto-broker-cli-js`

Command-line interface applications that:

- Demonstrate client library integration
- Serve as testing and validation tools
- Provide examples for application developers
- Used in end-to-end testing pipelines

**Use Cases**:

- Development and testing
- Known-Answer-Tests (KAT) validation
- Performance benchmarking
- Integration examples

### 4. Crypto Broker Deployment

**Repository**: `crypto-broker-deployment`

Provides deployment configurations and end-to-end tests for:

- **Cloud Foundry**: Manifest files and sidecar configuration
- **Kubernetes**: Helm charts for K8s deployment
- **Docker**: Docker Compose configurations for local testing
- **E2E Testing**: Comprehensive test suite validating all components

**Testing Capabilities**:

- Health check tests
- Hashing and signing operation tests
- Benchmark tests
- Client compatibility matrix generation
- Cross-platform builds (multiple OS/architecture combinations)

### 5. Crypto Broker Documentation

**Repository**: `crypto-broker-documentation`

Contains comprehensive documentation including:

- **Architecture Diagrams**: C4 model diagrams, sequence diagrams, activity diagrams
- **Specifications**: Client API, server behavior, profile structure
- **ADRs (Architectural Decision Records)**: Design decisions and rationale
- **API Documentation**: Complete API reference

### 6. Crypto Broker Proto

**Repository**: `crypto-broker-proto`

Defines the Protocol Buffer schemas for:

- Request and response message structures
- gRPC service definitions
- Shared types and enumerations

Included as a Git submodule in both server and client repositories to ensure consistency.

---

## Communication Architecture

The Crypto Broker uses **gRPC over Unix domain sockets** for client-server communication. This design (detailed in ADR-0004) balances performance, security, and maintainability.

### Why gRPC?

gRPC was selected over HTTP/JSON based on comprehensive benchmarking (1000 samples per configuration) across hash and certificate signing operations:

- **Binary Efficiency**: Protobuf reduces payload size by 30-40% compared to JSON, critical for certificate operations containing binary data (CSRs, keys, certificates)
- **Concurrency**: HTTP/2 multiplexing significantly improves performance under concurrent load
- **Type Safety**: Strong typing and schema validation prevent integration errors
- **Multi-Language Support**: Code generation for Go, JavaScript/Node.js, and future client libraries
- **Streaming**: Built-in bidirectional streaming for future use cases
- **Lower IPC Overhead**: Consistently faster net transmission time compared to HTTP

Benchmarking showed that for certificate signing operations, gRPC provides measurable latency improvements, while for smaller payloads (hash operations) the difference is marginal but still favorable.

### Unix Domain Sockets

Communication occurs over Unix sockets at `/tmp/open-crypto-broker/crypto-broker-server.sock`, providing:

- **Performance**: No network stack overhead
- **Security**: File system permissions control access; prevents remote attacks
- **Simplicity**: No port management or network configuration required

Server and client run in separate containers/processes on the same host with a shared volume mount for the socket file

---

## Performance Evaluation

### Benchmarking API

The Crypto Broker provides a dedicated benchmarking API (`BenchmarkData`) that allows:

- Server-side performance measurement of all cryptographic operations
- Automatic iteration count determination for statistical validity
- Comprehensive results across multiple algorithms (hash, signing)
- Detailed performance metrics (average time per operation)

This API enables comprehensive performance evaluation through controlled testing using Go's benchmark framework.

---

### Benchmarking Methodology

The Crypto Broker performance evaluation consists of two complementary benchmark suites:

1. **Client-Side (End-to-End) Benchmarks**:
   - Measures complete request lifecycle from application to result
   - Includes client library overhead, IPC communication, server processing, and cryptographic operations
   - Uses Go benchmark framework with variable iteration counts for statistical significance
   - Tests both sequential and parallel execution modes
   - Source: `crypto-broker-client-go` benchmark suite

2. **Server-Side (Pure Crypto) Benchmarks**:
   - Measures cryptographic operation performance in isolation (no IPC overhead)
   - Direct invocation of crypto functions within server process
   - Uses Go benchmark framework with high iteration counts
   - Source: `crypto-broker-server/internal/bench` test suite

By comparing these two benchmark types, we can derive communication overhead and quantify the benefit of parallel execution vs sequential mode

**Test Configuration**:

- **Platform**: Linux (amd64)
- **CPU**: AMD EPYC 7763 64-Core Processor
- **Profile**: Default (client-side benchmarks)
- **Parallelism**: GOMAXPROCS=4 (4 concurrent goroutines for parallel benchmarks)
- **Methodology**: Go benchmark framework with automatic iteration count determination

---

### Client-Side Benchmark Results (End-to-End Performance)

The client-side benchmarks measure complete end-to-end performance from application code through the entire request lifecycle. These benchmarks use the Go client library to invoke individual cryptographic operations (HashData, SignCertificate, HealthData), measuring the full roundtrip including client library overhead, protobuf serialization, Unix socket IPC, server processing, cryptographic execution, and response deserialization.

**How it works**:

- Application code calls client library methods (e.g., `lib.HashData()`, `lib.SignCertificate()`)
- Each call triggers a complete gRPC request/response cycle over Unix domain sockets
- Benchmarks run in two modes: sequential (one operation at a time) and parallel (10 concurrent goroutines)
- Go's benchmark framework automatically determines optimal iteration counts for statistical validity
- Results include both latency (time per operation) and throughput (operations per second)

#### Hash Operations

| Operation | Mode        | Latency (ns/op) | Latency (μs) | Throughput          | Memory     | Allocations   |
|-----------|-------------|-----------------|--------------|---------------------|------------|---------------|
| HashData  | Sequential  | 265,408         | 265 μs       | 3,770 ops/sec       | 8,783 B/op | 117 allocs/op |
| HashData  | Parallel    | 107,112         | 107 μs       | 9,340 ops/sec       | 8,841 B/op | 118 allocs/op |

**Observations**:

- Sequential hash operations complete in 265 microseconds end-to-end
- Parallel execution reduces latency by 60% (107 μs) due to concurrent request handling with 4 goroutines
- Memory footprint is lightweight (9 KB per operation)
- High throughput capability (3.8K-9.3K ops/sec depending on parallelism)

#### Health Check Operations

| Operation  | Mode        | Latency (ns/op) | Latency (μs) | Throughput          | Memory     | Allocations   |
|------------|-------------|-----------------|--------------|---------------------|------------|---------------|
| HealthData | Sequential  | 194,015         | 194 μs       | 5,155 ops/sec       | 5,473 B/op | 97 allocs/op  |
| HealthData | Parallel    | 71,045          | 71 μs        | 14,080 ops/sec      | 5,499 B/op | 97 allocs/op  |

**Observations**:

- Health checks are faster than hash operations (simpler processing, smaller payload)
- Extremely low latency enables frequent health monitoring without performance impact
- Parallel health checks achieve 14K ops/sec throughput with GOMAXPROCS=4

#### Certificate Signing Operations

Note: Configuration format is **CSR key / CA key** (e.g. "CSR P-256 / CA P-384" means the CSR uses a P-256 public key and is signed by a CA with a P-384 key).

| Operation                                    | Mode        | Latency (ns/op) | Latency (μs/ms)       | Throughput       | Memory      | Allocations   |
|----------------------------------------------|-------------|-----------------|-----------------------|------------------|-------------|---------------|
| SignCertificate (CSR P-256 / CA P-384)       | Sequential  | 1,733,483       | 1,733 μs (1.73 ms)    | 577 ops/sec      | 20,207 B/op | 129 allocs/op |
| SignCertificate (CSR P-256 / CA P-384)       | Parallel    | 868,809         | 869 μs (0.87 ms)      | 1,151 ops/sec    | 20,516 B/op | 130 allocs/op |
| SignCertificate (CSR P-256 / CA RSA-4096)    | Sequential  | 5,000,867       | 5,001 μs (5.00 ms)    | 200 ops/sec      | 23,120 B/op | 131 allocs/op |
| SignCertificate (CSR P-256 / CA RSA-4096)    | Parallel    | 2,039,654       | 2,040 μs (2.04 ms)    | 490 ops/sec      | 23,653 B/op | 134 allocs/op |
| SignCertificate (CSR P-521 / CA P-521)       | Sequential  | 7,694,561       | 7,695 μs (7.69 ms)    | 130 ops/sec      | 23,752 B/op | 130 allocs/op |
| SignCertificate (CSR P-521 / CA P-521)       | Parallel    | 3,251,685       | 3,252 μs (3.25 ms)    | 308 ops/sec      | 25,064 B/op | 136 allocs/op |

**Observations**:

- Three signing algorithm combinations benchmarked: CSR P-256 / CA P-384, CSR P-256 / CA RSA-4096, and CSR P-521 / CA P-521
- CSR P-256 / CA P-384 is the lightest signing operation (1.73 ms seq); CSR P-521 / CA P-521 is the heaviest (7.69 ms seq)
- Parallel execution reduces latency by 50-59% across all combinations with GOMAXPROCS=4
- Signing is significantly more computationally intensive than hashing (6-29x slower sequentially)
- Memory usage approximately 2-3x that of hash operations due to certificate data structures
- RSA-4096 CA signing (5 ms) is substantially slower than ECDSA CA alternatives due to RSA key size

---

### Server-Side Benchmark Results (Pure Crypto Performance)

The server-side benchmarks measure pure cryptographic operation performance in isolation, eliminating all IPC and networking overhead. These benchmarks directly invoke the cryptographic library functions within the server process using Go's standard testing framework, providing baseline performance metrics for the underlying crypto operations.

**How it works**:

- Benchmarks run directly within the server's test suite (no client library or IPC involved)
- Direct function calls to cryptographic operations (e.g., `service.HashSHA3_256()`, `service.SignCertificate()`)
- Uses Go's `testing.B` benchmark framework with high iteration counts (typically 10,000-1,000,000+ iterations)
- Measures pure algorithmic performance without serialization, socket I/O, or gRPC overhead
- Provides baseline for comparing against end-to-end client-side benchmarks to quantify IPC overhead
- Run via: `task run-benchmarks` or `go test -bench=.`

#### Hash Operations (Pure Crypto)

| Algorithm   | Latency (ns/op) | Latency (μs) | Throughput             |
|-------------|-----------------|--------------|------------------------|
| SHA-256     | 703.1           | 0.70 μs      | 1,422,000 ops/sec      |
| SHA-384     | 1,304           | 1.30 μs      | 767,000 ops/sec        |
| SHA-512     | 1,405           | 1.41 μs      | 712,000 ops/sec        |
| SHA-512/256 | 1,198           | 1.20 μs      | 835,000 ops/sec        |
| SHA3-256    | 1,931           | 1.93 μs      | 518,000 ops/sec        |
| SHA3-384    | 2,386           | 2.39 μs      | 419,000 ops/sec        |
| SHA3-512    | 3,204           | 3.20 μs      | 312,000 ops/sec        |
| SHAKE-128   | 1,507           | 1.51 μs      | 663,000 ops/sec        |
| SHAKE-256   | 1,907           | 1.91 μs      | 524,000 ops/sec        |

**Observations**:

- SHA-256 is the fastest algorithm at 0.70 μs per hash
- SHA-2 family (SHA-256, SHA-384, SHA-512) consistently faster than SHA-3 equivalents on this platform
- SHA-512 is slower than SHA-256 but provides longer output
- SHAKE XOF functions offer good performance for variable-length outputs

#### Certificate Signing Operations (Pure Crypto)

| Configuration (CSR key / CA key) | Latency (ns/op) | Latency (μs/ms)      | Throughput         |
|----------------------------------|-----------------|----------------------|--------------------|
| CSR P-256 / CA P-384             | 1,061,297       | 1,061 μs (1.06 ms)   | 942 ops/sec        |
| CSR P-256 / CA RSA-4096          | 4,445,214       | 4,445 μs (4.45 ms)   | 225 ops/sec        |
| CSR P-521 / CA P-521             | 7,757,207       | 7,757 μs (7.76 ms)   | 129 ops/sec        |

**Observations**:

- CSR P-256 / CA P-384 (lightest combination) completes in 1.06 ms pure crypto
- CSR P-256 / CA RSA-4096 is 4.2x slower (4.45 ms) due to RSA key size
- CSR P-521 / CA P-521 is the most expensive at 7.76 ms (7.3x slower than CSR P-256 / CA P-384)

---

### Communication Overhead Analysis

By comparing server-side (pure crypto) with client-side (end-to-end) benchmarks, we can derive the IPC communication overhead:

#### Hash Operations Overhead

| Metric         | Server-Side (Pure Crypto) | Client-Side Seq  | Seq IPC Overhead  | Client-Side Parallel | Parallel Speedup |
|----------------|---------------------------|------------------|-------------------|----------------------|------------------|
| Hash Operation | 1.93 μs (SHA3-256)        | 265 μs           | 263 μs            | 107 μs               | 2.5×             |

**Analysis**:

- **Sequential overhead**: 263 μs for full gRPC roundtrip (serialization, socket I/O, deserialization)
- **IPC dominates**: For fast operations like hashing, IPC overhead is 136× the actual crypto time
- **Seq IPC:Crypto ratio**: 263:1.93 = 136:1
- **Parallel speedup**: 265 μs / 107 μs = 2.5× — reflects concurrent request handling; parallel ns/op is not comparable to the single-threaded server baseline and does not represent an IPC overhead measurement

#### Certificate Signing Overhead

| Configuration (CSR key / CA key) | Server-Side (Pure Crypto) | Client-Side Seq  | Seq IPC Overhead  | Client-Side Parallel | Parallel Speedup |
|----------------------------------|---------------------------|------------------|-------------------|----------------------|------------------|
| CSR P-256 / CA P-384             | 1,061 μs                  | 1,733 μs         | 672 μs            | 869 μs               | 2.0×             |
| CSR P-256 / CA RSA-4096          | 4,445 μs                  | 5,001 μs         | 556 μs            | 2,040 μs             | 2.5×             |
| CSR P-521 / CA P-521             | 7,757 μs                  | 7,695 μs         | 0 μs (noise)      | 3,252 μs             | 2.4×             |

**Analysis**:

- **Sequential overhead**: 672 μs for CSR P-256 / CA P-384 roundtrip; 556 μs for CSR P-256 / CA RSA-4096; 0 μs for CSR P-521 / CA P-521 (within measurement noise — crypto time approaches or exceeds seq client time)
- **Seq IPC:Crypto ratio**: 0.63:1 for CSR P-256 / CA P-384 — unlike hashing, crypto work dominates over IPC cost for signing
- **Parallel speedup**: Measured as seq / parallel latency ratio (2.0×–2.5×). Parallel ns/op cannot be compared to the single-threaded server baseline — Go's `RunParallel` reports `total_wall_time / (N × iterations)`, which reflects concurrent throughput, not per-operation latency in isolation. This behaviour is consistent across platforms (observed on both AMD EPYC amd64 and Apple M2 Pro arm64)

#### Key Insights on IPC Performance

1. **Parallel Execution Configuration**:
   - All parallel benchmarks use GOMAXPROCS=4 (4 concurrent goroutines)
   - Each goroutine executes operations concurrently, sharing a single Unix socket connection
   - Parallelism is determined by the benchmark configuration (AMD EPYC 7763)

2. **Parallel Execution Effectiveness Varies by Operation**:
   - **Hash/Health operations**: 2.5× / 2.7× speedup
     - Fast crypto operations (1.93 μs) are completely dominated by IPC overhead (263 μs)
     - Parallel execution reduces per-operation latency by 60% via HTTP/2 multiplexing
   - **Sign operations**: 2.0×–2.5× speedup with GOMAXPROCS=4
     - Heavy crypto operations (1–8 ms) make IPC overhead proportionally much smaller
     - Parallel ns/op can fall below the single-threaded server baseline — this is a measurement artefact of Go's `RunParallel` dividing total wall time by `(N × iterations)`; it does not imply negative IPC overhead
     - The meaningful metric is the seq/parallel speedup ratio (2.0×–2.5×), driven by concurrent server-side processing of N simultaneous gRPC requests
     - This behaviour is consistent across platforms (AMD EPYC amd64 and Apple M2 Pro arm64)

3. **IPC Overhead Depends on Operation Weight**:
   - For fast operations (hash: 1.93 μs crypto), IPC dominates sequential latency (136:1)
   - For signing (CSR P-256 / CA P-384: 1,061 μs crypto), IPC is proportionally smaller (0.63:1)
   - For heaviest operations (CSR P-521 / CA P-521: 7,757 μs crypto), IPC adds negligible overhead (<1% of seq latency)
   - This pattern is consistent across platforms (observed on both AMD EPYC amd64 and Apple M2 Pro arm64)

4. **Parallel Execution is Critical**:
   - Reduces per-operation latency by 60% (hash/health) to 50–59% (signing)
   - gRPC/HTTP2 multiplexing amortizes connection setup and teardown
   - Concurrent operations share the same Unix socket connection

5. **Operation Complexity Matters**:
   - For fast operations (hash: 1.93 μs crypto), IPC dominates total sequential time (99%)
   - For lighter signing (CSR P-256 / CA P-384: 1,061 μs crypto), IPC represents 39% of seq latency
   - For heaviest operations (CSR P-521 / CA P-521: 7,757 μs crypto), IPC adds <1% overhead
   - Parallel ns/op is only meaningful relative to seq ns/op (speedup ratio); it is not a valid IPC overhead metric

6. **IPC Overhead Components** (263 μs sequential for hash):
   - Protobuf serialization/deserialization: 50–80 μs
   - Unix socket write/read system calls: 80–100 μs
   - gRPC framing and processing: 60–80 μs
   - Context switches and scheduling: 20–40 μs

7. **Optimization Strategies**:
   - **Batch operations**: Use parallel mode for multiple requests
   - **Algorithm selection**: CSR P-256 / CA P-384 offers best balance of signing speed and security
   - **Profile selection**: Choose algorithms balancing security and performance

---

### Key Performance Indicators (KPIs)

The following KPIs are tracked to ensure the Crypto Broker meets performance and reliability requirements:

#### Latency Metrics

Latency metrics measure the time delay for cryptographic operations, critical for applications requiring real-time or near-real-time responses. Lower latency improves user experience and enables higher throughput in request-heavy scenarios.

| Metric                    | Description                                                              | Target   | Current Performance                                                                           | Notes                              |
|---------------------------|--------------------------------------------------------------------------|----------|-----------------------------------------------------------------------------------------------|------------------------------------|
| Hash Operation Latency    | Time to compute a hash of arbitrary data using SHA-2/SHA-3 algorithms.   | < 375μs  | 265μs (seq), 107μs (parallel)                                                                 | Below target in both modes         |
| Sign Operation Latency    | Time to generate an X.509 certificate from a CSR.                        | < 2.3ms  | CSR P-256/CA P-384: 1,733μs (seq), 869μs (parallel); up to 7,695μs seq (CSR P-521/CA P-521)   | Below target for lightest combo    |
| Health Check Latency      | Time to query server health status.                                      | < 375μs  | 194μs (seq), 71μs (parallel)                                                                  | Minimal overhead                   |
| Parallel Performance Gain | Performance improvement when executing operations concurrently.          | > 2x     | 2.5x (hash), 2.7x (health), 2.0x–2.5x (sign)                                                  | Meets target across all operations |
| Memory per Operation      | RAM allocated per cryptographic operation.                               | < 40KB   | 9KB (hash), 5KB (health), 20–25KB (sign)                                                      | Lightweight memory footprint       |

#### Throughput Metrics

Throughput metrics measure the volume of cryptographic operations the server can process per unit time. High throughput is essential for applications with high request volumes or batch processing requirements.

| Metric                      | Description                                                              | Target  | Current Performance                               | Notes                                               |
|-----------------------------|--------------------------------------------------------------------------|---------|---------------------------------------------------|-----------------------------------------------------|
| Hash Operations/sec         | Number of hash computations completed per second under sustained load.   | > 2,700 | 3,770 (seq), 9,340 (parallel)                     | Exceeds target                                      |
| Sign Operations/sec         | Number of certificate signing operations completed per second.           | > 440   | 577 (seq CSR P-256/CA P-384), 1,151 (parallel)    | Exceeds target (CSR P-256/CA P-384 lightest combo)  |
| Health Check Operations/sec | Number of health checks completed per second.                            | > 2,700 | 5,155 (seq), 14,080 (parallel)                    | Excellent monitoring capacity                       |
| Parallel Scaling Efficiency | Throughput improvement ratio when switching to parallel execution.       | > 2x    | 2.5x (hash), 2.7x (health), 2.0x–2.5x (sign)      | Consistent improvement across all operations        |

#### Observability Coverage

Observability metrics track the system's ability to expose internal state and behavior for monitoring, debugging, and performance analysis. Comprehensive observability enables proactive issue detection and rapid troubleshooting.

| Metric                    | Description                                                                      | Target                | Current State | Notes                     |
|---------------------------|----------------------------------------------------------------------------------|-----------------------|---------------|---------------------------|
| Trace Coverage            | Percentage of crypto operations instrumented with distributed tracing spans.     | 100% of operations    | 100%          | OpenTelemetry integration |
| Structured Logging        | Percentage of log events emitted in machine-parsable format.                     | 100% of events        | 100%          | JSON/text format          |

#### Quality Metrics

Quality metrics assess code correctness, test coverage, and compliance with cryptographic standards. High quality ensures reliable cryptographic operations and regulatory compliance.

| Metric                             | Description                                                                      | Target         | Current State                                               | Notes                                                                               |
|------------------------------------|----------------------------------------------------------------------------------|----------------|-------------------------------------------------------------|-------------------------------------------------------------------------------------|
| Test Coverage                      | Percentage of source code lines executed during automated testing.               | > 80%          | Server: 20-25% / Go Client: 76.7% / JS Client: 53%          | Server below target / Go client near target / JS excluding generated code           |
| E2E Test Pass Rate                 | Percentage of end-to-end integration tests passing in CI/CD pipeline.            | 100%           | 100%                                                        | All tests passing                                                                   |
| Known-Answer Test (KAT) Compliance | Percentage of cryptographic operations validated against NIST test vectors.      | 100%           | Not yet measured                                            | NIST test vector validation                                                         |

**Notes on KPI Measurement**:

1. **Target Computation Methodology**:
   - **All targets are derived from benchmark data as initial baselines for deployment planning, not hard architectural requirements**
   - Targets serve as explainable performance expectations based on measured system behavior
   - Latency and throughput targets use a component-based formula that accounts for both cryptographic operations and IPC overhead
   - **Formula**: `Target = (Baseline_Crypto × (1 + α)) + (IPC_Overhead × (1 + β))`
   - **Components**:
     - `Baseline_Crypto`: Pure cryptographic operation time from server-side benchmarks (no IPC)
     - `α (crypto_margin)`: 0.25 (25% margin for algorithm variance and CPU differences)
     - `IPC_Overhead`: Inter-process communication overhead, categorized by operation class:
       - Lightweight operations (<1KB payload): 263 μs (hash, health check)
       - Heavy operations (>5KB payload): 672 μs (certificate signing, CSR P-256/CA P-384 reference)
     - `β (system_margin)`: 0.40 (40% margin for IPC variance and system differences)
   - **Example Calculation** (Hash Operation):

     ```text
     Baseline_Crypto = 1.93 μs (SHA3-256)
     IPC_Overhead = 263 μs (lightweight class)
     Target = (1.93 × 1.25) + (263 × 1.40) = 2.41 + 368.2 = 370.6 μs ≈ 375 μs
     ```

   - **System Dependency**: IPC overhead values measured on reference platform (Linux/amd64, AMD EPYC 7763). Actual overhead may vary by 30-50% on different hardware/architectures
   - **Throughput Targets**: Derived from latency targets using `Throughput = 1 / Target_Latency`
   - **Memory Targets**: Calculated from maximum observed memory usage across all operations
     - **Formula**: `Memory_Target = Max_Observed_Memory × (1 + γ)`
     - `γ (memory_margin)`: 0.60 (60% margin for GC overhead and system variance)
     - **Example**: Max observed = 25KB (sign CSR P-521/CA P-521 parallel) → Target = 25KB × 1.60 = 40KB
   - **Parallel Metrics**: Represent observed performance characteristics from parallel benchmark runs, not calculated values

2. **Benchmark Data Source**:
   - Latency and throughput metrics derived from Go benchmark framework tests
   - Client-side benchmarks: `crypto-broker-client-go` test suite with variable iteration counts for statistical significance
   - Server-side benchmarks: `crypto-broker-server/internal/bench` test suite with high iteration counts
   - See Test Configuration section above for platform and methodology details

3. **Measurement Accuracy**:
   - Go benchmark framework automatically determines iteration counts for statistical validity
   - Results represent average performance across all iterations
   - Sequential tests measure single-threaded performance
   - Parallel tests measure concurrent performance with 4 goroutines

4. **Production Monitoring**:
   - Current KPIs based on controlled benchmark environment
   - Production metrics require deployment with OpenTelemetry collectors
   - Real-world performance may vary based on:
     - Hardware specifications (CPU, memory, disk I/O)
     - Concurrent load patterns
     - Operating system and kernel configuration

5. **Continuous Improvement**:
   - KPIs reviewed and updated with each major release
   - Benchmark suite executed as part of CI/CD pipeline
   - Performance regression detection automated in testing
   - Target values adjusted based on production feedback and requirements
   - Targets should be recalculated when deploying to significantly different hardware platforms

6. **Test Coverage Measurement**:
   - **Server**: Measured via `go test -cover` (20-25%)
   - **Go Client**: Measured via `go test -cover` (76.7%)
   - **JS Client**: Measured via `npx jest --coverage` (53%)
   - Target is >80% across all components
   - **Known-Answer Test (KAT) Compliance**: NIST test vector validation to be implemented

---

## FIPS 140-3 Mode

### FIPS 140-3 Overview

The Crypto Broker supports FIPS 140-3 compliance for environments requiring validated cryptographic modules. This is documented in ADR-0007.

### Implementation Approach

**Decision**: Build-time linking to a specific validated module version with `GOFIPS140`

**Build Command**:

```bash
GOFIPS140=v1.0.0 go build -o bin/cryptobroker-server cmd/server/server.go
```

**Verification**:

```bash
go version -m bin/cryptobroker-server
# Output includes:
# build   GOFIPS140=v1.0.0
# build   DefaultGODEBUG=fips140=on
# build   -tags=fips140v1.0
```

### Why Build-Time Linking?

**Advantages**:

- **Frozen Module Version**: Links exact snapshot of Go Cryptographic Module v1.0.0
- **CMVP Traceability**: Can point to specific CMVP certificate for compliance proof
- **No Runtime Dependencies**: No need to set environment variables in production
- **Reproducible Builds**: Module version doesn't change between builds
- **Automatic Activation**: Sets `GODEBUG=fips140=on` by default

**Trade-offs**:

- Cannot switch to non-FIPS mode at runtime
- Must rebuild binary to change FIPS module version

### FIPS Mode Validation Status

- Go Cryptographic Module v1.0.0 is on the [CMVP Modules in Process](https://csrc.nist.gov/Projects/cryptographic-module-validation-program/modules-in-process/modules-in-process-list) list
- Submission date: 08.05.2025 (pending NIST review as of document date)
- Replaces the previously used Go+BoringCrypto module

### Performance Impact of FIPS Mode

**FIPS Configuration**:

- FIPS Module: Go Cryptographic Module v1.0.0-c2097c7c
- Build command: `GOFIPS140=v1.0.0 go build ...`
- Build tags: `-tags=fips140v1.0`
- Default GODEBUG: `fips140=on`
- Go version: go1.26.1

**Comparison Baseline**:

- Non-FIPS: Standard Go crypto libraries (same test configuration as Performance Evaluation section)

#### Server-Side (Pure Crypto) Performance Comparison

| Algorithm   | Non-FIPS (ns/op) | FIPS (ns/op) | Overhead  | Impact              |
|-------------|------------------|--------------|-----------|---------------------|
| SHA-256     | 703.1            | 714.9        | +11.8 ns  | +1.7% (negligible)  |
| SHA-384     | 1,304            | 1,309        | +5 ns     | +0.4% (negligible)  |
| SHA-512     | 1,405            | 1,411        | +6 ns     | +0.4% (negligible)  |
| SHA-512/256 | 1,198            | 1,182        | -16 ns    | -1.3% (negligible)  |
| SHA3-256    | 1,931            | 1,903        | -28 ns    | -1.5% (negligible)  |
| SHA3-384    | 2,386            | 2,361        | -25 ns    | -1.0% (negligible)  |
| SHA3-512    | 3,204            | 3,183        | -21 ns    | -0.7% (negligible)  |
| SHAKE-128   | 1,507            | 1,505        | -2 ns     | -0.1% (negligible)  |
| SHAKE-256   | 1,907            | 1,879        | -28 ns    | -1.5% (negligible)  |

#### Certificate Signing Performance Comparison

| Configuration (CSR key / CA key) | Non-FIPS (μs) | FIPS (μs) | Overhead  | Impact              |
|----------------------------------|---------------|-----------|-----------|---------------------|
| CSR P-256 / CA P-384             | 1,061         | 1,063     | +2 μs     | +0.2% (negligible)  |
| CSR P-256 / CA RSA-4096          | 4,445         | 4,210     | -235 μs   | -5.3% (FIPS faster) |
| CSR P-521 / CA P-521             | 7,757         | 7,315     | -442 μs   | -5.7% (FIPS faster) |

#### Client-Side (End-to-End) Performance Comparison

| Operation                                    | Non-FIPS  | FIPS      | Overhead   | Impact                              |
|----------------------------------------------|-----------|-----------|------------|-------------------------------------|
| HashData (seq)                               | 265 μs    | 266 μs    | +1 μs      | +0.2% (negligible)                  |
| HashData (parallel)                          | 107 μs    | 92 μs     | -15 μs     | -14.0% (measurement variance)       |
| SignCertificate CSR P-256/CA P-384 (seq)     | 1,733 μs  | 1,747 μs  | +14 μs     | +0.8% (negligible)                  |
| SignCertificate CSR P-256/CA P-384 (para.)   | 869 μs    | 696 μs    | -173 μs    | -19.9% (concurrent execution)       |
| SignCertificate CSR P-256/CA RSA-4096 (seq)  | 5,001 μs  | 5,521 μs  | +520 μs    | +10.4%                              |
| SignCertificate CSR P-256/CA RSA-4096 (para.)| 2,040 μs  | 2,311 μs  | +271 μs    | +13.3%                              |
| SignCertificate CSR P-521/CA P-521 (seq)     | 7,695 μs  | 9,323 μs  | +1,628 μs  | +21.2%                              |
| SignCertificate CSR P-521/CA P-521 (para.)   | 3,252 μs  | 3,372 μs  | +120 μs    | +3.7%                               |
| HealthData (seq)                             | 194 μs    | 195 μs    | +1 μs      | +0.6% (negligible)                  |
| HealthData (parallel)                        | 71 μs     | 69 μs     | -2 μs      | -2.8% (within margin of error)      |

#### Key Findings

1. **Hash Operations**: FIPS mode has **negligible overhead** (<2%) for all hash algorithms
   - Differences are within measurement noise (single-digit nanoseconds)
   - Some measurements show FIPS slightly faster, indicating measurement variance
   - FIPS integrity checks have minimal impact on hash performance

2. **Certificate Signing (Pure Crypto)**: FIPS mode shows **slightly better performance** for complex signing operations
   - CSR P-256/CA P-384: +0.2% (negligible, within noise)
   - CSR P-256/CA RSA-4096: -5.3% (FIPS ~235 μs faster)
   - CSR P-521/CA P-521: -5.7% (FIPS ~442 μs faster)
   - Likely due to FIPS-validated code paths being well-optimized for x86_64 on AMD EPYC

3. **End-to-End Performance**: FIPS shows **measurable overhead for RSA-4096 and P-521 signing** in real-world scenarios
   - Lightweight operations (hash, health, CSR P-256/CA P-384 signing): <1% difference (within measurement noise)
   - CSR P-256/CA RSA-4096 signing (seq): +10.4% overhead (~520 μs); parallel: +13.3%
   - CSR P-521/CA P-521 signing (seq): +21.2% overhead (~1.6 ms); parallel: +3.7%
   - Note: IPC baseline overhead (~263 μs) partially masks FIPS impact for hash/health operations
   - Negative values in parallel mode reflect concurrent execution variance, not genuine improvement

4. **Memory Usage**: FIPS mode shows **no significant memory difference** on AMD EPYC
   - HashData: 8,783 B/op (non-FIPS) vs 8,783 B/op (FIPS) = no change
   - HealthData: 5,473 B/op (non-FIPS) vs 5,471 B/op (FIPS) = no change
   - SignCertificate: 23,120 B/op (non-FIPS) vs 23,150 B/op (FIPS) = no change
   - Allocation counts are identical between FIPS and non-FIPS builds
   - Note: Memory behavior may differ from other platforms (e.g., previously measured 17–40% reduction on Apple M2 Pro)

5. **Startup Time Overhead**
   - FIPS mode adds ~50-100ms for self-checks and known-answer tests
   - One-time cost at server initialization
   - Negligible impact on overall service availability

#### Deployment Recommendation

**Enable FIPS mode by default**. The performance impact is acceptable while providing:

- CMVP-validated cryptographic operations
- Regulatory compliance (FedRAMP, FIPS 140-3 requirements)
- Additional integrity checks and known-answer tests
- Negligible or no overhead for hash and lightweight signing operations (CSR P-256/CA P-384)
- Note: Applications relying heavily on CSR P-256/CA RSA-4096 or CSR P-521/CA P-521 signing should expect ~10–21% additional latency in sequential mode; use parallel execution mode to mitigate

### FIPS Mode Features

When FIPS mode is enabled:

- **DRBG with Kernel Entropy**: Uses NIST-compliant DRBG seeded with kernel entropy
- **Approved Algorithms Only**: TLS and crypto operations restricted to FIPS-approved algorithms
- **Integrity Self-Checks**: Module integrity verification on startup
- **Known-Answer Tests**: FIPS module runs internal KATs at startup to validate core crypto primitives
- **Runtime Verification**: `crypto/fips140.Enabled()` function confirms mode is active

---

## Deployment Architecture

### Deployment Targets

The Crypto Broker supports two primary deployment platforms:

1. **Cloud Foundry** (PaaS)
2. **Kubernetes** (Container orchestration)

Both deployments follow the sidecar pattern: the Crypto Broker Server runs alongside the main application, communicating via Unix socket over a shared filesystem.

### Cloud Foundry Deployment

**Deployment Model**: Sidecar Process

**Key Components**:

- Main application (using client library)
- Crypto Broker Server (sidecar process)
- Shared filesystem for Unix socket (`/tmp`)
- Profiles configuration file

**Manifest Structure** (example for Go client):

```yaml
applications:
  - name: my-app
    command: './my-app'
    health-check-type: process
    sidecars:
      - name: crypto-broker-server
        health-check-type: process
        command: 'CRYPTO_BROKER_PROFILES_DIR=$PWD ./cryptobroker-server'
```

**Deployment Approach** (ADR-0002):

- **Pre-compiled Binaries**: Deploy compiled executables, not source code
- **Reasons**:
    - Binary can be signed for integrity verification
    - No dependency resolution at runtime
    - Faster deployment (no compilation step)
    - Reproducible builds independent of CF buildpack version
    - Meets compliance requirements (verified artifacts)

1. Download pre-compiled server binary from releases
2. Configure profiles and manifest files
3. Deploy using Cloud Foundry CLI

Refer to the deployment repository for platform-specific examples and current command syntax.

**Cloud Foundry Specifics**:

- Uses binary buildpack
- Health checks configured as `process` type
- Environment variables passed via manifest
- Shared `/tmp` directory for Unix socket

### Kubernetes Deployment

**Deployment Model**: Multi-Container Pod

**Key Components**:

- Pod with multiple containers:
    - Application container(s) using client library
    - Crypto Broker Server container
- Shared volume for Unix socket
- ConfigMaps for profiles and configuration
- Optional: Secrets for certificates

**Helm Chart Structure**:

```text
kube-broker/
├── Chart.yaml           # Chart metadata
├── values.yaml          # Configurable parameters
└── templates/
    ├── deployment.yaml  # Pod definition
    ├── configmap.yaml   # Configuration
    └── helpers.tpl      # Template helpers
```

**Key Configuration** (`values.yaml`):

```yaml
namespace: crypto-broker
replicaCount: 1

serverApp:
  name: server-app
  image:
    name: ghcr.io/open-crypto-broker/server
    pullPolicy: IfNotPresent

volumes:
  - name: socket-volume
    emptyDir: {}  # Shared Unix socket volume

volumeMounts:
  - name: socket-volume
    mountPath: /tmp
```

**Deployment Process**:

For detailed deployment instructions and up-to-date commands, see the [crypto-broker-deployment README](https://github.com/open-crypto-broker/crypto-broker-deployment). The general workflow includes:

1. **Prepare Environment**: Build or pull container images
2. **Configure Helm Values**: Customize deployment parameters in `values.yaml`
3. **Deploy**: Install Helm chart to Kubernetes cluster
4. **Verify**: Check pod status and logs
5. **Manage**: Update, scale, or uninstall as needed

Refer to the deployment repository for specific commands, examples for different Kubernetes distributions (minikube, EKS, AKS, GKE), and troubleshooting guidance.

**Kubernetes Features**:

- **Shared Volumes**: `emptyDir` volume for Unix socket sharing between containers
- **ConfigMaps**: Profile configuration and environment variables
- **Security Context**: Non-root user, read-only filesystem, dropped capabilities
- **Resource Limits**: Configurable CPU/memory limits
- **Multiple Replicas**: Scalable deployment (each pod is independent)

### Docker Compose (Local Development)

For local development and testing, Docker Compose provides a quick way to run multi-container setups. See the [crypto-broker-deployment README](https://github.com/open-crypto-broker/crypto-broker-deployment) for current setup instructions and commands.

Docker Compose provides:

- Multi-container local setup
- Similar environment to production
- Easy testing and debugging
- No cluster required

---

## Resilience and Fault Tolerance

### Server Crash Handling

#### Cloud Foundry

**Restart Policy**:

- Cloud Foundry automatically monitors process health
- Health check type: `process` (monitors if process is running)
- If sidecar crashes, CF restarts it automatically
- Restart attempts configured per deployment

**Impact of Server Crash**:

- **Client Behavior**: Connection failures, requests timeout
- **Application Impact**: Applications receive connection errors from client library
- **Recovery Time**: Typically 5-10 seconds for CF to detect and restart
- **State**: Server is stateless; no data loss on restart

**Simulating Crashes**:

1. **Find the Process**:

   ```bash
   cf ssh my-app
   ps aux | grep cryptobroker-server
   ```

2. **Kill the Process**:

   ```bash
   kill -9 <PID>
   ```

3. **Observe Recovery**:

   ```bash
   cf logs my-app --recent
   # Watch for sidecar restart
   ```

4. **Verify Recovery**:

   ```bash
   # Application should reconnect automatically
   # Check client library logs for reconnection attempts
   ```

#### Kubernetes

**Restart Policy**:

- Kubernetes monitors container health via kubelet
- Default restart policy: `Always`
- Container restarts automatically on crash
- Exponential backoff for repeated failures

**Impact of Server Crash**:

- **Pod-Level**: Only the server container crashes, other containers continue running
- **Client Behavior**: Clients in the same pod receive connection errors
- **Recovery Time**: Typically 2-5 seconds for immediate restart
- **Backoff**: 10s, 20s, 40s, etc. for repeated failures (max 5 minutes)

**Simulating Crashes**:

1. **Method 1: Kill Process Inside Container**:

   ```bash
   # Find the pod
   kubectl get pods -n crypto-broker
   
   # Execute in server container
   kubectl exec -it <pod-name> -c server-app -n crypto-broker -- /bin/sh
   
   # Find and kill process
   ps aux | grep cryptobroker
   kill -9 <PID>
   
   # Exit container
   exit
   ```

2. **Method 2: Delete Container (more forceful)**:

   ```bash
   # Get pod name
   kubectl get pods -n crypto-broker
   
   # Delete the pod (will be recreated by deployment)
   kubectl delete pod <pod-name> -n crypto-broker
   ```

3. **Method 3: Induce Crash via Chaos Engineering** (advanced):

   ```bash
   # Install Chaos Mesh or similar tool
   # Create chaos experiment to kill containers randomly
   ```

4. **Observe Recovery**:

   ```bash
   # Watch pod status
   kubectl get pods -n crypto-broker -w
   
   # Check restart count
   kubectl describe pod <pod-name> -n crypto-broker
   # Look for "Restart Count: X"
   
   # View logs
   kubectl logs <pod-name> -c server-app -n crypto-broker
   ```

5. **Monitor with k9s** (recommended):

   ```bash
   k9s
   # Navigate to namespace: :namespace crypto-broker
   # View pods, press Enter to see containers
   # Check restart counts and logs
   ```

### Client Resilience

**Client Library Features**:

- **Retry Policies**: Configurable retry logic for transient failures
- **Connection Management**: Automatic reconnection on socket errors
- **Timeout Handling**: Configurable request timeouts
- **Error Propagation**: Clear error messages to application

**Best Practices**:

- Applications should handle connection errors gracefully
- Implement exponential backoff for retries at application level
- Log errors for debugging
- Consider circuit breaker pattern for repeated failures

### High Availability

**Scaling Strategies**:

1. **Horizontal Scaling** (Kubernetes):
   - Increase `replicaCount` in Helm values
   - Each pod runs independent server instance
   - Load distribution via application pod count

2. **Sidecar-per-Instance** (Both platforms):
   - Each application instance has its own server sidecar
   - No shared state, no single point of failure
   - Linear scaling with application instances

**State Management**:

- Server is stateless (no session data)
- Configuration loaded from profiles on startup
- No database or persistent storage required
- Crashes only affect in-flight requests (which fail and can be retried)

### Monitoring and Observability

**OpenTelemetry Integration**:

- Distributed tracing for all requests
- Span attributes: operation type, algorithm, input size, etc.
- Exporter options: OTLP, console, or both
- Helps identify performance bottlenecks and failures

**Health Checks**:

- gRPC health check protocol support
- CLI health command: `./cli health`
- Can be integrated into platform health checks

**Logging**:

- Structured logging (JSON or text format)
- Configurable log levels (debug, info, warn, error)
- Output to stdout/stderr for container log collection

---

## Security Considerations

The Crypto Broker's security architecture follows a security-by-design approach, embedding security controls at the architectural level rather than relying solely on operational measures. This section describes the built-in security properties and the essential deployment requirements for operators.

### Security-by-Design Principles

#### Access Control

- **Unix Socket Permissions**: File system permissions control access
- **Local-Only**: Server only listens on Unix socket (no network exposure)
- **Sidecar Pattern**: Isolates crypto operations from application process

#### Cryptographic Material

- **Private Keys**: Passed in request payloads (not stored by server)
- **Certificates**: Transient (exist only during request processing)
- **No Persistence**: Server does not store any cryptographic material
- **Memory Safety**: Go's memory management reduces leak risks

#### Profile Configuration

- **YAML-Based**: Human-readable, version-controllable
- **Validation**: Server validates profile structure on startup
- **Least Privilege**: Profiles define allowed algorithms, preventing unauthorized operations

#### Compliance

- **FIPS 140-3**: Build-time enforcement of validated crypto module
- **Algorithm Restrictions**: Profile-based control of approved algorithms
- **Audit Trail**: OpenTelemetry traces provide request audit logs
- **Reproducible Builds**: Pre-compiled binaries

### Deployment Security Requirements

**Unix Socket File Permissions** (automatic):

The server automatically enforces socket security on startup:

- Creates the socket directory (`/tmp/open-crypto-broker/`) with `0700` permissions if it does not exist
- Applies `0600` permissions to the socket file immediately after binding
- Refuses to start (panics) if either operation fails — the server will not run without secure socket permissions

No operator action is required for socket permissions.

**Profile Configuration Protection** (mandatory):

- Store profile YAML files with restrictive permissions (chmod 640 minimum)
- Validate profile changes in non-production environments before deployment

**Key Management** (application responsibility):

- Applications must securely manage CA private keys used for signing operations
- Implement key rotation policies aligned with organizational security requirements

---

## References

### Documentation

- [Architecture Documentation](./)
- [API Specifications](../spec/)
- [Architectural Decision Records](../adr/)
- [Deployment Guide](https://github.com/open-crypto-broker/crypto-broker-deployment)

### External Resources

- [gRPC Documentation](https://grpc.io/)
- [Protocol Buffers](https://protobuf.dev/)
- [FIPS 140-3 Go Compliance](https://go.dev/doc/security/fips140)
- [Cloud Foundry Deployment](https://docs.cloudfoundry.org/devguide/deploy-apps/deploy-app.html)
- [Kubernetes Helm](https://helm.sh/)
- [OpenTelemetry](https://opentelemetry.io/)

### Key ADRs

- [**ADR-0002**: Cloud Foundry Deployment Strategy (Pre-compiled Binaries)](../adr/overall/0002-cf-deployment.md)
- [**ADR-0003**: Sidecar Architecture Alternatives](../adr/overall/0003-sidecar-alternatives.md)
- [**ADR-0004**: Communication Protocol Selection (gRPC vs HTTP)](../adr/overall/0004-communication-protocol.md)
- [**ADR-0005**: Message Structure (Protocol Buffers)](../adr/overall/0005-message-structure.md)
- [**ADR-0007**: FIPS 140-3 Mode Implementation (Build-time Linking)](../adr/overall/0007-fips140-3-mode.md)

---

## Conclusion

The Crypto Broker provides a robust, performant, and compliant solution for offloading cryptographic operations in cloud-native environments. Its sidecar architecture, multi-language support, and FIPS 140-3 compliance make it suitable for enterprise applications with strict security and regulatory requirements.

Key strengths:

- **Performance**: Sub-millisecond communication overhead, optimized crypto operations
- **Compliance**: FIPS 140-3 support with validated crypto module
- **Flexibility**: Profile-based configuration, multiple deployment targets
- **Resilience**: Automatic restart, stateless design, built-in observability
- **Developer Experience**: Simple client APIs, comprehensive documentation, example applications

The architecture is designed for extensibility, with clear component boundaries and well-defined interfaces, enabling future enhancements while maintaining backward compatibility.

---

**Document Version**: 1.0  
**Last Updated**: March 2026  
**Authors**: Crypto Broker Team (documentation assisted by GitHub Copilot using Claude Sonnet 4.6)  
**Status**: Living Document
