#!/bin/bash
# =============================================================================
# OS Update Script
#
# This script applies all available system updates to ensure the golden image
# has the latest security patches and bug fixes.
#
# Refs: Req 1.3
# =============================================================================

set -euo pipefail

echo "==> Starting OS updates..."

# -----------------------------------------------------------------------------
# System Updates
# -----------------------------------------------------------------------------

echo "==> Applying system updates..."
dnf update -y

# -----------------------------------------------------------------------------
# Clean Up
# -----------------------------------------------------------------------------

echo "==> Cleaning dnf cache..."
dnf clean all
rm -rf /var/cache/dnf/*

echo "==> OS updates completed successfully."
