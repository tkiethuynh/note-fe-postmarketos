# postmarketOS for Samsung Galaxy Note FE (`samsung-gracerlte`)

Turn a **Samsung Galaxy Note FE (`SM-N935F` / `FD` / `S` / `K` / `L` — Exynos 8890)** into a Linux server or lightweight pocket Linux device running **postmarketOS (Alpine `edge`)** with a recompiled **Linux `3.18.140`** kernel supporting **Docker**, **`nftables`**, **`Btrfs` / `NFS` / `CIFS`**, and **USB-Serial** adapters.

> [!WARNING]
> **Exynos 8890 models only** (`SM-N935F`, `SM-N935FD`, `SM-N935S`, `SM-N935K`, `SM-N935L`). Qualcomm Snapdragon variants (`SM-N9350`) are **not** supported.

---

## Hardware Support Status

| Component | Status | Notes |
|---|---|---|
| **CPU / RAM / Storage** | Working | 8-core Exynos 8890 (`aarch64`), `3.7 GiB` RAM, UFS storage (`~52.6 GiB` `/mnt/data`) |
| **Wi-Fi (`bcmdhd` / BCM4359)** | Working | 2.4 GHz & 5 GHz (`433 MBit/s`), factory MAC from `/efs` (`ro`), powersave disabled |
| **USB OTG / Gadget (`rndis0`)** | Working | `172.16.42.1/24` + `unudhcpd` fallback for cable SSH |
| **Docker & `nftables`** | Working | Built-in `overlayfs`, `cgroupfs` v1, `NF_TABLES` + `NFT_*`, `MACVLAN`, `VXLAN`, `IP_VS` |
| **Filesystems & USB Serial** | Working | `Btrfs`, `NFS v3/v4`, `CIFS`, `FTDI`, `PL2303`, `CH341`, `CP210x`, `USB_ACM` |
| **Display (`/dev/fb0`) & Touch / S-Pen** | Works (fbdev) | Intentionally blanked in headless mode; supports X11 UIs (`xfce4`, `lxqt`, `sxmo`) |
| **Audio (ALSA) & Bluetooth** | Exposed | `Lucky CS47L91` sound card & `bcm4359` BT (`rfkill`) present; needs UCM / `brcm_patchram_plus` |
| **Camera (`fimc-is`)** | Not working | Requires Android HAL; `udev` `v4l_id` must be masked (`60-persistent-v4l.rules -> /dev/null`) to prevent boot panic |
| **Cellular Modem (LTE/Calls)** | Not working | Requires Samsung proprietary Android `cbd` + `libsec-ril.so` (use **Ubuntu Touch** if you need a daily-driver phone) |
| **3D GPU Acceleration (Wayland)** | Not working | No open-source Mali-T880 driver on 3.18; X11 runs smoothly on CPU |

---

## Repository Layout

```text
.
├── kernel/
│   ├── config-samsung-gracerlte.aarch64   # Linux 3.18.140 config (Docker + nftables + homelab extras)
│   └── Dockerfile                         # Ubuntu 18.04 cross-compile env (gcc-5 aarch64 + armhf compat vDSO)
├── scripts/
│   └── build-kernel.sh                    # Clones UBports 3.18.140 source and compiles Image (and boot.img)
└── port/
    ├── device-samsung-gracerlte/          # postmarketOS device package + headless/Wi-Fi scripts
    └── linux-samsung-gracerlte/           # postmarketOS kernel package recipe
```

---

## 1. Rebuilding the `3.18.140` Kernel

This kernel is built from UBports' Exynos 8890 downstream tree (`halium-11.0-4.2-bt-focal`, commit [`e697e3acd8b23f3e5a7ee2b9b23e766491430f8a`](https://gitlab.com/ubports/porting/community-ports/android11/samsung-galaxy-s7/kernel-samsung-universal8890/-/commit/e697e3acd8b23f3e5a7ee2b9b23e766491430f8a)) with `# CONFIG_MODULES is not set` (monolithic kernel — no `/lib/modules` needed).

```bash
./scripts/build-kernel.sh
```

This produces `kernel/Image`. If you also place your device's `dt.img` and `ramdisk.cpio.gz` into `kernel/`, the script automatically packs `kernel/boot-pmos-docker.img` using `mkbootimg_modified` with Samsung's required offsets (`second_offset=0xf0000000`) and `SEANDROIDENFORCE` footer, and verifies it fits inside the `40 MiB` (`41,943,040` bytes) `BOOT` partition.

