---
status: accepted
date: 2025-06-06
decision-makers: Stephan Andre, Maximilian Lenkeit, Anselme Tueno
consulted: Arturo Guridi, Pawel Chmielewski, Robin Winzler, Daniel Becker
informed: Erwin Margewitsch
---

# Specification of message structures for the communication between the application and the Crypto Broker

## Context and Problem Statement

This ADR specifies the message structure which the application and the Crypto Broker use to exchange data in the form of requests and responses.
To ensure consistency, maintainability, and reliability across implementations of the Crypto Broker in different programming languages, a well-defined message structure must be introduced.
We will define message structures for the communication between the application and the sidecar, which handles requests (hash/sign command sent from the application to the broker) and responses (result of the crypto function sent by the broker back to the application).

## Decision Drivers

* The communication should contain a well-defined and consistent structure and data format for transmitted data
    * The structure should contain all required and optional fields needed for a consistent exchange of requests and responses
    * The structure should comply with the API requirements set for the specific functions (hash/sign)
* The message structure should be able to handle errors (e.g. unexpected disconnection or erroneous data)
* The data format should be interoperable across different programming languages and easy to integrate
* The data format should offer an efficient way to communicate (regarding time and complexity)

## Considered Options

* Text-based data format
    * JSON
    * XML
* Binary data format
    * BSON
    * Protobuf

## Decision Outcome

Chosen option: Protobuf

### Consequences

* Based on the decision to use gRPC as the IPC protocol, the decision for the message structure is to use Protobuf
* Note that this ADR decides the message data format and a preliminary structure, which is subject to modifications based on other work in progress

### Confirmation

* Confirmed by: Maximilian Lenkeit, Maik Müller, Stephan Andre

## Pros and Cons of the Options

### Protobuf as the data format

#### Description

This option defines a data structure in Protobuf for gRPC based connections.

#### Pros

* High performance (speed and efficiency)
* Compatibility with multiple programming languages
* Supports "bytes" data format
* Strong typing
* Client-side code generation
* Ootb support for HTTP and Unix domain sockets

#### Cons

* Potentially hard to debug
* Limited readability and testing
* Message structure needs to be compiled to code in order to be used in application logic

### JSON as the data format

#### Description

This option defines a data structure in JSON for http based connections.

#### Pros

* Human readable, simple, familiar, widely known
* Easy to test
* Easy to integrate with tools like Postman or curl

#### Cons

* Does not support data type "bytes"
    * Byte data needs to be base64 encoded, which increases computation time
* Limited semantics
* Slow to process compared to binary formats

## More Information

### Protobuf message structure draft (gRPC)

#### General

```proto
syntax = "proto3";

package cryptobroker;

service CryptoBroker {
    rpc Hash(HashRequest) returns (HashResponse);
    rpc Sign(SignRequest) returns (SignResponse);
}

message Metadata {
    string id = 1;
    google.protobuf.Timestamp createdAt = 2;
}
```

#### Request

```proto
message HashRequest {
    Metadata metadata = 1;
    string profile = 2;
    bytes hashInput = 3;
}

message SignRequest {
    Metadata metadata = 1;
    string profile = 2;
    bytes csr = 3;
    bytes signingKey = 4;
    bytes caCert = 5;

    // optional not before offset and flag whether it is provided to handle implicit/explicit zeros
    bool notBeforeOffsetProvided = 6;
    optional string notBeforeOffset = 7; // in time.Duration

    // optional not after offset and flag whether it is provided to handle implicit/explicit zeros
    bool notAfterOffsetProvided = 8;
    optional string notAfterOffset = 9; // in time.Duration

    // optional CRL distribution points
    repeated string crlDistributionPoints = 10;

    // optional override of Subject
    optional string subject = 11;
}
```

#### Response

