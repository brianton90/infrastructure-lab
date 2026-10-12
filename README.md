# Infrastructure Lab — Oracle Cloud Always Free (Terraform)

Provisions a single **ARM VM (Ampere A1)** on OCI's **Always Free** tier using Terraform, with **k3s** installed via cloud-init for lightweight Kubernetes workloads. k3s ships with its own containerd runtime — no separate Docker installation needed.

## ⚠️ Always Free limit change (2026)

On June 15, 2026, Oracle silently reduced the Ampere A1 Always Free cap from **4 OCPU / 24 GB** to **2 OCPU / 12 GB** per tenancy. Starting **August 18, 2026**, instances exceeding the new limit may be **automatically terminated**. This project ships pre-configured at the safe limit (`infra_vm_ocpus = 2`, `infra_vm_memory_gb = 12`). Do not increase these values without checking **OCI Console → Governance → Cost Management → Always Free Usage** first.

## Always Free resources used

| Resource | Always Free limit (2026) |
|---|---|
| Ampere A1 Flex (compute) | 2 OCPU + 12 GB RAM total (across all A1 instances) |
| Boot / Block Volume | 200 GB total pool (shared across all volumes) |
| VCN, Subnet, Internet Gateway, Route Table, Security List | Always free |
| Ephemeral public IP | Free (a **reserved/static** IP is not — avoid `oci_core_public_ip` of type `reserved`) |
| Outbound data (egress) | 10 TB/month |

## Security model

This lab uses a dynamic home IP, so CIDR-based access restriction is not practical. Security is enforced through multiple layers instead:

| Port | Exposed | Mechanism |
|---|---|---|
| 22 (SSH) | Yes — `0.0.0.0/0` | ED25519 key-only auth + fail2ban (5 failed attempts → 1h ban) |
| 80 (HTTP) | Yes — `0.0.0.0/0` | Traefik Ingress Controller — routes to services by hostname/path |
| 443 (HTTPS) | Yes — `0.0.0.0/0` | Traefik Ingress Controller (TLS) |
| 6443 (k3s API) | **No** | Localhost only — access via SSH tunnel |
| 30000–32767 (NodePorts) | **No** | Services exposed via Traefik Ingress instead |

Egress is restricted to TCP and UDP — raw protocols are blocked at the OCI Security List level.

## Project structure

```
infrastructure-lab/
├── terraform.tf          # Terraform version, required providers, remote backend
├── providers.tf          # OCI provider configuration
├── main.tf               # Data sources (availability domains, Ubuntu ARM image)
├── network.tf            # VCN, Internet Gateway, Route Table, Security List, Subnet
├── compute.tf            # Ampere A1 VM instance
├── budget.tf             # Budget + cost alert rule
├── variables.tf          # All input variables
├── outputs.tf            # Useful outputs (IP, SSH command, resource usage check)
├── terraform.tfvars.example  # Variable template — copy to terraform.tfvars
└── cloud-init.yaml       # Bootstrap: k3s, Traefik, fail2ban, UFW, SSH hardening
```

## Prerequisites

1. An OCI account (a credit card is required at signup but won't be charged within Always Free limits).
2. Terraform ~> 1.16 installed locally.
3. A local SSH key pair (`ssh-keygen -t ed25519`).
4. An **OCI API Signing Key**:
   - OCI Console → profile icon → **User Settings** → **API Keys** → **Add API Key** → generate key pair → download the private key.
   - The confirmation screen shows your `tenancy`, `user`, `fingerprint`, and `region` — copy those values into `terraform.tfvars`.
5. **OCI Customer Secret Keys** (for the remote S3-compatible backend):
   - OCI Console → **User Settings** → **Customer Secret Keys** → **Generate Secret Key**.
   - Store the Access Key ID and secret in `~/.aws/credentials` as the `[default]` profile.

## Getting started

```bash
# 1. Copy and fill in the variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars   # fill in OCIDs, fingerprint, key paths, and alert email

# 2. Initialize Terraform (downloads provider, configures backend)
terraform init

# 3. Preview the changes
terraform plan

# 4. Apply
terraform apply

# 5. Get the VM IP and connect
terraform output ssh_infra_vm
```

> The cloud-init script takes 1–2 minutes to finish after the VM boots. Wait before running `kubectl`.

### What cloud-init installs

- **k3s** (single-node Kubernetes) with API server bound to `127.0.0.1` (localhost only)
- **Traefik Ingress Controller** (included with k3s) listening on ports 80 and 443
- **fail2ban** configured for SSH: 5 failed attempts in 10 minutes → 1-hour ban
- SSH hardened: `PasswordAuthentication no`, `PermitRootLogin no`
- `KUBECONFIG` exported in `.bashrc`, alias `k=kubectl`, and `kubectl` bash completion
- `open-iscsi` (required by CSI storage providers like Longhorn)
- **UFW** configured: allow 22, 80, 443, 10250, 8472/UDP — everything else denied

### Quick validation

```bash
ssh ubuntu@<public-ip>
kubectl get nodes
kubectl get pods -A        # Traefik should appear in kube-system
```

## Accessing the k3s API remotely

The k3s API (port 6443) is not exposed to the internet. Use an SSH tunnel:

```bash
# Open the tunnel (keep this terminal open)
ssh -L 6443:localhost:6443 ubuntu@<public-ip>

# In another terminal — works transparently
kubectl get nodes
kubectl get pods -A
```

## Exposing services with Traefik Ingress

Services are exposed externally through the **Traefik Ingress Controller** on ports 80/443 — not via NodePort. This keeps the Security List clean and gives you URL-based routing.

Example Ingress resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web, websecure
spec:
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-svc
                port:
                  number: 8080
```

Point your domain's DNS A record to the VM's public IP (`terraform output infra_vm_public_ip`) and Traefik handles the routing.

## Remote state backend

State is stored in OCI Object Storage using the S3-compatible API:

- **Bucket:** `labs-infra-bucket`
- **Namespace:** `grlawnzmssdj`
- **Region:** `sa-saopaulo-1`

Authentication uses OCI Customer Secret Keys stored in `~/.aws/credentials`. See `terraform.tf` for the full backend configuration.

## Cost guardrails

- `oci_budget_budget` + `oci_budget_alert_rule` (in `budget.tf`) send an email alert if **any** charge appears on the tenancy. This is an early-warning system, not an automatic spending cap — OCI does not block consumption automatically.
- Avoid the following when extending the lab:
  - Load Balancers above the free tier (10 Mbps is free).
  - **Reserved** public IPs (ephemeral IPs used here are free).
  - Boot + block volumes exceeding 200 GB in total.
  - Non-free shapes (`VM.Standard.E3.*`, `E4.*`, etc.) — only `A1.Flex` and `E2.1.Micro` are Always Free.
  - More than 2 OCPU / 12 GB total across all A1 instances.

## Common issue: "Out of host capacity"

Popular regions (e.g., `us-ashburn-1`) frequently run out of available Always Free ARM capacity. Options:
- Retry `terraform apply` periodically — the community commonly uses scripts that retry every few minutes.
- Switch regions in `terraform.tfvars` — `eu-frankfurt-1`, `ap-tokyo-1`, and `sa-saopaulo-1` tend to have better availability.
- Use **OCI Resource Manager** (Oracle's managed Terraform service, also free) by uploading this directory as a Stack — it handles provisioning retries on the backend.

## Tear down

```bash
terraform destroy
```
