#!/usr/bin/env bash
#
# Enclave OS — build the ISO from a non-Arch host (e.g. WSL Ubuntu) using the
# official Arch Linux container. Needs Docker (or Podman) with privileged mode,
# because mkarchiso mounts images and uses loop devices.
#
# Usage (from WSL Ubuntu, with Docker installed):
#   scripts/build-iso-docker.sh [--output DIR] [--keep-work]
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd -- "$SCRIPT_DIR/.." && pwd)"

if command -v docker >/dev/null 2>&1; then
  RUNNER=docker
elif command -v podman >/dev/null 2>&1; then
  RUNNER=podman
else
  echo "error: need docker or podman installed (Docker Desktop + WSL integration, or 'sudo apt install docker.io')." >&2
  exit 1
fi

echo "[enclave] building inside archlinux container via $RUNNER …"
exec "$RUNNER" run --rm --privileged \
  -e ENCLAVE_WORK=/tmp/enclave-build \
  -v "$REPO:/enclave" -w /enclave \
  archlinux:latest \
  bash -c 'pacman -Syu --noconfirm --needed archiso git base-devel sudo sassc librsvg plymouth && exec bash scripts/build-iso.sh "$@"' \
  _ "$@"
