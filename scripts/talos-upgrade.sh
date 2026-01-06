#!/usr/bin/env bash
set -euo pipefail

# Talos Cluster Upgrade Script
# Upgrades all nodes in the cluster to a new Talos version

TERRAFORM_DIR="terraform/envs/talos_cluster"
TALOSCONFIG="${TERRAFORM_DIR}/output/talosconfig"

# Check if talosctl is installed
if ! command -v talosctl &> /dev/null; then
    echo "❌ Error: talosctl is not installed"
    echo "Install with: brew install siderolabs/tap/talosctl"
    exit 1
fi

# Check if talosconfig exists
if [ ! -f "$TALOSCONFIG" ]; then
    echo "❌ Error: Talos config not found at $TALOSCONFIG"
    echo "Run 'make tf-apply' first to provision the cluster"
    exit 1
fi

# Get schematic ID and version from Terraform
echo "📋 Getting cluster configuration from Terraform..."
cd "$TERRAFORM_DIR"

SCHEMATIC_ID=$(terraform output -raw talos_schematic_id 2>/dev/null || echo "")
TALOS_VERSION=$(terraform output -raw talos_version 2>/dev/null || echo "")

if [ -z "$SCHEMATIC_ID" ] || [ -z "$TALOS_VERSION" ]; then
    echo "❌ Error: Could not get schematic ID or version from Terraform"
    echo "Ensure these outputs are defined in your Terraform configuration"
    exit 1
fi

IMAGE="factory.talos.dev/installer/${SCHEMATIC_ID}:${TALOS_VERSION}"
echo "🖼️  Image: $IMAGE"
echo ""

# Get node IPs from Terraform
CONTROL_PLANE_NODES=$(terraform output -json control_plane_nodes | jq -r '.[]' 2>/dev/null || echo "")
WORKER_NODES=$(terraform output -json worker_nodes | jq -r '.[]' 2>/dev/null || echo "")

if [ -z "$CONTROL_PLANE_NODES" ]; then
    echo "❌ Error: No control plane nodes found"
    exit 1
fi

echo "🎯 Control Plane Nodes:"
echo "$CONTROL_PLANE_NODES" | while read -r node; do echo "  - $node"; done
echo ""

if [ -n "$WORKER_NODES" ]; then
    echo "🎯 Worker Nodes:"
    echo "$WORKER_NODES" | while read -r node; do echo "  - $node"; done
    echo ""
fi

# Check if running in CI or if AUTO_APPROVE is set
if [ "${CI:-false}" = "true" ] || [ "${AUTO_APPROVE:-false}" = "true" ]; then
    echo "🤖 Running in CI mode - auto-approving upgrade"
else
    # Confirm upgrade interactively
    echo "⚠️  This will upgrade all nodes to: $IMAGE"
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

export TALOSCONFIG="$(pwd)/output/talosconfig"

# Upgrade control plane nodes first
echo ""
echo "🔄 Upgrading control plane nodes..."
echo "$CONTROL_PLANE_NODES" | while read -r node; do
    echo "  Upgrading $node..."
    talosctl upgrade --nodes "$node" --image "$IMAGE" --preserve || {
        echo "❌ Failed to upgrade $node"
        exit 1
    }
    echo "  ✅ Upgrade initiated for $node"
    echo "  ⏳ Waiting 60s before next node..."
    sleep 60
done

# Upgrade worker nodes
if [ -n "$WORKER_NODES" ]; then
    echo ""
    echo "🔄 Upgrading worker nodes..."
    echo "$WORKER_NODES" | while read -r node; do
        echo "  Upgrading $node..."
        talosctl upgrade --nodes "$node" --image "$IMAGE" --preserve || {
            echo "❌ Failed to upgrade $node"
            exit 1
        }
        echo "  ✅ Upgrade initiated for $node"
        echo "  ⏳ Waiting 60s before next node..."
        sleep 60
    done
fi

echo ""
echo "✅ All upgrades initiated successfully!"
echo ""
echo "Monitor the upgrade with:"
echo "  export TALOSCONFIG=$TALOSCONFIG"
echo "  talosctl health"
