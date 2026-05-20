#!/usr/bin/env bash
set -euo pipefail

VM_NAME=${VM_NAME:-ubuntu-intel}
IMAGE=${IMAGE:-ubuntu:noble}
ARCH=${ARCH:-amd64}

if ! command -v orb >/dev/null 2>&1; then
  echo "[ERROR] orb command not found. Install or open OrbStack first."
  exit 1
fi

if orb list | awk '{print $1}' | grep -qx "$VM_NAME"; then
  echo "[INFO] VM already exists: $VM_NAME"
else
  echo "[INFO] Creating OrbStack VM..."
  orb create --arch "$ARCH" "$IMAGE" "$VM_NAME"
fi

echo "[INFO] Starting shell..."

orb -m "$VM_NAME" sudo bash -lc 'apt update && apt install -y git && git clone https://github.com/PBK98/Linux-Monitoring.git'

orb shell -m "$VM_NAME" sudo -i
