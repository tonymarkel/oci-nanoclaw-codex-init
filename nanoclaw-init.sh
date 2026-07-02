#!/bin/bash
#
# Installs the prerequisites to run nanoclaw on Oracle Linux 9
# using codex as the main AI engine. 
#
set -euo pipefail

# ===========================================================================
# Packages (qemu-kvm, qemu-img, virtiofsd, podman-gvproxy dropped: those are
# only needed for `podman machine`, which is for macOS/Windows hosts)
# ===========================================================================
sudo dnf update -y
sudo dnf install -y \
  bubblewrap \
  ca-certificates \
  containers-common-extra \
  git \
  patch \
  podman \
  podman-docker

# Silence the "podman is emulating docker" message
sudo touch /etc/containers/nodocker

# ===========================================================================
# nvm + Node 22 (source nvm.sh directly; ~/.bashrc may no-op non-interactively)
# ===========================================================================
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh | bash
fi
. "$NVM_DIR/nvm.sh"
nvm install 22
nvm alias default 22
nvm use 22

# ===========================================================================
# Codex CLI (config/login is interactive — done at the end of this script)
# ===========================================================================
npm install -g @openai/codex

# ===========================================================================
# docker-compose: install into PATH. `podman compose` searches PATH for a
# compose provider; the podman-docker shim does NOT read ~/.docker/cli-plugins.
# ===========================================================================
if [ ! -x /usr/local/bin/docker-compose ]; then
  sudo curl -fSL \
    "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
    -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi

# ===========================================================================
# SELinux policy for nanoclaw containers writing into home-dir bind mounts.
# NOTE: this grants ALL container_t processes write access to user_home_t.
# If :Z/:z volume labels (or a udica-generated policy) cover your mounts,
# prefer those — they're much narrower.
# ===========================================================================
if ! sudo semodule -l | grep -q '^nanoclaw-v2-selinux-policy'; then
  policy_dir=$(mktemp -d)
  cat > "$policy_dir/nanoclaw-v2-selinux-policy.te" <<'EOF'
module nanoclaw-v2-selinux-policy 1.0;

require {
        type container_t;
        type container_runtime_t;
        type user_home_t;
        type unconfined_t;
        type user_tmp_t;
        class file { append create ioctl link lock map open read rename setattr unlink write };
        class dir { add_name create remove_name rename reparent rmdir setattr watch write };
        class lnk_file { create read unlink };
        class process2 { nnp_transition nosuid_transition };
}

#============= container_t ==============
allow container_t user_home_t:dir { add_name create remove_name rename reparent rmdir setattr watch write };
allow container_t user_home_t:file { append create ioctl link lock map open read rename setattr unlink write };
allow container_t user_home_t:lnk_file { create read unlink };
allow container_t user_tmp_t:file open;
#============= unconfined_t ==============
allow unconfined_t container_runtime_t:process2 { nnp_transition nosuid_transition };
EOF
  checkmodule -M -m \
    -o "$policy_dir/nanoclaw-v2-selinux-policy.mod" \
    "$policy_dir/nanoclaw-v2-selinux-policy.te"
  semodule_package \
    -o "$policy_dir/nanoclaw-v2-selinux-policy.pp" \
    -m "$policy_dir/nanoclaw-v2-selinux-policy.mod"
  sudo semodule -i "$policy_dir/nanoclaw-v2-selinux-policy.pp"
  rm -rf "$policy_dir"
fi

# ===========================================================================
# Rootless podman API socket (docker-compatible). No sudo with --user!
# Linger keeps the user manager (and socket) alive without a login session.
# ===========================================================================
systemctl --user enable --now podman.socket
sudo loginctl enable-linger "$USER"

DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"
export DOCKER_HOST
if ! grep -q 'DOCKER_HOST=.*podman' ~/.bashrc; then
  # shellcheck disable=SC2016
  echo 'export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"' >> ~/.bashrc
fi

