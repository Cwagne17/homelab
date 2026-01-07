#!/usr/bin/env bash
set -euo pipefail

# Talos Cluster Upgrade Script
# Upgrades all nodes in the cluster to a new Talos version

TOFU_DIR="terraform/envs/talos_cluster"
TALOSCONFIG="${TOFU_DIR}/output/talosconfig"

# Function to upgrade a single node
upgrade_node() {
    local hostname=$1
    local ip_address=$2
    
    echo "  📦 $hostname"
    echo "     IP: $ip_address"
    
    talosctl upgrade --nodes "$ip_address" --endpoints "$CONTROL_PLANE_ENDPOINT" --image "$IMAGE" --preserve || {
        echo "❌ Failed to upgrade $hostname"
        exit 1
    }
    echo "  ✅ Upgrade completed for $hostname"
}

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

# Get schematic ID and version from tofu
echo "📋 Getting cluster configuration from tofu..."
cd "$TOFU_DIR"

SCHEMATIC_ID=$(tofu output -raw talos_schematic_id 2>/dev/null || echo "")
TALOS_VERSION=$(tofu output -raw talos_version 2>/dev/null || echo "")

if [ -z "$SCHEMATIC_ID" ] || [ -z "$TALOS_VERSION" ]; then
    echo "❌ Error: Could not get schematic ID or version from OpenTofu"
    echo "Ensure these outputs are defined in your OpenTofu configuration"
    exit 1
fi

IMAGE="factory.talos.dev/installer/${SCHEMATIC_ID}:${TALOS_VERSION}"
echo "🖼️  Image: $IMAGE"
echo ""

# Build a map of nodes with hostname and IP address
echo "📋 Building node inventory..."
NODE_DETAILS=$(tofu output -json node_details)

# Extract control plane and worker IPs
CONTROL_PLANE_NODES=$(echo "$NODE_DETAILS" | jq -r '.[] | select(.machine_type == "controlplane") | .ip_address' | tr '\n' ' ')
WORKER_NODES=$(echo "$NODE_DETAILS" | jq -r '.[] | select(.machine_type == "worker") | .ip_address' | tr '\n' ' ')

if [ -z "$CONTROL_PLANE_NODES" ]; then
    echo "❌ Error: No control plane nodes found"
    exit 1
fi

# Get the first control plane IP to use as the endpoint for all operations
CONTROL_PLANE_ENDPOINT=$(echo "$NODE_DETAILS" | jq -r '.[] | select(.machine_type == "controlplane") | .ip_address' | head -n 1)

if [ -z "$CONTROL_PLANE_ENDPOINT" ]; then
    echo "❌ Error: No control plane IP found"
    echo "Run 'tofu refresh' to update VM IP addresses"
    exit 1
fi

echo "🎯 Using control plane endpoint: $CONTROL_PLANE_ENDPOINT"
echo ""

echo "🎯 Control Plane Nodes:"
echo "$NODE_DETAILS" | jq -r '.[] | select(.machine_type == "controlplane") | "  - \(.hostname) (IP: \(.ip_address), MAC: \(.mac_address))"'
echo ""

if [ -n "$WORKER_NODES" ]; then
    echo "🎯 Worker Nodes:"
    echo "$NODE_DETAILS" | jq -r '.[] | select(.machine_type == "worker") | "  - \(.hostname) (IP: \(.ip_address), MAC: \(.mac_address))"'
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
for ip_address in $CONTROL_PLANE_NODES; do
    # Get node details from map
    NODE_INFO=$(echo "$NODE_DETAILS" | jq -r --arg ip "$ip_address" '.[] | select(.ip_address == $ip)')
    HOSTNAME=$(echo "$NODE_INFO" | jq -r '.hostname')
    
    upgrade_node "$HOSTNAME" "$ip_address"
done

# Upgrade worker nodes
if [ -n "$WORKER_NODES" ]; then
    echo ""
    echo "🔄 Upgrading worker nodes..."
    for ip_address in $WORKER_NODES; do
        # Get node details from map
        NODE_INFO=$(echo "$NODE_DETAILS" | jq -r --arg ip "$ip_address" '.[] | select(.ip_address == $ip)')
        HOSTNAME=$(echo "$NODE_INFO" | jq -r '.hostname')
        
        upgrade_node "$HOSTNAME" "$ip_address"
    done
fi

echo ""
echo "✅ All upgrades initiated successfully!"
echo ""
echo "Monitor the upgrade with:"
echo "  export TALOSCONFIG=$TALOSCONFIG"
echo "  talosctl health"
