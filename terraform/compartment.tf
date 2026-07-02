resource "oci_identity_compartment" "nanoclaw" {
  compartment_id = var.tenancy_ocid
  name           = var.compartment_name
  description    = "Nanoclaw agent swarm"
  enable_delete  = true
}

# Compartments are eventually consistent across regions; creating resources
# in one immediately after it appears can 404. Give IAM time to propagate.
resource "time_sleep" "compartment_ready" {
  depends_on      = [oci_identity_compartment.nanoclaw]
  create_duration = "60s"
}