# ===========================================================================
# OneCLI: bind host + firewall
# ===========================================================================
hostip=$(ip -o -4 addr list | awk '{print $4}' | cut -d/ -f1 | grep -v '^127\.' | head -n 1)
export ONECLI_BIND_HOST="$hostip"
if ! grep -q 'ONECLI_BIND_HOST' ~/.bashrc; then
  echo "export ONECLI_BIND_HOST=$hostip" >> ~/.bashrc
fi
sudo firewall-cmd --zone=public --permanent --add-port=10254-10255/tcp
sudo firewall-cmd --reload

# ===========================================================================
# Fetch nanoclaw.  Optionally, pin to a known-good commit for your patches. 
# ===========================================================================
if [ ! -d nanoclaw-v2 ]; then
  git clone https://github.com/nanocoai/nanoclaw.git nanoclaw-v2
fi
cd nanoclaw-v2
# git checkout <known-good-sha>   # TODO: pin the commit your patches target

# ===========================================================================
# Patch 1: container-runtime.ts 
# adds: isPodmanRuntime, isRootlessDockerRuntime
# ===========================================================================
if ! grep -q 'isPodmanRuntime' src/container-runtime.ts; then
  patch -l src/container-runtime.ts <<'EOF'
--- nanoclaw-v2/src/container-runtime.ts        2026-07-02 13:29:16.799077527 +0000
+++ container-runtime.ts        2026-07-02 13:27:22.770570553 +0000
@@ -11,6 +11,42 @@
 /** The container runtime binary name. */
 export const CONTAINER_RUNTIME_BIN = 'docker';
 
+/**
+ * Returns true if the container runtime is actually Podman (which may be
+ * aliased as docker). Rootless Podman needs --userns=keep-id to map the
+ * container's node user (uid 1000) back to the host user instead of into the
+ * subuid range, allowing writes to host-owned group directories.
+ */
+export function isPodmanRuntime(): boolean {
+  try {
+    const result = execSync(`${CONTAINER_RUNTIME_BIN} --version`, {
+      encoding: 'utf-8',
+      stdio: ['pipe', 'pipe', 'pipe'],
+    });
+    return /podman/i.test(result);
+  } catch {
+    return false;
+  }
+}
+
+/**
+ * Returns true if Docker is running in rootless mode.
+ * In rootless Docker the user namespace maps container UID 0 → host UID (the
+ * user who owns the daemon), so the container must run as UID 0 (--user 0:0)
+ * to get write access to host-owned bind-mount directories.
+ */
+export function isRootlessDockerRuntime(): boolean {
+  try {
+    const result = execSync(`${CONTAINER_RUNTIME_BIN} info`, {
+      encoding: 'utf-8',
+      stdio: ['pipe', 'pipe', 'pipe'],
+    });
+    return /^\s+rootless:\s+true\s*$/m.test(result);
+  } catch {
+    return false;
+  }
+}
+
 /** CLI args needed for the container to resolve the host gateway. */
 export function hostGatewayArgs(): string[] {
   // On Linux, host.docker.internal isn't built-in — add it explicitly
@@ -21,8 +57,8 @@
 }
 
 /** Returns CLI args for a readonly bind mount. */
-export function readonlyMountArgs(hostPath: string, containerPath: string): string[] {
-  return ['-v', `${hostPath}:${containerPath}:ro`];
+export function readonlyMountArgs(hostPath: string, containerPath: string, relabel = false): string[] {
+  return ['-v', `${hostPath}:${containerPath}:${relabel ? 'ro,z' : 'ro'}`];
 }
 
 /** Stop a container by name. Uses execFileSync to avoid shell injection. */
EOF
fi

# The new functions use execSync — make sure it's imported.
if ! grep -q "child_process" src/container-runtime.ts; then
  sed -i "0,/^import /s//import { execSync } from 'node:child_process';\nimport /" \
    src/container-runtime.ts
  grep -q "child_process" src/container-runtime.ts || {
    echo "ERROR: couldn't add execSync import to container-runtime.ts" >&2
    exit 1
  }
fi

# ===========================================================================
# Patch 2: container-runtime.test.ts — prevents regression
# ===========================================================================
if ! grep -q 'SELinux' src/container-runtime.test.ts; then
  patch -l src/container-runtime.test.ts <<'EOF'
--- nanoclaw-v2/src/container-runtime.test.ts   2026-07-02 13:29:16.799077527 +0000
+++ container-runtime.test.ts   2026-07-02 13:27:29.260713242 +0000
@@ -38,6 +38,11 @@
     const args = readonlyMountArgs('/host/path', '/container/path');
     expect(args).toEqual(['-v', '/host/path:/container/path:ro']);
   });
