.PHONY: help start stop restart logs clean build test deploy-infra deploy-apps

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

start: ## Start all services locally
	docker-compose up -d
	@echo "Services started. Frontend: http://localhost:3001"

stop: ## Stop all services
	docker-compose down

restart: ## Restart all services
	docker-compose restart

logs: ## View logs for all services
	docker-compose logs -f

clean: ## Clean up docker resources
	docker-compose down -v
	docker system prune -f

build: ## Build all docker images
	docker-compose build

test-java: ## Run Java service tests
	cd services/java-service && mvn test

test-nodejs: ## Run Node.js service tests
	cd services/nodejs-service && npm test

deploy-infra: ## Deploy infrastructure with Terraform
	cd infrastructure/terraform && \
	terraform init && \
	terraform plan && \
	terraform apply

destroy-infra: ## Destroy infrastructure
	cd infrastructure/terraform && terraform destroy

kubectl-config: ## Configure kubectl for EKS
	aws eks update-kubeconfig --region us-east-1 --name microservices-platform-dev

deploy-apps: ## Deploy applications to EKS
	kubectl apply -f infrastructure/kubernetes/

local-dev-java: ## Run Java service locally
	cd services/java-service && mvn spring-boot:run

local-dev-nodejs: ## Run Node.js service locally
	cd services/nodejs-service && npm run dev

local-dev-react: ## Run React frontend locally
	cd frontend/react-app && npm start

ecr-login: ## Login to ECR
	aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(ECR_REGISTRY)
