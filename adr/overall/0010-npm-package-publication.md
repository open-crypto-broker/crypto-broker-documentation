---
status: "proposed"
date: 2025-12-10
decision-makers: Stephan Andre, Maximilian Lenkeit, Anselme Tueno
consulted: Miyana Stange, Robin Winzler, Pawel Chmielewski, Mirkanan Kazimzade
informed: Erwin Margewitsch
---

# Package Publication Options for the TS Client Library

## Context and Problem Statement

For distribution of the TS Client Library it is generally desirable to push the project to a global package registry.
Publishing to such a registry allows developers to install the library with familiar tooling, e.g. by using the Node Package Manager (npm).
The default source for the node package manager is npmjs.org. But it can also be configured to use another package repository, e.g. Github's (npm) package registry.

The aim of this ADR is to discuss how we want to publish the ts client library, either using the npmjs.org registry, the github npm package registry, respectively, both or none of them.

## Decision Drivers

* Higher Visibility and Discoverability
* Easy Maintenance
* No additional costs

## Considered Options

* Publish on the public npm registry (npmjs.org)
* Publish on GitHub Packages (GitHub's npm registry)
* Publish on both
* Do not publish to a registry

## Decision Outcome

Chosen option: [TBD]

### Consequences

* Good, because [TBD]
* Bad, because [TBD]

### Confirmation

{Describe how the implementation / compliance of the ADR can/will be confirmed. Is there any automated or manual fitness function? If so, list it and explain how it is applied. Is the chosen design and its implementation in line with the decision? E.g., a design/code review or a test with a library such as ArchUnit can help validate this. Note that although we classify this element as optional, it is included in many ADRs.}

## Pros and Cons of the Options

### Publish on npmjs.org

* Good, because
    * the public npm registry is where most JS/Node developers search and install packages; most tooling and CI workflows expect it
    * it maximizes the visibility and discoverability in the default npm ecosystem
    * providing public packages is free of charge
* Neutral, because
    * we also use the npmjs.org registry for our packages dependencies
* Bad, because
    * the npmjs packages have to be managed separately (e.g. collaborators/teams need to be managed separately in npmjs).
    * the visibility and discoverability is limited to npmjs.org

### Publish on GitHub Packages

* Good, because
    * everything is in one place/ecosystem
    * no separate accounts (and permission configurations) have to be created for managing the npm package
    * providing public packages is free of charge (note: the default visibility is set to private)
* Bad, because
    * the visibility and discoverability is mostly tied to github
    * hosting everything on github has a big impact if the services are down

### Publish on both

* Good, because
    * the visibility and discoverability is further expanded
    * if one registry has an outage, an alternative source is available
* Bad, because
    * management of permissions and roles is expanded using separate platforms

### Do not publish to a registry

* Good, because
    * there is less maintenance and permission management needed
* Neutral, because
    * the package can still be installed using the github repository url
* Bad, because
    * the package will be unavailable during outages
    * visibility and discoverability are reduced to a minimum

## More Information