+
+  it('adds a shared SELinux relabel option for Podman mounts', () => {
+    const args = readonlyMountArgs('/host/path', '/container/path', true);
+    expect(args).toEqual(['-v', '/host/path:/container/path:ro,z']);
+  });
 });
 
 describe('stopContainer', () => {
EOF
fi

# ===========================================================================
# Patch 3: container-runner.ts — runtime-aware user mapping
# ===========================================================================
if ! grep -q 'isPodmanRuntime' src/container-runner.ts; then
  patch -l src/container-runner.ts <<'EOF'
--- nanoclaw-v2/src/container-runner.ts 2026-07-02 13:29:16.799077527 +0000
+++ container-runner.ts 2026-07-02 13:27:08.186249910 +0000
@@ -24,7 +24,7 @@
 import { materializeContainerJson } from './container-config.js';
 import { getContainerConfig } from './db/container-configs.js';
 import { updateContainerConfigScalars } from './db/container-configs.js';
-import { CONTAINER_RUNTIME_BIN, hostGatewayArgs, readonlyMountArgs, stopContainer } from './container-runtime.js';
+import { CONTAINER_RUNTIME_BIN, hostGatewayArgs, isPodmanRuntime, isRootlessDockerRuntime, readonlyMountArgs, stopContainer } from './container-runtime.js';
 import { EGRESS_NETWORK, egressNetworkArgs, ensureEgressNetwork } from './egress-lockdown.js';
 import { composeGroupClaudeMd } from './claude-md-compose.js';
 import { getAgentGroup } from './db/agent-groups.js';
@@ -466,7 +466,12 @@
   // User mapping
   const hostUid = process.getuid?.();
   const hostGid = process.getgid?.();
-  if (hostUid != null && hostUid !== 0 && hostUid !== 1000) {
+  const podmanRuntime = isPodmanRuntime();
+  if (podmanRuntime) {
+    args.push('--userns=keep-id');
+  } else if (isRootlessDockerRuntime()) {
+    args.push('--user', '0:0');
+  } else if (hostUid != null && hostUid !== 0 && hostUid !== 1000) {
     args.push('--user', `${hostUid}:${hostGid}`);
     args.push('-e', 'HOME=/home/node');
   }
@@ -474,9 +479,9 @@
   // Volume mounts
   for (const mount of mounts) {
     if (mount.readonly) {
-      args.push(...readonlyMountArgs(mount.hostPath, mount.containerPath));
+      args.push(...readonlyMountArgs(mount.hostPath, mount.containerPath, podmanRuntime));
     } else {
-      args.push('-v', `${mount.hostPath}:${mount.containerPath}`);
+      args.push('-v', `${mount.hostPath}:${mount.containerPath}${podmanRuntime ? ':z' : ''}`);
     }
   }
 
EOF
fi

# ===========================================================================
# Set interactive steps to run on first login after reboot
# ===========================================================================
cat <<'EOF' > /home/opc/first_login.sh
#!/bin/bash

# Path to the tracking flag
FLAG_FILE="$HOME/.first_login_done"

if [ ! -f "$FLAG_FILE" ]; then
    echo "This is your first login. Running Nanoclaw initialization..."
    echo "Please follow the prompts to configure Nanoclaw and Codex."
    cd nanoclaw-v2
    codex
    touch "$FLAG_FILE"
    ./nanoclaw.sh
else
    cd nanoclaw-v2
fi
EOF
chmod +x /home/opc/first_login.sh
echo ". /home/opc/first_login.sh" >> /home/opc/.bash_profile
sudo reboot
