# -----------------------------------------------------------------------
# OCI Authentication
# -----------------------------------------------------------------------

variable "tenancy_ocid" {
  description = "OCID of the tenancy (Profile > Tenancy in OCI console)."
  type        = string

  validation {
    condition     = startswith(var.tenancy_ocid, "ocid1.tenancy.")
    error_message = "tenancy_ocid must start with 'ocid1.tenancy.'."
  }
}

variable "user_ocid" {
  description = "OCID of the user (Profile > User Settings)."
  type        = string

  validation {
    condition     = startswith(var.user_ocid, "ocid1.user.")
    error_message = "user_ocid must start with 'ocid1.user.'."
  }
}

variable "fingerprint" {
  description = "Fingerprint of the API signing key (User Settings > API Keys)."
  type        = string

  validation {
    condition     = can(regex("^([0-9a-f]{2}:){15}[0-9a-f]{2}$", var.fingerprint))
    error_message = "fingerprint must be in the format xx:xx:...:xx (16 hex pairs separated by colons)."
  }
}

variable "private_key_path" {
  description = "Local path to the OCI API private key (e.g. ~/.oci/oci_api_key.pem)."
  type        = string
}

variable "region" {
  description = "OCI region (e.g. sa-saopaulo-1, us-ashburn-1). Regions with better ARM Always Free availability: eu-frankfurt-1, ap-tokyo-1, sa-saopaulo-1."
  type        = string
  default     = "sa-saopaulo-1"
}

# -----------------------------------------------------------------------
# Compartment
# -----------------------------------------------------------------------

variable "compartment_ocid" {
  description = "OCID of the compartment where resources will be created. Can be the root tenancy OCID."
  type        = string

  validation {
    condition     = startswith(var.compartment_ocid, "ocid1.")
    error_message = "compartment_ocid must be a valid OCI OCID starting with 'ocid1.'."
  }
}

# -----------------------------------------------------------------------
# SSH access
# -----------------------------------------------------------------------

variable "ssh_public_key_path" {
  description = "Local path to the SSH public key injected into the VM (e.g. ~/.ssh/id_ed25519.pub)."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

# -----------------------------------------------------------------------
# Compute — Always Free limits (2026): 2 OCPU / 12 GB total per tenancy.
# Exceeding these may trigger billing or automatic instance termination.
# Verify at: OCI Console > Governance > Cost Management > Always Free Usage.
# -----------------------------------------------------------------------

variable "infra_vm_ocpus" {
  description = "Number of OCPUs for the infra VM. Always Free cap in 2026: 2 total."
  type        = number
  default     = 2

  validation {
    condition     = var.infra_vm_ocpus >= 1 && var.infra_vm_ocpus <= 2
    error_message = "infra_vm_ocpus must be between 1 and 2 to stay within the Always Free limit."
  }
}

variable "infra_vm_memory_gb" {
  description = "Memory in GB for the infra VM. Always Free cap in 2026: 12 GB total."
  type        = number
  default     = 12

  validation {
    condition     = var.infra_vm_memory_gb >= 1 && var.infra_vm_memory_gb <= var.infra_vm_ocpus * 6
    error_message = "infra_vm_memory_gb must be between 1 and (infra_vm_ocpus * 6) to respect the Always Free 6 GB/OCPU ratio."
  }
}

variable "infra_vm_boot_volume_gb" {
  description = "Boot volume size in GB. The Always Free pool is 200 GB shared across all block volumes."
  type        = number
  default     = 50

  validation {
    condition     = var.infra_vm_boot_volume_gb >= 50 && var.infra_vm_boot_volume_gb <= 200
    error_message = "infra_vm_boot_volume_gb must be between 50 (OCI minimum) and 200 (Always Free pool total)."
  }
}

# -----------------------------------------------------------------------
# Budget alert
# -----------------------------------------------------------------------

variable "budget_alert_email" {
  description = "Email address to receive an alert if any cost appears on the tenancy."
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.budget_alert_email))
    error_message = "budget_alert_email must be a valid email address."
  }
}
