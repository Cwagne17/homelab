#!/bin/bash
# =============================================================================
# k3s Server Installation Script
#
# This script installs k3s into the golden image with:
#   - k3s server with Traefik ingress disabled
#   - Systemd service enabled for automatic startup
#   - Binary verification after installation
#
# Why bake k3s into the image:
#   - Fast boot: VMs start with Kubernetes already running
#   - Consistency: Every VM uses the exact same k3s version
#   - Reduced provisioning: No network download at runtime
#   - Atomic updates: Create new images to update k3s
#
# Flags used:
#   --disable traefik    - Don't install default ingress (use custom)
#   --write-kubeconfig-mode 644 - Allow non-root kubeconfig access
#   --node-name $(hostname) - Use VM hostname as node name
#
# Alternative approach (cloud-init):
#   Instead of baking k3s, you could install it via cloud-init user-data.
#   This allows different k3s versions per VM but increases boot time.
#   See: https://k3s.io/ for cloud-init examples.
#
# Refs: Req 1.3, 2.1, 2.2, 2.3, 2.4
# =============================================================================

set -euo pipefail

# K3S_VERSION is passed as environment variable from Packer
K3S_VERSION="${K3S_VERSION:-v1.28.5+k3s1}"

echo "==> Installing k3s version: ${K3S_VERSION}"

# -----------------------------------------------------------------------------
# Install k3s Server
# -----------------------------------------------------------------------------

echo "==> Downloading and installing k3s..."

# Install k3s using the official install script
# The script handles architecture detection and systemd service setup
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh -s - server \
    --disable traefik \
    --write-kubeconfig-mode 644 \
    --node-name "\$(hostname)"

# Note: The above command installs k3s and enables the service but we'll
# stop it after installation since the golden image shouldn't have a
# running cluster with generated certificates.

# -----------------------------------------------------------------------------
# Configure k3s Service
# -----------------------------------------------------------------------------

echo "==> Configuring k3s service..."

# Stop k3s for template preparation
# The service will start fresh on first boot with new node identity
systemctl stop k3s

# Ensure service is enabled for automatic startup
systemctl enable k3s

# Clean up any generated data that should be unique per VM
rm -rf /var/lib/rancher/k3s/server/db/
rm -rf /var/lib/rancher/k3s/server/tls/
rm -rf /var/lib/rancher/k3s/agent/
rm -f /etc/rancher/k3s/k3s.yaml
rm -f /var/lib/rancher/k3s/server/node-token

echo "==> Cleaned k3s state for template."

# -----------------------------------------------------------------------------
# Verify Installation
# -----------------------------------------------------------------------------

echo "==> Verifying k3s installation..."

# Check binary exists and is executable
if ! command -v k3s &> /dev/null; then
    echo "==> ERROR: k3s binary not found!"
    exit 1
fi

# Verify version
INSTALLED_VERSION=$(k3s --version | head -1)
echo "==> Installed: ${INSTALLED_VERSION}"

# Verify kubectl is available via k3s
if ! k3s kubectl version --client &> /dev/null; then
    echo "==> ERROR: k3s kubectl not working!"
    exit 1
fi

echo "==> k3s kubectl available."

# Verify systemd service exists
if ! systemctl list-unit-files | grep -q k3s.service; then
    echo "==> ERROR: k3s systemd service not found!"
    exit 1
fi

echo "==> k3s systemd service is configured."

# -----------------------------------------------------------------------------
# Create helpful aliases and configuration
# -----------------------------------------------------------------------------

echo "==> Setting up kubectl alias..."

# Add kubectl alias for convenience
cat >> /etc/profile.d/k3s.sh <<'EOF'
# k3s kubectl alias
alias kubectl='k3s kubectl'
alias k='k3s kubectl'

# kubeconfig for tools that need it
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
EOF

chmod 644 /etc/profile.d/k3s.sh

echo "==> k3s installation completed successfully."
echo "==> On first boot, k3s will initialize a new cluster."
