# =============================================================================
# CRC-Template Codex Patcher Docker Bake Configuration
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
  default = "0.144.3"
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
  targets = ["crs-patcher-codex-base"]
}

# -----------------------------------------------------------------------------
# Base Image
# -----------------------------------------------------------------------------

target "crs-patcher-codex-base" {
  context    = "."
  dockerfile = "oss-crs/base.Dockerfile"
  tags       = tags("crs-patcher-codex-base")
  args = {
    CODEX_CLI_VERSION = CODEX_CLI_VERSION
  }
}
