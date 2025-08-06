# Docker Compose Orchestration

This directory contains the full Docker Compose setup for orchestrating the Distributed Microservice Application. It includes the service definitions, configurations for infrastructure like Kafka and Debezium, and a `Makefile` to simplify common operations.

## 🚀 Services Overview

The `docker-compose.yml` file defines the following services:

- **Infrastructure**:
    - `zookeeper`: Required for Kafka coordination.
    - `kafka`: The core message broker for asynchronous communication.
    - `kafka-ui`: A web-based UI to view and manage Kafka topics and messages.
    - `postgres`: The PostgreSQL database server.
    - `kafka-connect`: Runs the Debezium connector to capture changes from the `outbox` table.
    - `prometheus`: Scrapes and stores metrics from the services.
    - `grafana`: Visualizes metrics with pre-configured dashboards.
    - `nginx-lb`: An Nginx instance that acts as a gRPC and HTTP load balancer for Service A instances.

- **Application**:
    - `service-a-1`, `service-a-2`, `service-a-3`: Three instances of the Go-based calculation service.
    - `service-b`: A single instance of the Java-based aggregation service.

## 🛠️ Makefile Commands

A `Makefile` is provided to streamline common tasks. Here are some of the most important commands:

| Command                 | Description                                                              |
| ----------------------- | ------------------------------------------------------------------------ |
| `make help`             | Shows a list of all available commands.                                  |
| `make start`            | Starts all services in the background.                                   |
| `make stop`             | Stops and removes all containers.                                        |
| `make logs-all`         | Tails the logs for all application services (Service A instances & B).   |
| `make logs-service-a`   | Shows logs for all Service A instances.                                  |
| `make logs-service-b`   | Shows logs for the Service B instance.                                   |
| `make logs-kafka-connect`| Tails the logs for the Debezium/Kafka Connect container.                 |
| `make setup-debezium`   | Deploys the Debezium connector for the outbox table.                     |
| `make check-debezium`   | Checks the status of the Debezium connector.                             |
| `make test-workflow`    | Runs a complete end-to-end test to validate the Debezium data pipeline.  |
| `make fix-debezium`     | Runs a script to troubleshoot and fix common Debezium issues.            |
| `make clean-all`        | Cleans up all unused Docker resources (containers, networks, volumes).   |

## ⚙️ Configuration Files

- **`docker-compose.yml`**: The main file defining all the services, networks, and volumes.
- **`nginx.conf`**: The configuration for the Nginx load balancer, which routes both gRPC and HTTP traffic to the Service A instances.
- **`metrics-nginx.conf`**: **(Not currently used)** A configuration file for a separate Nginx instance intended to act as a metrics aggregator for the Service A instances. This would simplify the Prometheus configuration by providing a single endpoint for scraping.
- **`init-multiple-databases.sh`**: A script that runs on PostgreSQL startup to create the necessary databases (`outbox`, `outbox_write`, `outbox_read`) and tables for the application.
- **`postgres-config/postgresql.conf`**: Custom PostgreSQL configuration to enable logical replication, which is required for Debezium.
- **`kafka-connect/connectors/outbox-connector.json`**: The configuration for the Debezium PostgreSQL connector. It specifies the database to monitor, the tables to watch, and the Kafka topic to publish changes to.
- **`fix-debezium.sh`**: A utility script to help diagnose and resolve common issues with the Debezium connector setup.
