#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BUSYBOX="$ROOT/build/busybox"
ROOTFS="$ROOT/build/rootfs"
OVERLAY="$ROOT/rootfs-overlay"
OLIVE_INIT="$ROOT/build/olive-init"

echo "Creating root filesystem..."

rm -rf "$ROOTFS"

mkdir -p \
    "$ROOTFS/bin" \
    "$ROOTFS/dev" \
    "$ROOTFS/etc" \
    "$ROOTFS/proc" \
    "$ROOTFS/root" \
    "$ROOTFS/sbin" \
    "$ROOTFS/sys" \
    "$ROOTFS/tmp"

echo "Applying rootfs overlay..."

cp -a "$OVERLAY/." "$ROOTFS/"

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

if [ ! -x "$OLIVE_INIT" ]; then
    echo "Error: olive-init has not been built." >&2
    echo "Run ./scripts/build-init.sh first." >&2
    exit 1
fi

echo "Installing olive-init..."

cp "$OLIVE_INIT" "$ROOTFS/init"
chmod +x "$ROOTFS/init"

echo "Creating initramfs..."

(
    cd "$ROOTFS"

    find . -print0 \
        | cpio --null -ov --format=newc \
        | gzip -9 > "$ROOT/build/initramfs.cpio.gz"
)
