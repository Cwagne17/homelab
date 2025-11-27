# =============================================================================
# Common Packer Configuration
#
# This file contains shared locals and configuration used across all Packer
# templates in this repository.
#
# Why shared configuration:
#   - Consistent image naming conventions
#   - Reusable timestamp and version formatting
#   - Common labels and metadata
#   - DRY (Don't Repeat Yourself) principle
#
# Refs: Req 1.5
# =============================================================================

# -----------------------------------------------------------------------------
# Shared Locals
# -----------------------------------------------------------------------------

locals {
  # Build timestamp for unique identification
  build_timestamp = formatdate("YYYYMMDD-hhmm", timestamp())

  # Image naming components
  # Format: alma{version}-k3-node-{arch}-{k3s-version}-v{distribution-release}
  # Example: alma9-k3-node-amd64-v1.28.5-v1

  # Default architecture (can be overridden per-template)
  default_arch = "amd64"

  # Common labels for all images
  common_labels = {
    "managed-by" = "packer"
    "project"    = "homelab"
    "repository" = "cwagne17/homelab"
  }

  # Description template
  description_template = "Built by Packer on %s. Part of homelab infrastructure."
}

# -----------------------------------------------------------------------------
# Usage Notes
# -----------------------------------------------------------------------------
#
# To use these locals in other templates, reference them directly:
#
#   template_description = format(local.description_template, local.build_timestamp)
#
# The locals are automatically available when Packer loads all *.pkr.hcl files
# in the directory.
#
# To reference from a subdirectory template, you may need to explicitly
# include this file or define similar locals in that template.
#
# -----------------------------------------------------------------------------
