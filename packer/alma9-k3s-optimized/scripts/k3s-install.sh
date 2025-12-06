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
#   --disable traefik         - Don't install default ingress (use custom like nginx-ingress)
#   --write-kubeconfig-mode 644 - Allow non-root kubeconfig access
#   --secrets-encryption      - Enable at-rest encryption for Kubernetes secrets
#
# Environment:
#   INSTALL_K3S_SKIP_START    - Prevents service from starting during build
#
# Note: 
#   - No version specified - uses stable channel (upgrade via System Upgrade Controller post-deploy)
#   - Node name auto-detects from hostname (set by Terraform/cloud-init on deployment)
#
# Alternative approach (cloud-init):
#   Instead of baking k3s, you could install it via cloud-init user-data.
#   This allows different k3s versions per VM but increases boot time.
#   See: https://k3s.io/ for cloud-init examples.
#
# Refs: Req 1.3, 2.1, 2.2, 2.3, 2.4
# =============================================================================

set -euo pipefail

echo "==> Installing k3s (stable channel)..."

# -----------------------------------------------------------------------------
# Install k3s Server
# -----------------------------------------------------------------------------

echo "==> Downloading and installing k3s..."

# Install k3s using the official install script
# The script handles architecture detection and systemd service setup
# Node name will auto-detect from hostname when the VM boots
# INSTALL_K3S_SKIP_START prevents the service from starting during image build
curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh -s - server \
    --disable traefik \
    --write-kubeconfig-mode 644 \
    --secrets-encryption

# Note: Service is installed but not started. The template will have k3s ready
# to start on first boot without any generated certificates or cluster state.

# -----------------------------------------------------------------------------
# Configure k3s Service
# -----------------------------------------------------------------------------

echo "==> Configuring k3s service..."

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
# Install Auto-Deploy Manifests
# -----------------------------------------------------------------------------

echo "==> Installing k3s auto-deploy manifests..."

# Create manifests directory (will be created by k3s on first start, but we need it now)
MANIFESTS_DIR="/var/lib/rancher/k3s/server/manifests"
mkdir -p "${MANIFESTS_DIR}"

# Move any manifests from /tmp/manifests to the k3s manifests directory
if [ -d /tmp/manifests ]; then
    mv /tmp/manifests/* "${MANIFESTS_DIR}/" 2>/dev/null || true
    rm -rf /tmp/manifests
    echo "==> Installed auto-deploy manifests from /tmp/manifests"
    ls -la "${MANIFESTS_DIR}/"
else
    echo "==> No manifests found in /tmp/manifests"
fi

# -----------------------------------------------------------------------------
# Verify Installation
# -----------------------------------------------------------------------------

echo "==> Verifying k3s installation..."

# Check binary exists and is executable
if ! command -v k3s &> /dev/null; then
    echo "==> ERROR: k3s binary not found!"
    exit 1
fi

# Verify version (from stable channel)
INSTALLED_VERSION=$(k3s --version | head -1)
echo "==> Installed: ${INSTALLED_VERSION}"
echo "==> Note: Version from stable channel. Use System Upgrade Controller for automatic updates."

# Verify kubectl is available via k3s
if ! k3s kubectl version --client &> /dev/null; then
    echo "==> ERROR: k3s kubectl not working!"
    exit 1
fi

echo "==> k3s kubectl available."

# Verify systemd service file exists
if [ ! -f /etc/systemd/system/k3s.service ]; then
    echo "==> ERROR: k3s systemd service file not found!"
    exit 1
fi

echo "==> k3s installation completed successfully."
echo "==> On first boot, k3s will initialize a new cluster."
