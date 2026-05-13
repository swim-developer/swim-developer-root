# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

This is `swim-developer-root`, the **Maven parent POM** for the swim-developer ecosystem. It contains no application code — only the parent POM, full-stack compose files, and observability configuration. All services, frameworks, and libraries live in sibling repositories that inherit from this parent.

Install the parent POM once so sibling projects resolve the parent artifact:

```bash
make install
# equivalent to: ./mvnw clean install -DskipTests
```

## Multi-Repository Ecosystem

Each module is its own Git repo. Sibling repos must be cloned into the **same parent directory** for the compose files to work (they use `context: ..` to reference siblings).

Key sibling repos: `swim-developer-framework`, `swim-digital-notam-consumer`, `swim-digital-notam-provider`, `swim-ed254-consumer`, `swim-ed254-provider`, `swim-developer-validators`, `swim-developer-extensions`, `swim-developer-tools`, `swim-developer-add-ons`.

## Full-Stack Local Development

```bash
# Prerequisites: sibling repos cloned, certs generated, ACK plugin built
podman compose up -d                              # core infra (no observability)
podman compose -f compose-observability.yml up -d  # core infra + Grafana/Prometheus/Tempo
```

External volumes `keycloak-certs` and `keycloak-providers` must exist before starting (created by `swim-developer-tools` cert generation scripts).

### Local Service Ports

| Service | Port |
|---------|------|
| Provider PostgreSQL | 5432 |
| Provider Artemis (AMQP/console) | 5671, 5672, 8161 |
| DNOTAM Consumer MongoDB | 27017 |
| ED-254 Consumer MongoDB | 27018 |
| Kafka | 9092 |
| AKHQ (Kafka UI) | 9980 |
| Keycloak | 8543 (HTTPS) |
| Mongo Express (DNOTAM) | 9081 |
| Mongo Express (ED-254) | 9082 |
| Adminer (validator DBs) | 9007 |
| Grafana | 3000 |
| Prometheus | 9090 |
| Tempo (OTLP gRPC/HTTP) | 4317, 4318 |

## Architecture

**Hexagonal Architecture** (Ports and Adapters). Domain core defines contracts through SPIs; infrastructure adapters implement them. New services implement five SPIs: `SwimEventExtractor`, `SwimOutboxRouter`, `SwimPayloadValidator`, `SwimSubscription`, `SwimIngressHandler`.

**Consumer and Provider are separate products for different organizations.** A Provider (AISP role) publishes aviation data. A Consumer (ANSP role) subscribes to external providers. They never connect to each other within the same organization — this reflects real-world SWIM architecture.

## Code Standards

- **Integration tests**: `mvn verify -DskipITs=false`, run sequentially across projects (port conflicts with Testcontainers)
- **OpenShift resources**: physical YAML files only, no inline `oc create`

## Technology Stack

Quarkus 3.34.6, Java 21, AMQP 1.0 (ActiveMQ Artemis), Apache Kafka, PostgreSQL (Provider), MongoDB with Panache (Consumer), mTLS with X.509, JWT/OIDC (Keycloak), OpenTelemetry, Podman for containers, Red Hat OpenShift 4.x.

## Standards Compliance

EUROCONTROL SPEC-170 (SWIM-TI Yellow Profile), EUROCAE ED-254, AIXM 5.1.1, FIXM 4.3, EU Regulation 2021/116 (CP1), AMQP 1.0 / TLS 1.3.