```proto
message HashResponse {
    Metadata metadata = 1;
    string hashValue = 2;
    HashCryptoMetadata cryptoMetadata = 3;
}

message SignResponse {
    Metadata metadata = 1;
    bytes signedCertificate = 2; // in .der/.pem format
}

message Error {
    string errorMsg = 1;
}

message HashCryptoMetadata {
    string hashAlgorithm = 1;
}
```

### JSON message structure draft (HTTP)

#### General

```json
{
    "endpoints": [
        {
            "url": "/hash",
            "method": "POST",
            "requestSchema": { "$ref": "schemas/request/hashRequest" },
            "responseSchema": { "$ref": "schemas/response/hashResponse" }
        },
        {
            "url": "/sign",
            "method": "POST",
            "requestSchema": { "$ref": "schemas/request/signRequest" },
            "responseSchema": { "$ref": "schemas/response/signResponse" }
        }
    ]
}

{
    "$id": "/schemas/metadata",
    "type": "object",
    "properties": {
        "id": {
            "type": "string",
            "description": "A unique identifier for the request/response object."
        },
        "createdAt": {
            "type": "string",
            "format": "date-time",
            "description": "The timestamp when the message was generated."
        }
    },
    "required": ["id", "createdAt"]
}
```

#### Request

```json
{
    "$id": "schemas/request/hashRequest",
    "type": "object",
    "properties": {
        "metadata": { "$ref": "/schemas/metadata" },
        "profile": {
            "type": "string",
            "description": "Name of the crypto profile used for this operation."
        },
        "hashInput": {
            "type": "string",
            "contentEncoding": "base64",
            "description": "Base64 encoded hash input bytes."
        }
    },
    "required": ["metadata", "profile", "hashInput"]
}

{
    "$id": "schemas/request/signRequest",
    "type": "object",
    "properties": {
        "metadata": { "$ref": "/schemas/metadata" },
        "profile": {
            "type": "string",
            "description": "Name of the crypto profile used for this operation."
        },
        "csr": {
            "type": "string",
            "description": "CSR content in pem format."
        },
        "signingKey": {
            "type": "string",
            "description": "Signing key content in pem format."
        },
        "caCert": {
            "type": "string",
            "description": "CA certificate in pem format."
        },
        "notBeforeOffset": {
            "type": "string",
            "description": "Optional: Time offset for notBefore validity field. Will be parsed to time.Duration."
        },
        "notAfterOffset": {
            "type": "string",
            "description": "Optional: Time offset for notAfter validity field. Will be parsed to time.Duration."
        },
        "crlDistributionPoints": {
            "type": "array",
            "items": {
                "type": "string",
                "format": "uri"
            },
            "description": "Optional: List of CRL distribution point URIs."
        },
        "subject": {
            "type": "string",
            "description": "Optional: Subject override."
        }
    },
    "required": ["metadata", "profile", "csr", "signingKey", "caCert"]
}
```

#### Response

```json
{
    "$id": "/schemas/response/hashResponse",
    "type": "object",
    "properties": {
        "hashValue": {
            "type": "string",
            "description": "Hash value of provided input."
        },
        "cryptoMetadata": { "$ref": "/schemas/hashCryptoMetadata" }
    },
    "required": ["hashValue", "cryptoMetadata"]
}

{
    "$id": "/schemas/response/signResponse",
    "type": "object",
    "properties": {
        "signedCertificate": {
            "type": "string",
            "description": "Certificate generated from the provided CSR in pem format."
        }
    },
    "required": ["signedCertificate"]
}

{
    "$id": "/schemas/hashCryptoMetadata",
    "type": "object",
    "properties": {
        "hashAlgorithm": {
            "type": "string",
            "description": "Hash algorithm used."
        }
    },
    "required": ["hashAlgorithm"]
}

{
    "$id": "/schemas/error",
    "type": "object",
    "properties": {
        "err": {
            "type": "string",
            "description": "Error message."
        }
    },
    "required": ["err"]
}
```
