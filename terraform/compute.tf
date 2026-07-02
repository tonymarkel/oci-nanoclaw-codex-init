data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Latest Oracle Linux 9 platform image compatible with the chosen shape
# (returns aarch64 images automatically for Ampere shapes).
data "oci_core_images" "ol9" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "nanoclaw" {
  count = var.instance_count

  compartment_id      = oci_identity_compartment.nanoclaw.id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "nanoclaw-${count.index + 1}"
  shape               = var.instance_shape

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ol9.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    display_name     = "nanoclaw-${count.index + 1}"
    hostname_label   = "nanoclaw-${count.index + 1}"
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
      init_script = file("${path.module}/../nanoclaw-init.sh")
    }))
  }

  depends_on = [time_sleep.compartment_ready]
}
