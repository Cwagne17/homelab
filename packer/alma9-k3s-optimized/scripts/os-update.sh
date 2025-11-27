#!/bin/bash
# =============================================================================
# OS Update and Base Configuration Script
#
# This script is run by Packer during image provisioning to:
#   - Apply all system updates
#   - Configure timezone and locale
#   - Install essential tooling
#   - Optimize system settings for k3s
#
# Why these actions:
#   - Updates ensure security patches are applied
#   - Timezone consistency aids log correlation
#   - Base tools support administration and debugging
#   - Kernel parameters optimize container workloads
#
# Refs: Req 1.3
# =============================================================================

set -euo pipefail

echo "==> Starting OS update and configuration..."

# -----------------------------------------------------------------------------
# System Updates
# -----------------------------------------------------------------------------

echo "==> Applying system updates..."
dnf update -y

echo "==> Cleaning dnf cache..."
dnf clean all

# -----------------------------------------------------------------------------
# Timezone Configuration
# -----------------------------------------------------------------------------

echo "==> Configuring timezone to UTC..."
timedatectl set-timezone UTC
timedatectl set-ntp true

# Ensure chrony is running for NTP
systemctl enable chronyd
systemctl start chronyd

# -----------------------------------------------------------------------------
# Locale Configuration
# -----------------------------------------------------------------------------

echo "==> Configuring locale..."
localectl set-locale LANG=en_US.UTF-8

# -----------------------------------------------------------------------------
# Essential Tooling
# -----------------------------------------------------------------------------

echo "==> Installing additional tools..."
dnf install -y \
    bash-completion \
    bind-utils \
    curl \
    ethtool \
    git \
    htop \
    iotop \
    jq \
    lsof \
    net-tools \
    nmap-ncat \
    policycoreutils-python-utils \
    psmisc \
    rsync \
    strace \
    sysstat \
    tcpdump \
    tmux \
    vim-enhanced \
    wget \
    yum-utils

# -----------------------------------------------------------------------------
# Kernel Parameter Optimization for k3s
# -----------------------------------------------------------------------------

echo "==> Configuring kernel parameters for k3s..."

cat > /etc/sysctl.d/99-k3s.conf <<EOF
# Network settings for Kubernetes
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1

# Increase inotify watches for container workloads
fs.inotify.max_user_instances = 1024
fs.inotify.max_user_watches = 524288

# Increase file descriptor limits
fs.file-max = 2097152

# Network tuning
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# Memory settings
vm.max_map_count = 262144
EOF

# Load br_netfilter module for bridge settings
modprobe br_netfilter
echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf

# Apply sysctl settings
sysctl --system

# -----------------------------------------------------------------------------
# Disable Swap (required for Kubernetes)
# -----------------------------------------------------------------------------

echo "==> Disabling swap..."
swapoff -a
sed -i '/swap/d' /etc/fstab

# -----------------------------------------------------------------------------
# Firewall Configuration (disabled for k3s, use NetworkPolicy instead)
# -----------------------------------------------------------------------------

echo "==> Configuring firewall..."
# k3s manages its own iptables rules; firewalld can conflict
# Disable firewalld and rely on k3s network policies
systemctl disable firewalld || true
systemctl stop firewalld || true

# -----------------------------------------------------------------------------
# Clean Up
# -----------------------------------------------------------------------------

echo "==> Cleaning up..."
dnf clean all
rm -rf /var/cache/dnf/*

echo "==> OS update and configuration completed successfully."
