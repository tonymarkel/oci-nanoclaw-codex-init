# Authenticates with the local OCI config file (~/.oci/config).
# User, tenancy, key, and region all come from the selected profile.
provider "oci" {
  config_file_profile = var.config_file_profile
}
