# Requirements Document

## Introduction

This feature adds two Python FastAPI microservices — a **User Service** and an **Item Service** — to the existing OCI infrastructure lab. It also establishes a CI/CD pipeline (GitHub Actions) that builds multi-arch Docker images for ARM64 (targeting the Ampere A1 Flex VM), pushes them to a container registry, and deploys both services to the k3s single-node cluster using Helm or plain Kubernetes manifests. Services are exposed externally through the existing Traefik Ingress Controller on ports 80/443; NodePorts are not used.

## Glossary

- **User_Service**: A FastAPI application that manages user records (CRUD operations).
- **Item_Service**: A FastAPI application that manages item/product records (CRUD operations).
- **Pipeline**: The GitHub Actions CI/CD workflow responsible for building images and deploying to k3s.
- **Registry**: The container image registry (GitHub Container Registry — `ghcr.io`) where built images are pushed.
- **k3s_Cluster**: The single-node Kubernetes cluster running on the OCI Ampere A1 VM.
- **Traefik**: The Ingress Controller included with k3s, listening on ports 80 and 443.
- **Ingress**: A Kubernetes `Ingress` resource that routes external HTTP/HTTPS traffic via Traefik to a service.
- **Manifest**: Kubernetes YAML resource definitions (Deployment, Service, Ingress) for each microservice.
- **Kubeconfig**: The `~/.kube/config` file on the VM, used by `kubectl` to communicate with the k3s API over localhost.
- **SSH_Tunnel**: A local port-forward (`ssh -L 6443:localhost:6443`) that exposes the k3s API to the GitHub Actions runner via a bastion-style connection.
- **Health_Endpoint**: The `/health` HTTP GET endpoint each service exposes to report its readiness.
- **ARM64**: The `linux/arm64` CPU architecture of the Ampere A1 Flex VM.

---

## Requirements

### Requirement 1: User Service Application

**User Story:** As a developer, I want a FastAPI-based User Service with CRUD endpoints, so that user records can be created, retrieved, updated, and deleted through a REST API.

#### Acceptance Criteria

1. THE User_Service SHALL expose a `POST /users` endpoint that creates a new user record and returns the created record with an assigned unique identifier.
2. THE User_Service SHALL expose a `GET /users/{id}` endpoint that returns the user record matching the given identifier.
3. WHEN a `GET /users/{id}` request is made for a non-existent identifier, THE User_Service SHALL return an HTTP 404 response with a descriptive error message.
4. THE User_Service SHALL expose a `PUT /users/{id}` endpoint that updates the fields of an existing user record and returns the updated record.
5. THE User_Service SHALL expose a `DELETE /users/{id}` endpoint that removes the user record with the given identifier and returns an HTTP 204 response.
6. THE User_Service SHALL expose a `GET /health` endpoint that returns an HTTP 200 response with a JSON body indicating service status.
7. THE User_Service SHALL validate incoming request bodies using Pydantic models and return HTTP 422 with validation details when the payload is invalid.

---

### Requirement 2: Item Service Application

**User Story:** As a developer, I want a FastAPI-based Item Service with CRUD endpoints, so that item records can be created, retrieved, updated, and deleted through a REST API.

#### Acceptance Criteria

1. THE Item_Service SHALL expose a `POST /items` endpoint that creates a new item record and returns the created record with an assigned unique identifier.
2. THE Item_Service SHALL expose a `GET /items/{id}` endpoint that returns the item record matching the given identifier.
3. WHEN a `GET /items/{id}` request is made for a non-existent identifier, THE Item_Service SHALL return an HTTP 404 response with a descriptive error message.
4. THE Item_Service SHALL expose a `PUT /items/{id}` endpoint that updates the fields of an existing item record and returns the updated record.
5. THE Item_Service SHALL expose a `DELETE /items/{id}` endpoint that removes the item record with the given identifier and returns an HTTP 204 response.
6. THE Item_Service SHALL expose a `GET /health` endpoint that returns an HTTP 200 response with a JSON body indicating service status.
7. THE Item_Service SHALL validate incoming request bodies using Pydantic models and return HTTP 422 with validation details when the payload is invalid.

---

### Requirement 3: Docker Image Build for ARM64

**User Story:** As a platform engineer, I want both services built as ARM64-compatible Docker images, so that they run natively on the Ampere A1 Flex VM without emulation overhead.

#### Acceptance Criteria

1. THE Pipeline SHALL build a Docker image for the User_Service targeting the `linux/arm64` platform.
2. THE Pipeline SHALL build a Docker image for the Item_Service targeting the `linux/arm64` platform.
3. THE Pipeline SHALL tag each image with both the Git commit SHA and the `latest` tag.
4. WHEN the build step for either service fails, THE Pipeline SHALL stop execution and report the failure without proceeding to push or deploy.
5. THE Pipeline SHALL use multi-stage Docker builds to produce minimal production images without development dependencies.

---

### Requirement 4: Image Push to Container Registry

**User Story:** As a platform engineer, I want built images pushed to a container registry, so that the k3s cluster can pull them during deployment.

#### Acceptance Criteria

1. WHEN a build succeeds, THE Pipeline SHALL push the built image to the Registry (`ghcr.io`) under the repository owner's namespace.
2. THE Pipeline SHALL authenticate to the Registry using a GitHub Actions secret containing a registry token with write access.
3. WHEN the push step fails, THE Pipeline SHALL stop execution and report the failure without proceeding to deploy.
4. THE Pipeline SHALL push images only on commits to the `main` branch, not on pull requests.

