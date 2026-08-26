#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BUSYBOX="$ROOT/build/busybox"
ROOTFS="$ROOT/rootfs"

if [ ! -x "$BUSYBOX" ]; then
    echo "Error: BusyBox has not been built." >&2
    echo "Run ./scripts/build-busybox.sh first." >&2
    exit 1
fi

echo "Installing BusyBox into rootfs..."

cp "$BUSYBOX" "$ROOTFS/bin/busybox"
chmod +x "$ROOTFS/bin/busybox"

echo "Creating BusyBox applet links..."

"$BUSYBOX" --list | while read -r applet; do
    ln -sf busybox "$ROOTFS/bin/$applet"
done

echo "Building initramfs..."

mkdir -p "$ROOT/build"

cd "$ROOT/rootfs"

find . -print0 \
    | cpio --null -o --format=newc \
    | gzip -9 \
    > "$ROOT/build/initramfs.cpio.gz"

echo "Created:"
ls -lh "$ROOT/build/initramfs.cpio.gz"
