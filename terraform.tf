# -----------------------------------------------------------------------
# Terraform configuration — required version, providers, and backend
# -----------------------------------------------------------------------

terraform {
  # Pinned to 1.16.x — allows patch upgrades, blocks unintended minor/major jumps.
  required_version = "~> 1.16"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.40"
    }
  }

  # Native OCI backend — introduced in Terraform 1.16.
  # Uses OCI API key auth (same ~/.oci/config as the provider).
  # No Customer Secret Keys needed. Supports state locking natively.
  backend "oci" {
    bucket    = "labs-infra-bucket"
    namespace = "grlawnzmssdj"
    key       = "terraform.tfstate"
    region    = "sa-saopaulo-1"
  }
}
