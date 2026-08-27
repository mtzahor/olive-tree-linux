#!/bin/sh

set -eu

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
export PATH

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

UEFI_DIR="$ROOT/build/uefi"
DISK_IMAGE="$UEFI_DIR/olive-tree.img"
GRUB_EFI="$UEFI_DIR/BOOTX64.EFI"
GRUB_CONFIG="$ROOT/boot/grub.cfg"

KERNEL="$ROOT/build/bzImage"
INITRAMFS="$ROOT/build/initramfs.cpio.gz"

ESP_OFFSET=1048576

if [ ! -f "$KERNEL" ]; then
    echo "Error: kernel has not been built." >&2
    exit 1
fi

if [ ! -f "$INITRAMFS" ]; then
    echo "Error: initramfs has not been built." >&2
    exit 1
fi

echo "Creating UEFI disk image..."

rm -rf "$UEFI_DIR"
mkdir -p "$UEFI_DIR"

dd if=/dev/zero \
    of="$DISK_IMAGE" \
    bs=1M \
    count=128 \
    status=none

sgdisk -o "$DISK_IMAGE"

sgdisk \
    -n 1:2048:0 \
    -t 1:ef00 \
    -c 1:"Olive Tree EFI" \
    "$DISK_IMAGE"

echo "Formatting EFI System Partition..."

mkfs.fat \
    -F 32 \
    --offset=2048 \
    "$DISK_IMAGE"

echo "Building GRUB EFI loader..."

grub-mkstandalone \
    --format=x86_64-efi \
    --modules="part_gpt fat linux search search_fs_file efi_gop" \
    --output="$GRUB_EFI" \
    "boot/grub/grub.cfg=$GRUB_CONFIG"


echo "Installing Olive Tree boot files..."

mmd -i "$DISK_IMAGE@@$ESP_OFFSET" ::/EFI
mmd -i "$DISK_IMAGE@@$ESP_OFFSET" ::/EFI/BOOT

mcopy \
    -i "$DISK_IMAGE@@$ESP_OFFSET" \
    "$GRUB_EFI" \
    ::/EFI/BOOT/BOOTX64.EFI

mcopy \
    -i "$DISK_IMAGE@@$ESP_OFFSET" \
    "$KERNEL" \
    ::/bzImage

mcopy \
    -i "$DISK_IMAGE@@$ESP_OFFSET" \
    "$INITRAMFS" \
    ::/initramfs.cpio.gz

echo "UEFI image built successfully:"
ls -lh "$DISK_IMAGE"
