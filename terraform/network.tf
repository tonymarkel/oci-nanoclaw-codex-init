resource "oci_core_vcn" "nanoclaw" {
  compartment_id = oci_identity_compartment.nanoclaw.id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "nanoclaw-vcn"
  dns_label      = "nanoclaw"

  depends_on = [time_sleep.compartment_ready]
}

resource "oci_core_internet_gateway" "nanoclaw" {
  compartment_id = oci_identity_compartment.nanoclaw.id
  vcn_id         = oci_core_vcn.nanoclaw.id
  display_name   = "nanoclaw-igw"
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = oci_identity_compartment.nanoclaw.id
  vcn_id         = oci_core_vcn.nanoclaw.id
  display_name   = "nanoclaw-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.nanoclaw.id
  }
}

resource "oci_core_security_list" "public" {
  compartment_id = oci_identity_compartment.nanoclaw.id
  vcn_id         = oci_core_vcn.nanoclaw.id
  display_name   = "nanoclaw-public-sl"

  # Instances need outbound access for dnf, git, npm, and Codex.
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"

    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"

    tcp_options {
      min = 443
      max = 443
    }
  }

  # Path MTU discovery (fragmentation needed) — standard OCI hygiene.
  ingress_security_rules {
    protocol = "1" # ICMP
    source   = "0.0.0.0/0"

    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = oci_identity_compartment.nanoclaw.id
  vcn_id                     = oci_core_vcn.nanoclaw.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "nanoclaw-public"
  dns_label                  = "pub"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false
}
