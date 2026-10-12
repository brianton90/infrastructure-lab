# -----------------------------------------------------------------------
# Network — VCN, Internet Gateway, Route Table, Security List, Subnet
# All resources within the OCI Always Free tier.
#
# Security model:
#   - SSH (22)       : open to 0.0.0.0/0 — key-only auth + fail2ban on host
#   - HTTP (80)      : open to 0.0.0.0/0 — Traefik Ingress (plain HTTP)
#   - HTTPS (443)    : open to 0.0.0.0/0 — Traefik Ingress (TLS)
#   - k3s API (6443) : NOT exposed externally — SSH tunnel only
#   - NodePorts      : NOT exposed — services are accessed via Traefik Ingress
#   - Egress         : TCP + UDP only (no raw protocols)
# -----------------------------------------------------------------------

resource "oci_core_vcn" "lab_vcn" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "lab-vcn"
  dns_label      = "labvcn"
}

resource "oci_core_internet_gateway" "lab_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.lab_vcn.id
  display_name   = "lab-igw"
  enabled        = true
}

resource "oci_core_route_table" "lab_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.lab_vcn.id
  display_name   = "lab-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.lab_igw.id
  }
}

resource "oci_core_security_list" "lab_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.lab_vcn.id
  display_name   = "lab-sl"

  # ------------------------------------------------------------------
  # Egress — TCP and UDP only. Raw protocols blocked.
  # ------------------------------------------------------------------

  egress_security_rules {
    description = "Allow outbound TCP"
    destination = "0.0.0.0/0"
    protocol    = "6"
  }

  egress_security_rules {
    description = "Allow outbound UDP (DNS, NTP, Flannel VXLAN)"
    destination = "0.0.0.0/0"
    protocol    = "17"
  }

  # ------------------------------------------------------------------
  # Ingress SSH (22)
  # Open to all IPs — dynamic home IP makes CIDR restriction impractical.
  # Compensated by: ED25519 key-only auth + fail2ban (5 attempts → 1h ban).
  # ------------------------------------------------------------------

  ingress_security_rules {
    description = "SSH — key-only auth, fail2ban active on host"
    protocol    = "6"
    source      = "0.0.0.0/0"

    tcp_options {
      min = 22
      max = 22
    }
  }

  # ------------------------------------------------------------------
  # Ingress HTTP (80) — Traefik Ingress Controller
  # ------------------------------------------------------------------

  ingress_security_rules {
    description = "HTTP — Traefik Ingress"
    protocol    = "6"
    source      = "0.0.0.0/0"

    tcp_options {
      min = 80
      max = 80
    }
  }

  # ------------------------------------------------------------------
  # Ingress HTTPS (443) — Traefik Ingress Controller (TLS)
  # ------------------------------------------------------------------

  ingress_security_rules {
    description = "HTTPS — Traefik Ingress (TLS)"
    protocol    = "6"
    source      = "0.0.0.0/0"

    tcp_options {
      min = 443
      max = 443
    }
  }

  # ------------------------------------------------------------------
  # k3s API (6443) — NOT exposed externally.
  # Access via SSH tunnel: ssh -L 6443:localhost:6443 ubuntu@<public-ip>
  #
  # NodePorts (30000-32767) — NOT exposed.
  # Route external traffic through Traefik Ingress on 80/443 instead.
  # ------------------------------------------------------------------
}

resource "oci_core_subnet" "lab_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.lab_vcn.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "lab-subnet"
  dns_label                  = "labsub"
  route_table_id             = oci_core_route_table.lab_rt.id
  security_list_ids          = [oci_core_security_list.lab_sl.id]
  prohibit_public_ip_on_vnic = false
}
