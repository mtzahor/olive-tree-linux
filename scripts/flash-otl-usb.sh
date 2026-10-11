#!/usr/bin/env bash
set -Eeuo pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
export PATH

readonly ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly IMAGE_DEFAULT="$ROOT/build/uefi/olive-tree.img"
readonly IMAGE_MAX_BYTES=134217728
readonly P2_START=262144
readonly P2_END=4456447
readonly P2_SECTORS=4194304

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    printf 'Usage: %s /dev/sdX [image-file]\n' "${0##*/}" >&2
    exit 2
fi

USB="$1"
IMAGE="${2:-$IMAGE_DEFAULT}"

[[ -b "$USB" ]] || die "Not a block device: $USB"
[[ -f "$IMAGE" ]] || die "Image not found: $IMAGE"

for tool in lsblk blockdev findmnt sgdisk partprobe blkid stat; do
    command -v "$tool" >/dev/null 2>&1 || die "Required tool not found: $tool"
done

[[ "$(lsblk -dnro TYPE "$USB" | tr -d '[:space:]')" == disk ]] ||
    die "$USB is not a whole disk"
[[ "$(lsblk -dnro RM "$USB" | tr -d '[:space:]')" == 1 ]] ||
    die "$USB is not marked removable"
[[ "$(lsblk -dnro TRAN "$USB" | tr -d '[:space:]')" == usb ]] ||
    die "$USB is not reported as a USB device"
[[ "$(sudo blockdev --getss "$USB")" == 512 ]] ||
    die "Expected 512-byte sectors on $USB"

image_bytes="$(stat -c '%s' "$IMAGE")"
(( image_bytes > 0 && image_bytes <= IMAGE_MAX_BYTES )) ||
    die "Image is ${image_bytes} bytes; maximum allowed is ${IMAGE_MAX_BYTES}. Refusing to risk partition 2."

disk_sectors="$(sudo blockdev --getsz "$USB")"
(( disk_sectors > P2_END )) || die "$USB is too small for the transfer partition"

PART1="${USB}1"
PART2="${USB}2"
[[ -b "$PART1" && -b "$PART2" ]] ||
    die "Expected existing partitions $PART1 and $PART2"

p2_start="$(lsblk -dnro START "$PART2" | tr -d '[:space:]')"
p2_sectors="$(sudo blockdev --getsz "$PART2")"
p2_type="$(sudo blkid -p -s TYPE -o value "$PART2" 2>/dev/null || true)"

[[ "$p2_start" == "$P2_START" ]] ||
    die "Partition 2 starts at ${p2_start:-unknown}, expected $P2_START"
[[ "$p2_sectors" == "$P2_SECTORS" ]] ||
    die "Partition 2 has $p2_sectors sectors, expected $P2_SECTORS"
[[ "$p2_type" == ext2 ]] ||
    die "Partition 2 is '${p2_type:-unknown}', expected ext2"

printf '\nTarget device:\n'
lsblk -o NAME,SIZE,MODEL,TRAN,TYPE,FSTYPE,LABEL,MOUNTPOINTS "$USB"
printf '\nImage: %s (%s bytes)\n' "$IMAGE" "$image_bytes"
printf 'Partition 2 will be restored at sectors %s-%s; it will not be formatted.\n\n' \
    "$P2_START" "$P2_END"

read -r -p "Type '$USB' to confirm: " confirmation
[[ "$confirmation" == "$USB" ]] || die "Confirmation did not match; nothing was flashed"

sudo -v

for part in "$PART1" "$PART2"; do
    while IFS= read -r target; do
        [[ -n "$target" ]] && sudo umount "$target"
    done < <(findmnt -rn -S "$part" -o TARGET)
done

printf 'Flashing image...\n'
sudo dd if="$IMAGE" of="$USB" bs=4M status=progress conv=fsync

printf 'Restoring GPT and transfer partition entry...\n'
sudo sgdisk -e "$USB"
sudo sgdisk -n "2:${P2_START}:${P2_END}" -t 2:8300 -c 2:OTL-TRANSFER "$USB"
sudo partprobe "$USB"
if command -v udevadm >/dev/null 2>&1; then
    sudo udevadm settle
fi

[[ -b "$PART2" ]] || die "Partition 2 did not reappear; do not format the disk"
p2_type="$(sudo blkid -p -s TYPE -o value "$PART2" 2>/dev/null || true)"
[[ "$p2_type" == ext2 ]] || die "Partition 2 does not read as ext2; do not format it"

sync
printf '\nVerified partition table and filesystems:\n'
sudo sgdisk -p "$USB"
lsblk -f "$USB"

if command -v eject >/dev/null 2>&1; then
    sudo eject "$USB"
    printf '\nUSB ejected.\n'
else
    printf '\nSafely eject the USB before unplugging it.\n'
fi
