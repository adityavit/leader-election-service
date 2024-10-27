# Add this at the beginning of the Makefile
GO_VERSION := $(shell go version | cut -d " " -f 3 | cut -c 3-)
GO_MAJOR_VERSION := $(shell echo $(GO_VERSION) | cut -d. -f1)
GO_MINOR_VERSION := $(shell echo $(GO_VERSION) | cut -d. -f2)

# Variables
BINARY_NAME=leader-election-service
\
DOCKER_TAG=latest
HELM_RELEASE_NAME=leader-election-service
HELM_CHART_DIR=./leader-election-service

# Go related variables
GOBASE=$(shell pwd)
GOBIN=$(GOBASE)/bin

# Build the binary
build: check-go-version
	@echo "Building $(BINARY_NAME)..."
	@go build -o $(GOBIN)/$(BINARY_NAME) .

# Run the binary
run: build
	@echo "Running $(BINARY_NAME)..."
	@$(GOBIN)/$(BINARY_NAME)

# Clean the binary
clean:
	@echo "Cleaning..."
	@rm -rf $(GOBIN)

# Delete the Docker image if it exists
docker-delete:
	@echo "Deleting Docker image if it exists..."
	@docker rmi $(DOCKER_IMAGE):$(DOCKER_TAG) 2>/dev/null || true

# Build the Docker image (now depends on docker-delete)
docker-build: docker-delete
	@echo "Building Docker image..."
	@docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

# Push the Docker image
docker-push:
	@echo "Pushing Docker image..."
	@docker push $(DOCKER_IMAGE):$(DOCKER_TAG)

# Run tests
test:
	@echo "Running tests..."
	@go test ./...

# Format the code
fmt:
	@echo "Formatting code..."
	@go fmt ./...

# Run golangci-lint
lint:
	@echo "Running linter..."
	@golangci-lint run

# Download dependencies
deps:
	@echo "Downloading dependencies..."
	@go mod download

# Update dependencies
deps-update:
	@echo "Updating dependencies..."
	@go get -u ./...
	@go mod tidy

# Add this check before the build target
check-go-version:
	@if [ $(GO_MAJOR_VERSION) -lt 1 ] || ([ $(GO_MAJOR_VERSION) -eq 1 ] && [ $(GO_MINOR_VERSION) -lt 20 ]); then \
		echo "Requires Go version 1.20 or higher (found $(GO_VERSION))"; \
		exit 1; \
	fi

# Helm related targets
helm-lint:
	@echo "Linting Helm chart..."
	@helm lint $(HELM_CHART_DIR)

helm-template:
	@echo "Generating Helm template..."
	@helm template $(HELM_RELEASE_NAME) $(HELM_CHART_DIR) --set image.repository=$(DOCKER_IMAGE) --set image.tag=$(DOCKER_TAG)

helm-uninstall:
	@echo "Uninstalling Helm chart..."
	@helm uninstall $(HELM_RELEASE_NAME)

helm-list:
	@echo "Listing Helm releases..."
	@helm list

helm-history:
	@echo "Showing Helm release history..."
	@helm history $(HELM_RELEASE_NAME)

helm-rollback:
	@echo "Rolling back to previous release..."
	@helm rollback $(HELM_RELEASE_NAME)

# Add these variables at the top of your Makefile
DOCKER_IMAGE=leader-election-service
DOCKER_TAG=latest
KIND_CLUSTER_NAME=kind

# Build and load image into Kind
build-and-load: docker-delete docker-build kind-load

# Load the Docker image into Kind cluster
kind-load:
	@echo "Loading Docker image into Kind cluster..."
	@kind load docker-image $(DOCKER_IMAGE):$(DOCKER_TAG) --name $(KIND_CLUSTER_NAME)

# Update the helm-install target
helm-install: build-and-load
	@echo "Installing Helm chart..."
	@helm install $(HELM_RELEASE_NAME) $(HELM_CHART_DIR) --set image.repository=$(DOCKER_IMAGE) --set image.tag=$(DOCKER_TAG)

# Update the helm-upgrade target
helm-upgrade: build-and-load
	@echo "Upgrading Helm chart..."
	@helm upgrade $(HELM_RELEASE_NAME) $(HELM_CHART_DIR) --set image.repository=$(DOCKER_IMAGE) --set image.tag=$(DOCKER_TAG)

# Add this to the .PHONY list
.PHONY: build run clean docker-delete docker-build docker-push test fmt lint deps deps-update helm-lint helm-template helm-install helm-upgrade helm-uninstall helm-list helm-history helm-rollback kind-load build-and-load

# Port forward to the leader pod
port-forward:
	@echo "Setting up port forward to the leader pod..."
	@kubectl get pods -l app.kubernetes.io/name=$(HELM_RELEASE_NAME) -o name | \
	while read pod; do \
		if [ "$$(kubectl exec $${pod} -- wget -qO- http://localhost:8080/leader)" = "true" ]; then \
			kubectl port-forward $${pod} 8080:8080; \
			break; \
		fi; \
	done

# Add port-forward to the .PHONY list
.PHONY: build run clean docker-delete docker-build docker-push test fmt lint deps deps-update helm-lint helm-template helm-install helm-upgrade helm-uninstall helm-list helm-history helm-rollback kind-load build-and-load port-forward
