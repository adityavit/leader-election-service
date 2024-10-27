# Leader Election Service

This project demonstrates a Kubernetes-based leader election mechanism using Go. It deploys multiple pods, but only one pod serves as the leader at any given time. The leader pod runs a HTTP server, while the other pods stand by ready to take over if the leader fails.

## Prerequisites

- Go 1.20 or later
- Docker
- Kind (Kubernetes in Docker)
- kubectl
- Helm

## Setup

1. Clone the repository:   ```
   git clone https://github.com/yourusername/leader-election-service.git
   cd leader-election-service   ```

2. Install dependencies:   ```
   go mod download   ```

3. Create a Kind cluster (if you haven't already):   ```
   kind create cluster   ```

## Building and Deploying

1. Build the Docker image and load it into Kind:   ```
   make build-and-load   ```

2. Install the Helm chart:   ```
   make helm-install   ```

## Testing the Service

1. Set up port forwarding to the leader pod:   ```
   make port-forward   ```

2. In a new terminal, send a request to the service:   ```
   curl http://localhost:8080   ```
   You should see a response like "Hello from the leader pod!"

3. To check which pod is the leader, you can use:   ```
   kubectl get pods   ```
   And then for each pod:   ```
   kubectl exec <pod-name> -- wget -qO- http://localhost:8080/leader   ```
   The pod that returns "true" is the current leader.

## Cleaning Up

To uninstall the Helm release:
```
make helm-uninstall
```
