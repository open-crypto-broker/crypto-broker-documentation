---
status: accepted
date: 2025-03-26
decision-makers: Stephan Andre, Maximilian Lenkeit, Anselme Tueno
consulted: Daniel Becker, Arturo Guridi, Pawel Chmielewski, Jens Siecke, Robin Winzler
informed: Erwin Margewitsch
---

# Definition of library API for the Crypto Broker

## Context and Problem Statement

An application might want to use certain cryptographic functionalities like hashing, signing or encrypting data in order to meet certain security requirements (confidentiality, integrity, authenticity).
The application will call functions from a library, which in turn will take care of connecting to the Crypto Broker.
In order to achieve this goal in a crypto-agile way, profiles for the Crypto Broker can be named and structured along different dimensions and options.
One option is that the library specifies which profile shall be used (e.g. PCI-DSS, NIST).
Another option is that the library uses cryptographic functionality in an profile-agnostic approach s.t. the library does not know which profile is used at all.
This ADR is about deciding on these options.

## Decision Drivers

* It should be crypto-agile: application should not need to worry about which cryptographic algorithm is used
* The profiles should meet the requirements from certain institutions or countries (e.g. BSI, NIST, KSA, ...)

## Considered Options

* Profile name as parameter for function calls
* Generic function calls

## Decision Outcome

Chosen option: Profile name as parameter for function calls

### Consequences

* Good, because the application can quickly change the profile by just changing the profile name (crypto-agile) in the function calls.

* Bad, because the application needs to know which profiles are available.

### Confirmation

* Confirmed by: Stephan Andre

## Pros and Cons of the Options

### Profile name as parameter for function calls

#### Description

* The library API can select different profiles as a parameter

  ```C
  hash(BSI, <other parameters>);
  sign(PCI-DSS, <other parameters>);
  ```

* When the application calls a crypto function via the library API, a profile name is passed on to the Crypto Broker, for example as a function parameter or a globally set static variable
    * The library API MUST specify a profile name, even if it is just the default profile
* The names of the profile shall reflect generic profile names corresponding to, e.g. a standard for credit card payments such as PCI DSS, or a governmental policy such as BSI, NIST, or KSA
* Upon receiving an application request, the library API constructs a request with the specified profile. The Crypto Broker, parses the algorithms specified in the profile and executes the corresponding crypto functions

#### Pros

* The default profile guarantees broker-side agility
* The application does not need to care about the algorithms
* In case of a regulatory change or different desired application behavior, the respective algorithms are changed in the profile

#### Cons

* The application needs to know which profiles are available to use
* In case the application is deployed in multiple regulatory regions, each application deployment needs to specify the corresponding profile (e.g. NIST-compliance vs. KSA-compliance), hindering a scalable deployment approach
* The application has to handle the response which is sent back from the Crypto Broker
    * If a profile is changed, this will lead to a different response from the Crypto Broker, which must be caught by the application

### Generic function calls

#### Description

* The library API invokes Crypto Broker functions without specifying profiles

  ```C
  hash(file);
  sign(csr);
  ```

#### Pros

* The decision which profile is used, is made by the institution/company/government
* In case of a regulatory change or different desired application behavior, the respective algorithms are changed in the profile
* Only the Crypto Broker needs to load the profile at startup

#### Cons

* The application cannot set the profile
* The application has to handle the response which is sent back from the Crypto Broker
    * If a profile is changed, this will lead to a different response from the Crypto Broker, which must be caught by the application
