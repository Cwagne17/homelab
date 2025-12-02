#!/bin/bash
# =============================================================================
# Fetch AlmaLinux ISO Checksum
#
# This script fetches the official checksum for AlmaLinux ISOs from the
# repository and outputs it in the format needed for Packer.
#
# Usage:
#   ./scripts/fetch-alma-checksum.sh [VERSION] [ARCH]
#
# Examples:
#   ./scripts/fetch-alma-checksum.sh 9.5 x86_64
#   ./scripts/fetch-alma-checksum.sh 9.4 aarch64
#
# =============================================================================

set -euo pipefail

# Default values
VERSION="${1:-9.5}"
ARCH="${2:-x86_64}"
EDITION="minimal"

# Construct URLs
CHECKSUM_URL="https://repo.almalinux.org/almalinux/${VERSION}/isos/${ARCH}/CHECKSUM"
ISO_FILENAME="AlmaLinux-${VERSION}-${ARCH}-${EDITION}.iso"

echo "==> Fetching checksums for AlmaLinux ${VERSION} ${ARCH}..."
echo "==> URL: ${CHECKSUM_URL}"
echo ""

# Fetch and parse checksum file
CHECKSUM_LINE=$(curl -fsSL "${CHECKSUM_URL}" | grep -i "${ISO_FILENAME}" || true)

if [ -z "$CHECKSUM_LINE" ]; then
    echo "ERROR: Could not find checksum for ${ISO_FILENAME}"
    echo ""
    echo "Available ISOs:"
    curl -fsSL "${CHECKSUM_URL}" | grep "\.iso$" || echo "  (none found)"
    exit 1
fi

# Extract SHA256 hash
SHA256=$(echo "$CHECKSUM_LINE" | awk '{print $1}')

echo "==> Found checksum for ${ISO_FILENAME}:"
echo ""
echo "    sha256:${SHA256}"
echo ""
echo "==> Use in Packer configuration:"
echo ""
echo "    alma_iso_checksum = \"sha256:${SHA256}\""
echo ""
