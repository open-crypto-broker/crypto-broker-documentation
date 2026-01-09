# Crypto Broker API Template

This document outlines the steps required to include a new API in the Crypto Broker server and its ecosystem.

1. **Determine ADR Requirement**: Assess whether an Architecture Decision Record (ADR) is needed for the new API. If required, create an ADR in the `crypto-broker-documentation` repository.
2. **Update Specifications**: If no ADR is needed, update the API specifications in the `spec` folder of the `crypto-broker-documentation` repository.
    - Review and update any relevant architecture diagrams as necessary.
3. **Implement API in Server**: Develop the new API in the `crypto-broker-server` repository.
4. **Update Client Libraries**: Implement or update the public-facing API in the client libraries (`crypto-broker-client-go`, `crypto-broker-client-js`).
5. **Update CLI Tools**: Update CLI tools (`crypto-broker-cli-go`, `crypto-broker-cli-js`) to support and test the new API.
6. **Add End-to-End Tests**: If needed, implement new end-to-end test cases in the `crypto-broker-deployment` repository to cover the new API.
7. **Update Documentation**: Revise documentation (README, API docs) to reflect the new API and its usage.
8. **Create Release**: If needed, create a new release for the updated repositories to include the new API.
9. **Notify Stakeholders**: Inform relevant stakeholders or users about the addition of the new API.

---

## Flowchart

```mermaid
flowchart TD
    A[Start] --> B{Is ADR needed?}
    B -- Yes --> C[Create ADR in documentation repo]
    B -- No --> D[Update API specs in spec folder]
    D --> E[Update architecture diagrams if needed]
    C --> F[Implement API in server repo]
    E --> F
    F --> G[Update client libraries]
    G --> H[Update CLI tools]
    H --> I[Add end-to-end tests if needed]
    I --> J[Update documentation: README, API docs]
    J --> K{Create release?}
    K -- Yes --> L[Create new release]
    K -- No --> M[Notify stakeholders]
    L --> M
    M --> N[End]
```
