Olive Tree Linux v0.0.3

Minimalist Linux distro with Rust init.

Version history:

- v0.0.5  Added a reproducible UEFI-bootable GPT disk image with GRUB and automatic QEMU UEFI boot.
- v0.0.4  Added reproducible, one-command builds of the kernel, BusyBox, Rust init, rootfs, and initramfs from source
- v0.0.3  PID 1 lifecycle and controlled shutdown
- v0.0.2  Rust PID 1 + mounts + process/session/console setup
- v0.0.1  Linux + BusyBox shell

Building and running: run in the cloned repository ./scripts/build.sh and then /scripts/run-qemu-uefi.sh or /scripts/run-qemu.sh to run without UEFI

## Build dependencies

Olive Tree Linux is currently built on Debian.

### System packages


sudo apt update

sudo apt install \
    build-essential \
    bc \
    bison \
    flex \
    libssl-dev \
    libelf-dev \
    libncurses-dev \
    cpio \
    xz-utils \
    bzip2 \
    wget \
    file \
    qemu-system-x86 \
    ovmf \
    grub-efi-amd64-bin \
    dosfstools \
    mtools \
    gdisk \

### Rust

Install Rust using rustup, then add the musl target:

rustup target add x86_64-unknown-linux-musl

A musl toolchain may also be required on Debian:

sudo apt install musl-tools
