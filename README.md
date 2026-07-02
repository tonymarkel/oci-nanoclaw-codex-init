# Nanoclaw on OCI + Codex + Podman
Nanoclaw is a small agent that runs in it's own sandbox. In it's current form it prefers local Mac/Linux and can use Claude for debugging out of the box. This script allows you to run Nanoclaw on OCI and Oracle Linux 9 so that you can experiment with your agents while using cloud resources, and not running Docker in an enterprise context.
## To Run
* Incorporate nanoclaw-init.sh into cloud-init on a new compute instance running Oracle Linux 9
* Run this as an unpriviliged user with sudo access on an existing instance
```
curl -sSL https://github.com/tonymarkel/oci-nanoclaw-codex-init/nanoclaw-init.sh | bash
```

Note: this script performs a `dnf update` and reboots the machine

## After Installation - Next Login
1. Codex Setup - Choose Device Pairing
2. Nanoclaw Setup - Choose Codex for the Agent - Device Pair again
3. For any errors, do not debug with Claude, but run `codex /debug` from the nanoclaw-v2 directory
4. Once running, run `npnm run chat hi` from the nanoclaw-v2 directory
