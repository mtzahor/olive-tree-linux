#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

IMAGE="$ROOT/build/uefi/olive-tree.img"
OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.fd"
OVMF_VARS_TEMPLATE="/usr/share/OVMF/OVMF_VARS_4M.fd"
OVMF_VARS="$ROOT/build/uefi/OVMF_VARS.fd"

if [ ! -f "$IMAGE" ]; then
    echo "Error: UEFI image has not been built." >&2
    echo "Run ./scripts/build.sh first." >&2
    exit 1
fi

echo "Starting Olive Tree Linux with UEFI..."

cp "$OVMF_VARS_TEMPLATE" "$OVMF_VARS"

qemu-system-x86_64 \
    -m 512M \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$OVMF_VARS" \
    -drive format=raw,file="$IMAGE" \
    -serial stdio \
    -device qemu-xhci \
