#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

UTIL_LINUX_VERSION="$(cat "$ROOT_DIR/cgpt/util-linux-version")"

UTIL_LINUX_SOURCE="$ROOT_DIR/build/util-linux-$UTIL_LINUX_VERSION"
UTIL_LINUX_ARCHIVE="$ROOT_DIR/build/util-linux-$UTIL_LINUX_VERSION.tar.xz"

VBOOT_VERSION="$(cat "$ROOT_DIR/cgpt/vboot-version")"
VBOOT_SHA256="$(cat "$ROOT_DIR/cgpt/vboot-sha256")"

VBOOT_ARCHIVE="$ROOT_DIR/build/vboot-utils_$VBOOT_VERSION.orig.tar.xz"
VBOOT_SRC="$ROOT_DIR/build/vboot-utils-$VBOOT_VERSION"

BUILD_DIR="$ROOT_DIR/build/cgpt-static"
OUT="$ROOT_DIR/build/cgpt"

CC=musl-gcc

mkdir -p "$ROOT_DIR/build"


echo "==> Building static cgpt"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/cgpt" "$BUILD_DIR/core" "$BUILD_DIR/libuuid"

# ---------------------------------------------------------------------------
# Download and extract util-linux
# ---------------------------------------------------------------------------

if [ ! -s "$UTIL_LINUX_ARCHIVE" ]; then
    echo "==> Downloading util-linux $UTIL_LINUX_VERSION"

    wget \
        "https://www.kernel.org/pub/linux/utils/util-linux/v2.41/util-linux-$UTIL_LINUX_VERSION.tar.xz" \
        -O "$UTIL_LINUX_ARCHIVE"
else
    echo "==> Using existing util-linux archive"
fi

if [ ! -d "$UTIL_LINUX_SOURCE" ]; then
    echo "==> Extracting util-linux $UTIL_LINUX_VERSION"

    tar -xf "$UTIL_LINUX_ARCHIVE" -C "$ROOT_DIR/build"
else
    echo "==> Using existing util-linux source tree"
fi

# ---------------------------------------------------------------------------
# Download and extract vboot-utils
# ---------------------------------------------------------------------------

if [ ! -s "$VBOOT_ARCHIVE" ]; then
    echo "==> Downloading vboot-utils $VBOOT_VERSION"

    wget \
        "https://deb.debian.org/debian/pool/main/v/vboot-utils/vboot-utils_$VBOOT_VERSION.orig.tar.xz" \
        -O "$VBOOT_ARCHIVE"
else
    echo "==> Using existing vboot-utils archive"
fi

echo "$VBOOT_SHA256  $VBOOT_ARCHIVE" | sha256sum -c -

if [ ! -d "$VBOOT_SRC" ]; then
    echo "==> Extracting vboot-utils $VBOOT_VERSION"

    mkdir -p "$VBOOT_SRC"
    tar -xf "$VBOOT_ARCHIVE" -C "$VBOOT_SRC"
else
    echo "==> Using existing vboot-utils source tree"
fi

# ---------------------------------------------------------------------------
# Build static libuuid
# ---------------------------------------------------------------------------

echo "==> Building static libuuid"

cd "$UTIL_LINUX_SOURCE"

touch Makefile.in

if [ ! -f config.status ]; then
    CC="$CC" \
    CPPFLAGS="-idirafter /usr/include -idirafter /usr/include/x86_64-linux-gnu" \
    ./configure \
        --disable-shared \
        --enable-static \
        --disable-all-programs \
        --enable-libuuid
fi

make libuuid.la

cp .libs/libuuid.a "$BUILD_DIR/libuuid/"

mkdir -p "$BUILD_DIR/libuuid/include/uuid"
cp libuuid/src/uuid.h "$BUILD_DIR/libuuid/include/uuid/"
# ---------------------------------------------------------------------------
# Compile cgpt command implementation
# ---------------------------------------------------------------------------

echo "==> Compiling cgpt"

cd "$VBOOT_SRC"

CGPT_SRCS="
cgpt/cgpt.c
cgpt/cgpt_add.c
cgpt/cgpt_boot.c
cgpt/cgpt_common.c
cgpt/cgpt_create.c
cgpt/cgpt_edit.c
cgpt/cgpt_find.c
cgpt/cgpt_legacy.c
cgpt/cgpt_prioritize.c
cgpt/cgpt_repair.c
cgpt/cgpt_show.c
cgpt/cmd_add.c
cgpt/cmd_boot.c
cgpt/cmd_create.c
cgpt/cmd_edit.c
cgpt/cmd_find.c
cgpt/cmd_legacy.c
cgpt/cmd_prioritize.c
cgpt/cmd_repair.c
cgpt/cmd_show.c
"

for src in $CGPT_SRCS; do
    obj="$BUILD_DIR/cgpt/$(basename "${src%.c}").o"

    "$CC" \
        -I. \
        -Ifirmware/include \
        -Ifirmware/2lib/include \
        -Ifirmware/lib/cgptlib/include \
        -Ihost/include \
        -I"$BUILD_DIR/libuuid/include" \
        -idirafter /usr/include \
        -idirafter /usr/include/x86_64-linux-gnu \
        -c "$src" \
        -o "$obj"
done

# ---------------------------------------------------------------------------
# Compile the minimal GPT implementation required by cgpt
# ---------------------------------------------------------------------------

echo "==> Compiling GPT core"

for src in \
    firmware/lib/cgptlib/cgptlib.c \
    firmware/lib/cgptlib/crc32.c \
    firmware/lib/cgptlib/cgptlib_internal.c
do
    obj="$BUILD_DIR/core/$(basename "${src%.c}").o"

    "$CC" \
        -I. \
        -Ifirmware/include \
        -Ifirmware/2lib/include \
        -Ifirmware/lib/cgptlib/include \
        -idirafter /usr/include \
        -idirafter /usr/include/x86_64-linux-gnu \
        -c "$src" \
        -o "$obj"
done

# ---------------------------------------------------------------------------
# Compile OTL compatibility layer
# ---------------------------------------------------------------------------

echo "==> Compiling OTL cgpt compatibility layer"

"$CC" \
    -I. \
    -Ifirmware/include \
    -Ifirmware/2lib/include \
    -Ifirmware/lib/cgptlib/include \
    -c "$ROOT_DIR/cgpt/compat.c" \
    -o "$BUILD_DIR/compat.o"

# ---------------------------------------------------------------------------
# Link a completely static executable
# ---------------------------------------------------------------------------

echo "==> Linking static cgpt"

"$CC" -static \
    -o "$OUT" \
    "$BUILD_DIR"/cgpt/*.o \
    "$BUILD_DIR"/core/*.o \
    "$BUILD_DIR/compat.o" \
    "$BUILD_DIR/libuuid/libuuid.a"

echo "==> Built $OUT"
file "$OUT"
