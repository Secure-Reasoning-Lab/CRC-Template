# =============================================================================
# CRC-Template Codex Finder Docker Bake Configuration
# =============================================================================
#
# Builds the CRS base image with Codex CLI and Python dependencies.
#
# Usage:
#   docker buildx bake prepare
#   docker buildx bake --push prepare   # Push to registry
# =============================================================================

variable "REGISTRY" {
  # Fail safely on accidental publish unless an owned registry is supplied.
  default = "localhost"
}

variable "VERSION" {
  default = "latest"
}

variable "CODEX_CLI_VERSION" {
  default = "0.121.0"
}

function "tags" {
  params = [name]
  result = [
    "${REGISTRY}/${name}:${VERSION}",
    "${REGISTRY}/${name}:latest",
    "${name}:latest"
  ]
}

# -----------------------------------------------------------------------------
# Groups
# -----------------------------------------------------------------------------

group "default" {
  targets = ["prepare"]
}

group "prepare" {
  targets = ["crs-finder-codex-base"]
}

# -----------------------------------------------------------------------------
# Base Image
# -----------------------------------------------------------------------------

target "crs-finder-codex-base" {
  context    = "."
  dockerfile = "oss-crs/base.Dockerfile"
  tags       = tags("crs-finder-codex-base")
  args = {
    CODEX_CLI_VERSION = CODEX_CLI_VERSION
  }
}
