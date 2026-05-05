# swim-developer

**swim-developer** is an open-source reference architecture for SWIM services on Red Hat OpenShift.

It delivers a reusable framework, four production-validated services (DNOTAM and ED-254, both Consumer and Provider), compliance validators, data models, and deployment tooling — everything required to implement EU Regulation 2021/116 (Common Project 1) without starting from scratch.

This is an open-source contribution to the SWIM development community: shared infrastructure, tested against real standards, so that each team can focus on their domain rather than on protocol mechanics.

This project implements the [SWIM Technical Infrastructure](https://www.eurocontrol.int/concept/system-wide-information-management) standards defined by EUROCONTROL and ICAO, targeting **EU Regulation 2021/116, Common Project 1 (CP1)**. It includes a reusable framework, four working services (DNOTAM and ED-254), data models, and compliance validators, all built on [Quarkus](https://quarkus.io/) and designed to run on [Red Hat OpenShift](https://www.redhat.com/en/technologies/cloud-computing/openshift).

The services here are starting points — tested, validated, and ready to be extended. The framework is an invitation for the community to build new SWIM services on a shared, proven foundation.

---

## What This Project Provides

**A framework**, not a monolith. swim-developer is organized around a central idea: the infrastructure that every SWIM service needs (subscription lifecycle, AMQP messaging, heartbeat monitoring, self-healing) should be written once and shared, so that each new service only implements what is unique to its domain.

**Four working services** that demonstrate both sides of the SWIM exchange, Consumer and Provider, for two real-world use cases:

- **DNOTAM** (Digital NOTAM), aeronautical information using AIXM 5.1.1
- **ED-254** (Arrival Sequence / AMAN), arrival management using FIXM 4.3

**Compliance validators** that exercise the full AMQP subscription lifecycle against running instances, verifying SPEC-170 conformance.

**Data models** (AIXM 5.1.1, FIXM 4.3) generated from the official XSD schemas, ready to use.

---

## Standards

This project implements the following standards. Each one shaped concrete design decisions — not aspirational references, but constraints the code was built to satisfy.

| Standard | What it governs |
|----------|----------------|
| [EUROCONTROL SPEC-170](https://www.eurocontrol.int/publication/spec-170-swim-ti-yellow-profile) | SWIM-TI Yellow Profile: AMQP 1.0 messaging, Subscription Manager API, heartbeat contracts, subscription lifecycle |
| [EUROCAE ED-254](https://www.eurocae.net/) | Arrival Sequence Service: subscription/notification model for downstream ATSU coordination |
| [AIXM 5.1.1](https://aixm.aero/) | Aeronautical Information Exchange Model: DNOTAM events (runway closures, obstacles, navaid status) |
| [FIXM 4.3](https://fixm.aero/) | Flight Information Exchange Model: ED-254 arrival sequence messages |
| EU Regulation 2021/116 | Common Project 1 (CP1): the regulatory mandate for SWIM adoption |
| AMQP 1.0 / TLS 1.3 | Transport and security: mutual TLS with X.509 certificates, SASL authentication (SWIM-TIYP-0008) |

---

## Architecture

swim-developer follows **Hexagonal Architecture** (Ports and Adapters). The domain core defines contracts through SPIs; infrastructure adapters handle protocol-specific concerns without leaking into domain logic. This separation is what makes the framework reusable, a new SWIM service implements a small set of SPIs, and the framework provides everything else.

```
                    +----------------------------------+
                    |          Domain Core             |
                    |                                  |
                    |   SPIs (Ports):                  |
                    |   . SwimEventExtractor<T>        |
   Driving          |   . SwimOutboxRouter             |         Driven
   Adapters ------> |   . SwimPayloadValidator         | <------ Adapters
   (REST API,       |   . SwimSubscription<E>          |         (AMQP, Kafka,
    Scheduler)      |   . SwimIngressHandler           |          MongoDB, PostgreSQL)
                    |                                  |
                    +----------------------------------+

   Dependency Rule: Adapters depend on Core. Core depends on nothing.
```

The framework was validated by building the second service family (ED-254) entirely on framework SPIs. No infrastructure code was copied, only domain-specific implementations were written. This confirmed that ~55% of what would otherwise be duplicated across services is handled by the framework.

For C4 diagrams, sequence diagrams, and architecture decision records, see the [swim-developer portal](https://swim-developer.github.io/architecture.html).

---

## Modules

### Framework

| Module | What it does |
|--------|-------------|
| **swim-framework-core** | SPIs, domain records, health checks, security, validation, messaging patterns |
| **swim-framework-consumer** | Subscription lifecycle, multi-provider AMQP connections, inbox/outbox, heartbeat tracking, auto-renewal, self-healing |
| **swim-framework-provider** | AMQP publishing, per-subscription heartbeat generation, subscription expiry and purge |
| **swim-framework-persistence-mongodb** | MongoDB Panache adapter for consumer persistence |
| **swim-framework-leader-kubernetes** | Leader election via Kubernetes API |
| **swim-framework-leader-infinispan** | Leader election via Infinispan distributed cache |

### Services

| Service | Role | What it does |
|---------|------|-------------|
| **swim-dnotam-provider** | Provider (AISP) | Subscription Manager REST API; publishes DNOTAM events (AIXM 5.1.1) via AMQP; PostgreSQL |
| **swim-dnotam-consumer** | Consumer (ANSP) | Subscribes to external providers; processes AIXM messages; persists to MongoDB; routes to Kafka by business intent |
| **swim-ed254-provider** | Provider (AISP) | Subscription Manager REST API; publishes arrival sequence events (FIXM 4.3) via AMQP; PostgreSQL |
| **swim-ed254-consumer** | Consumer (ANSP) | Subscribes to upstream AMAN providers; processes arrival sequence updates; persists to MongoDB |

### Data Models

| Module | What it does |
|--------|-------------|
| **aixm-model** | JAXB bindings for AIXM 5.1.1 and GML 3.2.1, generated from XSD |
| **fixm-ed254-model** | JAXB bindings for FIXM 4.3 and ED-254 extension, generated from XSD |

### Extensions

| Module | What it does |
|--------|-------------|
| **swim-outbox-kafka-dnotam** | Routes DNOTAM outbox events to Kafka topics by scenario code |
| **swim-outbox-kafka-ed254** | Routes ED-254 arrival sequence events to Kafka |
| **swim-inbox-kafka-dnotam** | Ingests DNOTAM events from Kafka into the provider pipeline |
| **swim-inbox-kafka-ed254** | Ingests ED-254 events from Kafka into the provider pipeline |

### Archetypes

| Module | What it does |
|--------|-------------|
| **swim-consumer-archetype** | Generates a complete consumer service project (38 classes, MongoDB, Kafka, hexagonal architecture) |
| **swim-provider-archetype** | Generates a complete provider service project (53 classes, PostgreSQL, AMQP, hexagonal architecture) |

### Validators

Test harnesses that exercise the full AMQP subscription lifecycle against real provider and consumer instances.

| Module | What it does |
|--------|-------------|
| **swim-validator-core** | Shared infrastructure: fault injection, notifications, filters |
| **swim-validator-consumer** | Consumer-side validation base |
| **swim-validator-provider** | Provider-side validation base |
| **swim-dnotam-consumer-validator** | DNOTAM consumer compliance validation |
| **swim-dnotam-provider-validator** | DNOTAM provider compliance validation |
| **swim-ed254-consumer-validator** | ED-254 consumer compliance validation |
| **swim-ed254-provider-validator** | ED-254 provider compliance validation |

---

## Project Structure

```
swim-developer/
|-- pom.xml                                  Master parent POM
|
|-- swim-framework/                          Reusable framework (6 modules)
|   |-- swim-framework-core/
|   |-- swim-framework-consumer/
|   |-- swim-framework-provider/
|   |-- swim-framework-persistence-mongodb/
|   |-- swim-framework-leader-kubernetes/
|   +-- swim-framework-leader-infinispan/
|
|-- swim-dnotam-provider/                    DNOTAM Provider service
|-- swim-dnotam-consumer/                    DNOTAM Consumer service
|-- swim-ed254-provider/                     ED-254 Provider service
|-- swim-ed254-consumer/                     ED-254 Consumer service
|
|-- aixm-model/                              AIXM 5.1.1 data model
|-- fixm-ed254-model/                        FIXM 4.3 / ED-254 data model
|
|-- swim-extensions/                         Kafka inbox/outbox adapters (4 modules)
|   |-- swim-outbox-kafka-dnotam/
|   |-- swim-outbox-kafka-ed254/
|   |-- swim-inbox-kafka-dnotam/
|   +-- swim-inbox-kafka-ed254/
|
|-- swim-consumer-archetype/                 Maven archetype for new consumer services
|-- swim-provider-archetype/                 Maven archetype for new provider services
|
+-- swim-validators/                         Compliance validators (7 modules)
    |-- swim-validator-core/
    |-- swim-validator-consumer/
    |-- swim-validator-provider/
    |-- swim-dnotam-consumer-validator/
    |-- swim-dnotam-provider-validator/
    |-- swim-ed254-consumer-validator/
    +-- swim-ed254-provider-validator/
```

25 Maven modules, 4 deployable services, 6 framework libraries, 4 extension adapters, 2 archetypes, 7 validators, 2 data models.

---

## Technology

| Component | Technology |
|-----------|-----------|
| Runtime | Quarkus 3.34.6, Java 21 |
| Messaging | ActiveMQ Artemis: AMQP 1.0 (SPEC-170 mandated) |
| Streaming | Apache Kafka (Strimzi on OpenShift) |
| Provider persistence | PostgreSQL |
| Consumer persistence | MongoDB (Panache) |
| Security | Mutual TLS (X.509), JWT/OIDC (Keycloak), TLS 1.3 |
| Observability | OpenTelemetry, Prometheus, Grafana |
| Containers | Podman: multi-arch manifests (linux/amd64 + linux/arm64) |
| Platform | Red Hat OpenShift 4.x |
| CI/CD | Tekton Pipelines |
| Code quality | SonarQube, OWASP Dependency-Check, JaCoCo |

---

## Consumer and Provider: Two Separate Products

**Consumer and Provider are separate products for different customers.**

A Provider (AISP role) publishes aviation data to the SWIM network. A Consumer (ANSP role) subscribes to external providers to receive that data. They exist in the same repository because they share the same framework, but they serve different organizations with different operational needs.

An ANSP's Consumer connects to *external* Providers, EUROCONTROL, Austro Control, LFV, and others. It never connects to its own Provider. This is not a technical limitation; it reflects the real-world architecture of SWIM, where data flows between organizations, not within them.

The framework supports **multi-provider connections**: a single Consumer can maintain simultaneous AMQP subscriptions to multiple external Providers.

---

## GET STARTED

Each project is an independent Git repository. Clone only what you need.

### Repository map

| Repository | What you get | Who needs it |
|-----------|-------------|--------------|
| [swim-developer-framework](https://github.com/swim-developer/swim-developer-framework) | Core libraries (SPIs, consumer, provider, persistence) | Framework contributors, service builders |
| [swim-digital-notam-consumer](https://github.com/swim-developer/swim-digital-notam-consumer) | DNOTAM Consumer service | ANSPs consuming Digital NOTAMs |
| [swim-digital-notam-provider](https://github.com/swim-developer/swim-digital-notam-provider) | DNOTAM Provider service | AISPs publishing Digital NOTAMs |
| [swim-ed254-consumer](https://github.com/swim-developer/swim-ed254-consumer) | ED-254 Arrival Sequence Consumer | ANSPs receiving E-AMAN data |
| [swim-ed254-provider](https://github.com/swim-developer/swim-ed254-provider) | ED-254 Arrival Sequence Provider | AISPs publishing E-AMAN data |
| [swim-developer-validators](https://github.com/swim-developer/swim-developer-validators) | Compliance validators (consumer + provider) | Service developers, conformance testing |
| [swim-developer-extensions](https://github.com/swim-developer/swim-developer-extensions) | Kafka inbox/outbox adapters | Service integrators |
| [aixm-model](https://github.com/swim-developer/aixm-model) | AIXM 5.1.1 JAXB bindings | Anyone parsing DNOTAM XML |
| [fixm-model-ed254](https://github.com/swim-developer/fixm-model-ed254) | FIXM 4.3 + ED-254 JAXB bindings | Anyone parsing ED-254 XML |
| [swim-developer-operator](https://github.com/swim-developer/swim-developer-operator) | Kubernetes/OpenShift Operator | Platform engineers |
| [swim-developer-add-ons](https://github.com/swim-developer/swim-developer-add-ons) | Artemis ACK plugin, Keycloak SPI | Platform engineers |
| [swim-developer-tools](https://github.com/swim-developer/swim-developer-tools) | Cert generation, full-stack compose, pipelines | All developers |

### "I want to consume DNOTAM events"

```bash
git clone https://github.com/swim-developer/swim-digital-notam-consumer
cd swim-digital-notam-consumer
podman compose up -d
./mvnw quarkus:dev
```

The `compose.yml` starts a fake SWIM provider (validator), MongoDB, and Kafka. Alternatively, [Quarkus Dev Services](https://quarkus.io/guides/dev-services) can provision the required infrastructure automatically during `quarkus:dev`. See the project README for the full configuration reference.

### "I want to run a DNOTAM provider"

```bash
git clone https://github.com/swim-developer/swim-developer-tools  # for cert generation
git clone https://github.com/swim-developer/swim-digital-notam-provider
cd swim-digital-notam-provider
# Generate certs first, see README
podman compose up -d
./mvnw quarkus:dev
```

### "I want to build a new SWIM service"

The fastest way to create a new service is using the Maven archetypes. They generate a complete project with hexagonal architecture, all mechanical classes pre-configured, and only domain-specific classes left to implement.

**Consumer** (receives data from external providers):

```bash
# 1. Install the parent POM
git clone https://github.com/swim-developer/swim-developer
cd swim-developer
./mvnw clean install
cd ..

# 2. Install the framework
git clone https://github.com/swim-developer/swim-developer-framework
cd swim-developer-framework
./mvnw clean install -DskipTests
cd ..

# 3. Install the consumer archetype
git clone https://github.com/swim-developer/swim-consumer-archetype
cd swim-consumer-archetype
mvn clean install
cd ..

# 4. Generate the new consumer
mvn archetype:generate \
  -DarchetypeGroupId=com.github.swim-developer \
  -DarchetypeArtifactId=swim-consumer-archetype \
  -DarchetypeVersion=1.0.0-SNAPSHOT \
  -DgroupId=com.github.swim_developer.myservice.consumer \
  -DartifactId=swim-myservice-consumer \
  -Dversion=1.0.0-SNAPSHOT \
  -DserviceName=myservice \
  -DserviceDisplayName="My Service" \
  -DservicePrefix=MyService \
  -DdataModel=AIXM \
  -DcollectionPrefix=myservice \
  -DinteractiveMode=false

# 5. Post-generation
cd swim-myservice-consumer
chmod +x mvnw
./mvnw compile
```

This generates 38 Java classes. Only 10 require domain-specific implementation (event extraction, validation, filtering). The remaining 28 work out of the box. See the [consumer archetype README](https://github.com/swim-developer/swim-consumer-archetype) for parameter descriptions and the full list of generated classes.

After the project compiles:

1. Add your data model dependency to `pom.xml` (e.g., `aixm-model` or `fixm-ed254-model`)
2. Add your outbox router extension (e.g., `swim-outbox-kafka-dnotam`)
3. Implement the 10 domain-specific classes (marked with `// TODO`)
4. Create a `compose.yml` for local infrastructure (MongoDB, Kafka, Artemis, Consumer Validator), or use [Quarkus Dev Services](https://quarkus.io/guides/dev-services) to provision them automatically
5. Use [swim-digital-notam-consumer](https://github.com/swim-developer/swim-digital-notam-consumer) as a reference implementation

**Provider** (publishes data to external consumers):

```bash
# 1. Install the parent POM (skip if already done above)
git clone https://github.com/swim-developer/swim-developer
cd swim-developer
./mvnw clean install
cd ..

# 2. Install the framework (skip if already done above)
git clone https://github.com/swim-developer/swim-developer-framework
cd swim-developer-framework
./mvnw clean install -DskipTests
cd ..

# 3. Install the provider archetype
git clone https://github.com/swim-developer/swim-provider-archetype
cd swim-provider-archetype
mvn clean install
cd ..

# 4. Generate the new provider
mvn archetype:generate \
  -DarchetypeGroupId=com.github.swim-developer \
  -DarchetypeArtifactId=swim-provider-archetype \
  -DarchetypeVersion=1.0.0-SNAPSHOT \
  -DgroupId=com.github.swim_developer.myservice.provider \
  -DartifactId=swim-myservice-provider \
  -Dversion=1.0.0-SNAPSHOT \
  -DserviceName=myservice \
  -DserviceDisplayName="My Service" \
  -DservicePrefix=MyService \
  -DdataModel=AIXM \
  -DtablePrefix=myservice \
  -DqueuePrefix=MYSERVICE \
  -DtopicName=MyServiceTopic \
  -DinteractiveMode=false

# 5. Post-generation
cd swim-myservice-provider
chmod +x mvnw
./mvnw compile
```

This generates 53 Java classes. Only 10 require domain-specific implementation. The remaining 43 work out of the box. See the [provider archetype README](https://github.com/swim-developer/swim-provider-archetype) for parameter descriptions and the full list of generated classes.

After the project compiles:

1. Add your data model dependency to `pom.xml` (e.g., `aixm-model` or `fixm-ed254-model`)
2. Add your ingress handler extension (e.g., `swim-inbox-kafka-dnotam`)
3. Implement the 10 domain-specific classes (marked with `// TODO`)
4. Create a `compose.yml` for local infrastructure (PostgreSQL, Kafka, Artemis, Provider Validator), or use [Quarkus Dev Services](https://quarkus.io/guides/dev-services) to provision them automatically
5. Use [swim-digital-notam-provider](https://github.com/swim-developer/swim-digital-notam-provider) as a reference implementation

See the archetype READMEs for the full list of parameters and generated classes.

### "I want to test a full stack locally"

Clone `swim-developer-tools`, it contains a multi-service `compose.yml` that starts all services together, along with the certificate generation scripts.

---

## Building

This repository is the Maven parent POM. Install it once so other projects resolve the parent artifact:

```bash
make install
# equivalent to: ./mvnw clean install -DskipTests
```

Each service or library repository is self-contained with its own `Makefile`. Clone the repo you need and run:

```bash
make help      # list all available targets
make build     # compile + package (skips tests)
make test      # unit + integration tests
make jvm       # build JVM multi-arch image + push (services only)
```

---

## Deployment

Services are deployed to OpenShift using Helm. Each service includes its own chart under `src/main/helm/`.

```bash
# Deploy to CRC (local OpenShift)
make deploy-dnotam-consumer

# Deploy to another environment
make deploy-dnotam-consumer ENV=prod
```

### Infrastructure

The services depend on supporting infrastructure deployed via the `swim-infra` Helm chart:

- ActiveMQ Artemis, AMQP 1.0 broker (separate instances for Provider and Consumer)
- Keycloak, OIDC/JWT authentication
- Strimzi/Kafka, event streaming
- MongoDB, Consumer persistence
- PostgreSQL, Provider persistence

---

## Code Quality

```bash
# SonarQube analysis
make sonar PROJECT=swim-dnotam-consumer
make sonar-all

# OWASP vulnerability scan (fails on CVSS >= 8)
make owasp PROJECT=swim-dnotam-consumer
make owasp-all
```

JaCoCo coverage reports are generated automatically during `mvn verify`.

---

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](https://swim-developer.github.io/architecture.html) | C4 diagrams, hexagonal architecture, message flows, sequence diagrams, architecture decision records |
| [Makefile](Makefile) | Build, deploy, analysis, and infrastructure targets |

---

## Related

| Project | Description |
|---------|-------------|
| [swim-example-apps](https://github.com/swim-developer/swim-example-apps) | 4 example applications (React 19 + PatternFly 6 + Quarkus) demonstrating Consumer and Provider integration |
| [swim-deploy-openshift-local](https://github.com/swim-developer/swim-deploy-openshift-local) | Full-stack OpenShift local deployment guide (CRC), Helm charts, Tekton pipelines |

---

## Contributing

This project is an open invitation to the SWIM development community. Whether you are an ANSP evaluating SWIM adoption, a system integrator building SWIM services, or a developer interested in aviation data exchange, contributions, feedback, and collaboration are welcome.

The framework was designed to be extended. If you are building a new SWIM service, the five SPIs (`SwimEventExtractor`, `SwimOutboxRouter`, `SwimPayloadValidator`, `SwimSubscription`, `SwimIngressHandler`) define the contracts your service needs to implement. The framework handles the rest.

---

## License

Licensed under the [Apache License 2.0](LICENSE).

---

Marcelo Sales
