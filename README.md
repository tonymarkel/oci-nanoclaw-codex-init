# Nanoclaw on OCI + Codex + Podman
Nanoclaw is a small agent that runs in it's own sandbox. In it's current form it prefers local Mac/Linux and can use Claude for debugging out of the box. This script allows you to run Nanoclaw on OCI and Oracle Linux 9 so that you can experiment with your agents while using cloud resources, and not running Docker in an enterprise context.
## To Run
* Incorporate nanoclaw-init.sh into cloud-init on a new compute instance running Oracle Linux 9
* Run this as an unpriviliged user with sudo access on an existing instance
```
curl -sSL https://github.com/tonymarkel/oci-nanoclaw-codex-init/nanoclaw-init.sh | bash
```

> [!NOTE]
> This script performs a `dnf update -y` and reboots the machine

## After Installation - Next Login
1. Codex Setup - Choose Device Pairing
2. Nanoclaw Setup - Choose Codex for the Agent - Device Pair again
3. For any errors, do not debug with Claude, but run `codex /debug` from the nanoclaw-v2 directory
4. Once running, run `npnm run chat hi` from the nanoclaw-v2 directory

## Using Terraform to Swarm
In the terraform folder is some sample code that will set up a cluster of Nanoclaw nodes. It uses cloud-init to install the prerequisites. Configuring each node is still manual. The output will give you a list of public IP addresses to use to log in and configure nanoclaw:
```
instance_public_ips = {
  "nanoclaw-1" = "256.132.99.1"
  "nanoclaw-2" = "332.458.12.55"
  "nanoclaw-3" = "543.21.0.9"
  "nanoclaw-4" = "987.65.43.21"
  "nanoclaw-5" = "420.69.6.7"
}
```
(No, these are not valid IPv4 addresses)