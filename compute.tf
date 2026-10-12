# -----------------------------------------------------------------------
# Compute — Ampere A1 instance (Always Free)
#
# Always Free cap in 2026: 2 OCPU / 12 GB per tenancy.
# Runs k3s. cloud-init.yaml handles bootstrap.
# -----------------------------------------------------------------------

resource "oci_core_instance" "infra_vm" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "lab-infra-vm"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.infra_vm_ocpus
    memory_in_gbs = var.infra_vm_memory_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.lab_subnet.id
    assign_public_ip = true
    hostname_label   = "labinfra"
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = var.infra_vm_boot_volume_gb
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data           = base64encode(file("${path.module}/cloud-init.yaml"))
  }

  freeform_tags = {
    "environment" = "lab"
    "tier"        = "always-free"
    "role"        = "infra"
  }
}

# -----------------------------------------------------------------------
# Check blocks (Terraform >= 1.6) — non-blocking assertions that run
# after apply and report warnings without failing the operation.
# -----------------------------------------------------------------------

# Asserts the VM is in a running state after provisioning.
check "infra_vm_running" {
  assert {
    condition     = oci_core_instance.infra_vm.state == "RUNNING"
    error_message = "infra_vm is not in RUNNING state (current: ${oci_core_instance.infra_vm.state}). Check the OCI console for provisioning errors."
  }
}

# Guards against accidentally exceeding the Always Free A1 limits.
check "always_free_ocpu_limit" {
  assert {
    condition     = var.infra_vm_ocpus <= 2
    error_message = "infra_vm_ocpus (${var.infra_vm_ocpus}) exceeds the 2-OCPU Always Free cap for 2026. This may trigger billing."
  }
}

check "always_free_memory_limit" {
  assert {
    condition     = var.infra_vm_memory_gb <= 12
    error_message = "infra_vm_memory_gb (${var.infra_vm_memory_gb}) exceeds the 12 GB Always Free cap for 2026. This may trigger billing."
  }
}
