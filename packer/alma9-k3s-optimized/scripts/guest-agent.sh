#!/bin/bash
# =============================================================================
# QEMU Guest Agent Installation Script
#
# This script installs and enables the QEMU guest agent, which provides:
#   - VM lifecycle management from Proxmox (shutdown, reboot)
#   - Filesystem freeze for consistent snapshots
#   - Network information reporting to hypervisor
#   - Guest information (hostname, OS version) in Proxmox UI
#
# Why the guest agent:
#   - Enables graceful VM shutdown from Proxmox
#   - Allows Proxmox to query VM IP addresses
#   - Required for backup consistency (fsfreeze)
#   - Improves VM management experience
#
# Refs: Req 1.3, 9.2
# =============================================================================

set -euo pipefail

echo "==> Installing QEMU guest agent..."

# -----------------------------------------------------------------------------
# Install QEMU Guest Agent
# -----------------------------------------------------------------------------

dnf install -y qemu-guest-agent

# -----------------------------------------------------------------------------
# Enable and Start Service
# -----------------------------------------------------------------------------

echo "==> Enabling QEMU guest agent service..."
systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent

# -----------------------------------------------------------------------------
# Verify Installation
# -----------------------------------------------------------------------------

echo "==> Verifying QEMU guest agent..."
if systemctl is-active --quiet qemu-guest-agent; then
    echo "==> QEMU guest agent is running."
else
    echo "==> WARNING: QEMU guest agent is not running!"
    echo "==> This may be expected during Packer build (no virtio channel)."
fi

# Verify the agent binary exists
if command -v qemu-ga &> /dev/null; then
    echo "==> QEMU guest agent binary found: $(which qemu-ga)"
else
    echo "==> ERROR: QEMU guest agent binary not found!"
    exit 1
fi

echo "==> QEMU guest agent installation completed."
