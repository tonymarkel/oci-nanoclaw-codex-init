# Nanoclaw Swarm — OCI Terraform

Spins up the Nanoclaw swarm on OCI:

* **Compartment** `Nanoclaw` off the tenancy root
* **VCN** `172.16.0.0/16` with an internet gateway
  * Public subnet `172.16.128.0/24`, security list allowing 22 and 443 from `0.0.0.0/0` (plus all egress)
* **5 × VM.Standard.A2.Flex** instances — 2 OCPU / 16 GB / 100 GB boot volume, latest Oracle Linux 9, public IPs
* [`nanoclaw-init.sh`](../nanoclaw-init.sh) delivered via cloud-init, run as the `opc` user (the script expects an unprivileged user with sudo). Each instance **reboots itself** when the script finishes — that's expected.

## Prerequisites

* Terraform >= 1.5
* A working `~/.oci/config` (API key auth) — region is taken from the profile

## Usage

```sh
cp terraform.tfvars.example terraform.tfvars   # then set tenancy_ocid
terraform init
terraform plan
terraform apply
```

Public IPs are printed as the `instance_public_ips` output. Cloud-init progress on an instance is logged to `/var/log/nanoclaw-init.log`.

After boot + self-reboot, SSH in as `opc` and follow the "After Installation" steps in the [repo README](../README.md) (Codex device pairing is interactive and runs on first login).

`terraform destroy` removes everything including the compartment (`enable_delete = true`).
