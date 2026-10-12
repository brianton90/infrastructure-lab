# -----------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------

output "infra_vm_public_ip" {
  description = "Public IP of the infra VM."
  value       = oci_core_instance.infra_vm.public_ip
}

output "infra_vm_private_ip" {
  description = "Private IP of the infra VM within the VCN."
  value       = oci_core_instance.infra_vm.private_ip
}

output "ssh_infra_vm" {
  description = "SSH command to connect to the infra VM."
  value       = "ssh ubuntu@${oci_core_instance.infra_vm.public_ip}"
}

output "always_free_usage_check" {
  description = "Current A1 resource allocation. Must stay at or below 2 OCPU / 12 GB (Always Free cap, 2026)."
  value = {
    total_ocpus     = var.infra_vm_ocpus
    total_memory_gb = var.infra_vm_memory_gb
  }
}
