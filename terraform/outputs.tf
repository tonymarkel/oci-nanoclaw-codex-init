output "compartment_id" {
  description = "OCID of the Nanoclaw compartment."
  value       = oci_identity_compartment.nanoclaw.id
}

output "image_name" {
  description = "Oracle Linux 9 image the instances booted from."
  value       = data.oci_core_images.ol9.images[0].display_name
}

output "instance_public_ips" {
  description = "Public IPs of the swarm, keyed by instance name."
  value = {
    for inst in oci_core_instance.nanoclaw : inst.display_name => inst.public_ip
  }
}
