.PHONY: help start-kafka stop-kafka create-topic

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

start: ## Start Kafka and Zookeeper using Docker Compose
	docker compose up -d
	@echo "Waiting for Kafka to be ready..."
	@sleep 10
	@echo "Kafka is ready!"

stop: ## Stop Kafka and Zookeeper
	docker compose down

create-topic: ## Create the user-events topic
	docker exec kafka kafka-topics --create \
		--topic user-events \
		--bootstrap-server localhost:9092 \
		--replication-factor 1 \
		--partitions 1

list-topics: ## List all Kafka topics
	docker exec kafka kafka-topics --list --bootstrap-server localhost:9092

test-connection: ## Test Kafka connection
	docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092
