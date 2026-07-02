variable "tenancy_ocid" {
  description = "OCID of the tenancy root. The Nanoclaw compartment is created directly under it. Find it in ~/.oci/config (tenancy=...)."
  type        = string
}

variable "config_file_profile" {
  description = "Profile name in ~/.oci/config to authenticate with."
  type        = string
  default     = "DEFAULT"
}

variable "compartment_name" {
  description = "Name of the compartment created off the tenancy root."
  type        = string
  default     = "Nanoclaw"
}

variable "vcn_cidr" {
  description = "CIDR block for the VCN."
  type        = string
  default     = "172.16.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "172.16.128.0/24"
}

variable "instance_count" {
  description = "Number of compute instances in the swarm."
  type        = number
  default     = 5
}

variable "instance_shape" {
  description = "Compute shape for the instances."
  type        = string
  default     = "VM.Standard.A2.Flex"
}

variable "instance_ocpus" {
  description = "OCPUs per instance."
  type        = number
  default     = 2
}

variable "instance_memory_gb" {
  description = "Memory per instance, in GB."
  type        = number
  default     = 16
}

variable "boot_volume_gb" {
  description = "Boot volume size per instance, in GB."
  type        = number
  default     = 100
}

variable "ssh_public_key" {
  description = "SSH public key installed for the opc user."
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJGt7N33P+4kb3rRAv0/T19mZgNI8IjBeDmPfZxAW5oNzzQfFZfejBRTGIyB2pZ21jVrbgbWnlqdoYR7J3GQg2fEHgCBqSgLc9mVuFE15qt4N5IBqhNKA02OM8T39p7ReVFVs+86sxLuHqROnbCxl+kM2hgN88TwVe2lts88f8iGwlJMnxbtafWZZtmddiV+2v4Qa6K6b704QwVygIo7qWHspOnF6GjOB6pAWoW3trKqfAv4qHdEK6CQCD0AfiCQdgzWe3VFSluyFrobTWwc/VToZfQYG+gnqOl4VE2Q8XtErvOywm/abTelipZ2xogqbXstuMZAadZPDXWeVZG7bN ssh-key-2026-06-30"
}