---

### Requirement 5: CI/CD Pipeline Trigger and Structure

**User Story:** As a developer, I want the pipeline to run automatically on relevant events, so that code changes are built and deployed without manual intervention.

#### Acceptance Criteria

1. THE Pipeline SHALL trigger automatically on every push to the `main` branch.
2. THE Pipeline SHALL trigger automatically when a pull request targets the `main` branch, running build and test steps only (no push or deploy).
3. THE Pipeline SHALL execute steps in the following order: lint/test → build → push → deploy.
4. WHEN any step fails, THE Pipeline SHALL not proceed to subsequent steps.
5. THE Pipeline SHALL run lint and unit tests for both services before building Docker images.

---

### Requirement 6: Automated Deployment to k3s

**User Story:** As a platform engineer, I want the pipeline to deploy updated images to the k3s cluster automatically, so that every merge to main results in a running update without manual SSH sessions.

#### Acceptance Criteria

1. WHEN new images are pushed to the Registry, THE Pipeline SHALL deploy the updated Kubernetes Manifests to the k3s_Cluster using `kubectl apply`.
2. THE Pipeline SHALL connect to the k3s API by establishing an SSH_Tunnel to the OCI VM using a GitHub Actions secret containing the SSH private key.
3. THE Pipeline SHALL update the image tag in each Deployment manifest to reference the newly pushed commit-SHA-tagged image before applying.
4. WHEN `kubectl apply` fails for either service, THE Pipeline SHALL report the failure and stop without marking the deployment as successful.
5. AFTER applying manifests, THE Pipeline SHALL wait for each Deployment's rollout to complete using `kubectl rollout status` before reporting success.

---

### Requirement 7: Kubernetes Manifests

**User Story:** As a platform engineer, I want Kubernetes manifests for both services, so that they can be deployed to and managed within the k3s cluster.

#### Acceptance Criteria

1. THE Manifest for each service SHALL include a `Deployment` resource with a configurable replica count defaulting to 1.
2. THE Manifest for each service SHALL include a `Service` resource of type `ClusterIP` (not `NodePort`).
3. THE Manifest for each service SHALL include an `Ingress` resource that routes external traffic via Traefik on the appropriate host path.
4. THE Manifest for the User_Service SHALL route traffic arriving at `/users` (and sub-paths) to the User_Service's `ClusterIP` Service.
5. THE Manifest for the Item_Service SHALL route traffic arriving at `/items` (and sub-paths) to the Item_Service's `ClusterIP` Service.
6. WHEN the k3s_Cluster applies a Manifest, THE Manifest SHALL configure the Deployment's container to use the image from the Registry (not a local image).
7. THE Manifest for each service SHALL configure liveness and readiness probes pointing to the `GET /health` endpoint.

---

### Requirement 8: Service Unit Tests

**User Story:** As a developer, I want unit tests for both services, so that regressions are caught before code reaches the cluster.

#### Acceptance Criteria

1. THE User_Service SHALL have unit tests that verify each CRUD endpoint returns the correct HTTP status code for valid inputs.
2. THE Item_Service SHALL have unit tests that verify each CRUD endpoint returns the correct HTTP status code for valid inputs.
3. WHEN a `POST` request is made with an invalid payload, THE User_Service test suite SHALL assert that the service returns HTTP 422.
4. WHEN a `POST` request is made with an invalid payload, THE Item_Service test suite SHALL assert that the service returns HTTP 422.
5. THE Pipeline SHALL execute the unit test suite for both services and fail the pipeline if any test fails.

---

### Requirement 9: Ingress Routing via Traefik

**User Story:** As an end user, I want to reach both microservices through the public IP of the OCI VM on standard HTTP/HTTPS ports, so that no special ports need to be opened on the firewall.

#### Acceptance Criteria

1. WHEN an HTTP request is made to `http://<vm-public-ip>/users`, THE Traefik SHALL route it to the User_Service.
2. WHEN an HTTP request is made to `http://<vm-public-ip>/items`, THE Traefik SHALL route it to the Item_Service.
3. THE Ingress for each service SHALL use the `traefik.ingress.kubernetes.io/router.entrypoints: web` annotation for HTTP.
4. THE Manifest for each service SHALL NOT define a `NodePort` — all external access SHALL be routed through Traefik.
5. WHERE TLS is configured, THE Ingress SHALL use the `websecure` entrypoint and a valid TLS secret.

---

### Requirement 10: Secrets and Configuration Management

**User Story:** As a platform engineer, I want secrets (registry credentials, SSH keys) stored securely in GitHub Actions, so that sensitive values are never committed to the repository.

#### Acceptance Criteria

1. THE Pipeline SHALL read the SSH private key for VM access exclusively from a GitHub Actions encrypted secret named `SSH_PRIVATE_KEY`.
2. THE Pipeline SHALL read the container registry token exclusively from a GitHub Actions encrypted secret named `REGISTRY_TOKEN`.
3. THE Pipeline SHALL read the VM public IP address from a GitHub Actions secret or variable named `VM_PUBLIC_IP`.
4. IF a required secret is absent or empty, THEN THE Pipeline SHALL fail immediately with a descriptive error message before executing any deployment steps.
5. THE Pipeline SHALL NOT log or echo the value of any secret in workflow step output.
