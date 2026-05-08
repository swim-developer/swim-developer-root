# swim-developer — Architecture

> Diagrams use [Mermaid](https://mermaid.js.org) and render natively on GitHub.

---

## 1. System Context (C4 Level 1)

```mermaid
C4Context
    title System Context — swim-developer

    Person(operator, "Service Operator", "Configures subscriptions and monitors service health via REST API")

    System(swimDev, "swim-developer", "Open-source SWIM CP1 reference implementation: DNOTAM and ED-254 Consumer and Provider services")

    System_Ext(eurocontrol, "EUROCONTROL / EAD", "External SWIM network — Subscription Manager REST API + AMQP broker")
    System_Ext(atm, "ATM Systems", "Downstream consumers — receive domain events via Kafka")
    System_Ext(platform, "Kubernetes / OpenShift", "Container orchestration platform")

    Rel(operator, swimDev, "Manages subscriptions and queries features", "REST / HTTPS")
    Rel(swimDev, eurocontrol, "Subscribes to topics, manages subscriptions", "REST / HTTPS + AMQP 1.0 / mTLS")
    Rel(swimDev, atm, "Forwards processed events", "Apache Kafka")
    Rel(swimDev, platform, "Runs on", "OCI containers")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## 2. Container Diagram (C4 Level 2)

```mermaid
C4Container
    title Container Diagram — swim-developer

    Person(operator, "Service Operator")

    System_Ext(extBroker, "EUROCONTROL AMQP Broker", "ActiveMQ Artemis — AMQP 1.0 / mTLS")
    System_Ext(extSM, "External Subscription Manager", "REST API — HTTPS / mTLS")
    System_Ext(kafka, "Apache Kafka", "Event streaming backbone")

    System_Boundary(swimDev, "swim-developer") {
        Container(dnotamConsumer, "swim-dnotam-consumer", "Quarkus / Java 21", "DNOTAM Consumer: subscribes to AISP, processes AIXM 5.1.1 events, persists to MongoDB")
        Container(dnotamProvider, "swim-dnotam-provider", "Quarkus / Java 21", "DNOTAM Provider: subscription REST API + AMQP event publishing to subscribers")
        Container(ed254Consumer, "swim-ed254-consumer", "Quarkus / Java 21", "ED-254 Consumer: subscribes to arrival sequence events, detects sequence gaps")
        Container(ed254Provider, "swim-ed254-provider", "Quarkus / Java 21", "ED-254 Provider: subscription REST API + AMQP arrival sequence publishing")
        ContainerDb(mongodb, "MongoDB", "Document store", "Consumer event and subscription persistence")
        ContainerDb(postgres, "PostgreSQL", "Relational DB", "Provider subscription and event persistence")
    }

    Rel(operator, dnotamConsumer, "Manages subscriptions", "REST / HTTPS")
    Rel(operator, dnotamProvider, "Manages subscriptions", "REST / HTTPS")
    Rel(operator, ed254Consumer, "Manages subscriptions", "REST / HTTPS")
    Rel(operator, ed254Provider, "Manages subscriptions", "REST / HTTPS")

    Rel(dnotamConsumer, extBroker, "Consumes DNOTAM events", "AMQP 1.0 / mTLS")
    Rel(dnotamConsumer, extSM, "Registers and manages subscriptions", "REST / HTTPS / mTLS")
    Rel(dnotamConsumer, mongodb, "Persists events and subscriptions")
    Rel(dnotamConsumer, kafka, "Forwards domain events")

    Rel(ed254Consumer, extBroker, "Consumes arrival sequence events", "AMQP 1.0 / mTLS")
    Rel(ed254Consumer, extSM, "Registers and manages subscriptions", "REST / HTTPS / mTLS")
    Rel(ed254Consumer, mongodb, "Persists arrival events and subscriptions")
    Rel(ed254Consumer, kafka, "Forwards arrival events")

    Rel(dnotamProvider, extBroker, "Publishes DNOTAM events to subscriber queues", "AMQP 1.0 / mTLS")
    Rel(dnotamProvider, postgres, "Persists subscriptions and events")
    Rel(dnotamProvider, kafka, "Consumes incoming DNOTAM events")

    Rel(ed254Provider, extBroker, "Publishes arrival sequence events to subscriber queues", "AMQP 1.0 / mTLS")
    Rel(ed254Provider, postgres, "Persists subscriptions and events")
    Rel(ed254Provider, kafka, "Consumes incoming arrival sequence events")
```

---

## 3. swim-framework — Module Hierarchy

```mermaid
graph LR
    classDef core fill:#FED7AA,stroke:#C2410C,color:#431407
    classDef consumer fill:#BFDBFE,stroke:#1D4ED8,color:#1e3a5f
    classDef provider fill:#BBF7D0,stroke:#15803D,color:#14532d
    classDef mongodb fill:#E9D5FF,stroke:#7C3AED,color:#3b0764
    classDef svc fill:#F8FAFC,stroke:#94A3B8,color:#334155

    CORE["swim-framework-core\nSPIs · DTOs · ports · cluster"]:::core
    FCONS["swim-framework-consumer\nAMQP receive · subscription lifecycle\nheartbeat · inbox/outbox · reconciliation"]:::consumer
    FPROV["swim-framework-provider\nAMQP publish · subscription expiry\nheartbeat gen · failed delivery recovery"]:::provider
    FMONGO["swim-framework-persistence-mongodb\nMongoDB base repositories"]:::mongodb

    FCONS --> CORE
    FPROV --> CORE
    FMONGO --> CORE

    DC["swim-dnotam-consumer"]:::svc
    DP["swim-dnotam-provider"]:::svc
    EC["swim-ed254-consumer"]:::svc
    EP["swim-ed254-provider"]:::svc

    DC --> FCONS
    DC --> FMONGO
    EC --> FCONS
    EC --> FMONGO
    DP --> FPROV
    EP --> FPROV
```

---

## 4. Maven Dependency Graph

```mermaid
graph LR
    classDef model fill:#E2E8F0,stroke:#64748B,color:#1e293b
    classDef fw fill:#FED7AA,stroke:#C2410C,color:#431407
    classDef svc fill:#BFDBFE,stroke:#1D4ED8,color:#1e3a5f
    classDef ext fill:#FEF08A,stroke:#A16207,color:#713f12

    AIXM["swim-aixm-model"]:::model
    FIXM["swim-fixm-model-ed254"]:::model
    CORE["swim-framework-core"]:::fw
    FCONS["swim-framework-consumer"]:::fw
    FPROV["swim-framework-provider"]:::fw
    FMONGO["swim-framework-persistence-mongodb"]:::fw
    EXT["swim-extensions\ninbox / outbox Kafka adapters"]:::ext
    DC["swim-dnotam-consumer"]:::svc
    DP["swim-dnotam-provider"]:::svc
    EC["swim-ed254-consumer"]:::svc
    EP["swim-ed254-provider"]:::svc

    FCONS --> CORE
    FPROV --> CORE
    FMONGO --> CORE

    DC --> FCONS
    DC --> FMONGO
    DC --> EXT
    DC --> AIXM
    DP --> FPROV
    DP --> AIXM
    EC --> FCONS
    EC --> FMONGO
    EC --> EXT
    EC --> FIXM
    EP --> FPROV
    EP --> FIXM
```

---

## Architecture Principles

| Principle | Applied |
|-----------|---------|
| **Hexagonal Architecture** | Domain and ports are isolated from infrastructure. Adapters implement ports; never the reverse. |
| **Template Method** | Framework abstract classes define the algorithm skeleton. Services implement only the domain-specific steps. |
| **Consumer ↔ Provider isolation** | A consumer never connects to the provider of the same module. During development, consumers connect to consumer-validators (dedicated test harnesses). |
| **At-least-once delivery** | AMQP message handlers are idempotent. Events are acknowledged only after successful persistence. |
| **mTLS everywhere** | All service-to-service communication uses mutual TLS with X.509 certificates injected as Kubernetes Secrets. |
