#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KDIR="$ROOT_DIR/kernel"
SRC_DIR="$KDIR/src"
OUT_DIR="$KDIR/out"
BIN_DIR="$KDIR/bin"

KERNEL_REPO="https://gitlab.com/ubports/porting/community-ports/android11/samsung-galaxy-s7/kernel-samsung-universal8890.git"
KERNEL_BRANCH="halium-11.0-4.2-bt-focal"
KERNEL_COMMIT="e697e3acd8b23f3e5a7ee2b9b23e766491430f8a"
MKBOOTIMG_URL="https://gitlab.com/ubports/porting/community-ports/android11/samsung-galaxy-s7/samsung-exynos8890/-/raw/focal/mkbootimg_modified/mkbootimg"

mkdir -p "$SRC_DIR" "$OUT_DIR" "$BIN_DIR"

if [ ! -d "$SRC_DIR/.git" ]; then
  echo "[1/4] Cloning UBports Exynos 8890 kernel ($KERNEL_BRANCH)..."
  git clone --depth=1 --branch "$KERNEL_BRANCH" "$KERNEL_REPO" "$SRC_DIR"
fi

echo "[2/4] Building cross-compiler container..."
docker build -t exynos8890-kbuild:18.04 "$KDIR"

cp "$KDIR/config-samsung-gracerlte.aarch64" "$OUT_DIR/.config"

echo "[3/4] Compiling Linux 3.18.140 Image..."
docker run --rm -u "$(id -u):$(id -g)" \
  -v "$KDIR:/work" \
  exynos8890-kbuild:18.04 \
  bash -c '
    ln -sf /usr/bin/arm-linux-gnueabihf-gcc-5 /work/bin/arm-linux-gnueabihf-gcc
    export PATH="/work/bin:$PATH"
    make -C /work/src O=/work/out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabihf- CC=aarch64-linux-gnu-gcc-5 olddefconfig
    make -C /work/src O=/work/out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabihf- CC=aarch64-linux-gnu-gcc-5 -j"$(nproc)" Image
  '

cp "$OUT_DIR/arch/arm64/boot/Image" "$KDIR/Image"
ls -lh "$KDIR/Image"

if [ -f "$KDIR/ramdisk.cpio.gz" ] && [ -f "$KDIR/dt.img" ]; then
  echo "[4/4] Packing boot-pmos-docker.img (with SEANDROIDENFORCE)..."
  if [ ! -x "$KDIR/mkbootimg" ]; then
    curl -fsSL "$MKBOOTIMG_URL" -o "$KDIR/mkbootimg"
    chmod +x "$KDIR/mkbootimg"
  fi

  docker run --rm -u "$(id -u):$(id -g)" \
    -v "$KDIR:/work" \
    exynos8890-kbuild:18.04 \
    bash -c '
      /work/mkbootimg \
        --kernel /work/Image \
        --ramdisk /work/ramdisk.cpio.gz \
        --dt /work/dt.img \
        --pagesize 2048 \
        --base 0x10000000 \
        --kernel_offset 0x00008000 \
        --ramdisk_offset 0x01000000 \
        --second_offset 0xf0000000 \
        --tags_offset 0x00000100 \
        --os_version 11 \
        --os_patch_level 2022-06 \
        --cmdline "buildvariant=userdebug" \
        --output /work/boot-pmos-docker.img
      printf "SEANDROIDENFORCE" >> /work/boot-pmos-docker.img
    '

  SIZE=$(wc -c < "$KDIR/boot-pmos-docker.img")
  echo "boot-pmos-docker.img size: $SIZE bytes (BOOT limit: 41943040 bytes)"
  if [ "$SIZE" -gt 41943040 ]; then
    echo "ERROR: boot-pmos-docker.img exceeds 40 MiB BOOT partition!" >&2
    exit 1
  fi
else
  echo "[4/4] Kernel Image ready at kernel/Image."
  echo "To also pack boot.img, place ramdisk.cpio.gz and dt.img in kernel/ and re-run."
fi