---

## 2. Building a Full Image with `pmbootstrap`

1. Initialize `pmbootstrap` (choose `edge` channel, `console` UI, and any placeholder device initially, or copy the port in first):
   ```bash
   pmbootstrap init
   ```
2. Copy the port packages into your `pmaports` tree (`testing`):
   ```bash
   PMAPORTS="$(pmbootstrap config aports)"
   cp -r port/device-samsung-gracerlte "$PMAPORTS/device/testing/"
   cp -r port/linux-samsung-gracerlte "$PMAPORTS/device/testing/"
   ```
3. Add the kernel binary (`kernel/Image` from step 1), `dt.img` (extracted from your device's `boot.img`), and `gracerlte-firmware.tar.gz` (see section 3), then update checksums:
   ```bash
   cp kernel/Image "$PMAPORTS/device/testing/linux-samsung-gracerlte/Image"
   cp /path/to/dt.img "$PMAPORTS/device/testing/linux-samsung-gracerlte/dt.img"
   cp /path/to/gracerlte-firmware.tar.gz "$PMAPORTS/device/testing/device-samsung-gracerlte/"

   pmbootstrap checksum linux-samsung-gracerlte
   pmbootstrap checksum device-samsung-gracerlte
   ```
4. Select `samsung-gracerlte` (`pmbootstrap init`) and build/install:
   ```bash
   pmbootstrap build linux-samsung-gracerlte device-samsung-gracerlte
   pmbootstrap install --no-fde
   ```

---

## 3. Proprietary Firmware Requirement

Wi-Fi (`bcm4359`) requires Samsung/Broadcom firmware blobs from `/vendor/firmware` and `/vendor/etc/wifi` (not redistributed in this git repo). Extract them from your device's stock Android or Ubuntu Touch `/vendor` partition into `port/device-samsung-gracerlte/gracerlte-firmware.tar.gz` (containing `vendor/firmware/...` and `vendor/etc/wifi/...`) before building with `pmbootstrap`.

---

## 4. Post-Install Notes (Docker + Headless)

### Docker on Linux 3.18 (`cgroupfs` v1)
Modern OpenRC defaults to `unified` (cgroup v2), which Linux 3.18 does not support. Switch `/etc/rc.conf` to `legacy` mode:

```sh
sed -i 's/^#rc_cgroup_mode="unified"/rc_cgroup_mode="legacy"/; s/^#rc_controller_cgroups="YES"/rc_controller_cgroups="YES"/' /etc/rc.conf
rc-update add cgroups default
rc-update add docker default
```

Store Docker data on the `~52 GB` userdata partition (`/mnt/data/docker`) by adding `/etc/docker/daemon.json`:

```json
{
  "data-root": "/mnt/data/docker"
}
```

### Known 3.18 / postmarketOS Quirks Handled
1. **Prevent `v4l_id` camera kernel panic:** `/etc/udev/rules.d/60-persistent-v4l.rules -> /dev/null`
2. **Prevent `bcmdhd` Wi-Fi latency spikes:** `/etc/NetworkManager/conf.d/wifi-powersave.conf` + `/etc/NetworkManager/dispatcher.d/99-wifi-no-powersave`
3. **2 GB `lz4` ZRAM + OLED blanking + `stay-awake`:** `port/device-samsung-gracerlte/gracerlte-headless.start`
4. **`nftables` boot service:** Leave OpenRC's `nftables` service disabled if using postmarketOS's default `/etc/nftables.nft` (which uses post-3.18 `nft` syntax); Docker and Tailscale manage `nf_tables` directly via netlink.

---

## Credits & License
* Kernel source: [UBports `kernel-samsung-universal8890`](https://gitlab.com/ubports/porting/community-ports/android11/samsung-galaxy-s7/kernel-samsung-universal8890) (GPL-2.0)
* Boot image tool: [UBports `mkbootimg_modified`](https://gitlab.com/ubports/porting/community-ports/android11/samsung-galaxy-s7/samsung-exynos8890/-/tree/focal/mkbootimg_modified)
* Port recipes & scripts in this repository: MIT License
