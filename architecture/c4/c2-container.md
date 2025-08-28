
```mermaid
C4Container
    title Container Diagram for CryptoAgility Project

    Person_Ext(user, "User")

    System_Boundary(container, "CryptoAgility") {
        Container(app, "Application")
        Container(cb, "CryptoBroker server")
        BiRel(app, cb, "Uses")
    }

    BiRel(user, app, "Uses")

```
