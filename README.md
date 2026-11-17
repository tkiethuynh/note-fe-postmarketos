# postmarketOS for Samsung Galaxy Note FE (`samsung-gracerlte`)

[![Build & Release Kernel](https://github.com/tkiethuynh/note-fe-postmarketos/actions/workflows/release-kernel.yml/badge.svg)](https://github.com/tkiethuynh/note-fe-postmarketos/actions/workflows/release-kernel.yml)

Turn a **Samsung Galaxy Note FE (`SM-N935F` / `FD` / `S` / `K` / `L` — Exynos 8890)** into a **24/7 Linux server** (Docker, Compose, `nftables`, Tailscale, ZRAM, `Btrfs`/`NFS`/`CIFS`, USB-Serial) or a **pocket Linux X11 device** (Touchscreen + S-Pen + Audio + Wi-Fi) running **postmarketOS (Alpine `edge`)** on a recompiled **Linux `3.18.140`** kernel.

> [!WARNING]
> **Exynos 8890 models only** (`SM-N935F`, `SM-N935FD`, `SM-N935S`, `SM-N935K`, `SM-N935L`). Qualcomm Snapdragon variants (`SM-N9350`) are **not** supported.
> Always back up your `EFS`, `BOOT`, and `RECOVERY` partitions before flashing anything.

---

## Hardware Support Status

| Component | Status | Notes |
|---|---|---|
| **SoC / RAM / Storage** | Working | 8-core Exynos 8890 (`aarch64`), `3.7 GiB` RAM, UFS storage (`~52.6 GiB` userdata) |
| **Wi-Fi (`bcmdhd` / BCM4359)** | Working | 2.4 GHz & 5 GHz (`433 MBit/s`), factory MAC from `/efs` (`ro`), powersave disabled |
| **USB OTG / Gadget (`rndis0`)** | Working | `172.16.42.1/24` + `unudhcpd` DHCP fallback for instant USB SSH |
| **Docker & `nftables`** | Working | `overlayfs`, `cgroupfs` v1, `NF_TABLES` + `NFT_*`, `MACVLAN`, `VXLAN`, `IP_VS` |
| **Filesystems & USB Serial** | Working | `Btrfs`, `NFS v3/v4`, `CIFS` (SMB), `FTDI`, `PL2303`, `CH341`, `CP210x`, `USB_ACM` |
| **Display (`/dev/fb0`) & Touch / S-Pen** | Works (`fbdev`) | Intentionally blanked in headless mode; supports X11 UIs (`xfce4`, `lxqt`, `sxmo`) |
| **Audio (ALSA) & Bluetooth** | Exposed | `Lucky CS47L91` sound card & `bcm4359` BT (`rfkill`) present; needs UCM / `brcm_patchram_plus` |
| **Battery / Thermal / ZRAM** | Working | `~34–37 °C` idle, `stay-awake` wakelock, `2 GiB` `lz4` ZRAM |
| **Camera (`fimc-is`)** | Not working | Requires Android HAL; `udev` `v4l_id` must be masked (`60-persistent-v4l.rules -> /dev/null`) to prevent boot panic |
| **Cellular Modem (LTE/Calls)** | Not working | Requires Samsung proprietary Android `cbd` + `libsec-ril.so` (use **Ubuntu Touch** if you need a daily-driver phone) |
| **3D GPU Acceleration (Wayland)** | Not working | No open-source Mali-T880 driver on 3.18; X11 runs smoothly on CPU |

---

## Kernel Features (`3.18.140`)

Built from UBports' Exynos 8890 downstream tree (`halium-11.0-4.2-bt-focal`, commit [`e697e3acd8b23f3e5a7ee2b9b23e766491430f8a`](https://gitlab.com/ubports/porting/community-ports/android11/samsung-galaxy-s7/kernel-samsung-universal8890/-/commit/e697e3acd8b23f3e5a7ee2b9b23e766491430f8a)) with `# CONFIG_MODULES is not set` (monolithic kernel — no `/lib/modules` needed):

* **Containers / Docker:** `OVERLAY_FS`, `USER_NS`, `PID_NS`, `NET_NS`, `IPC_NS`, `UTS_NS`, `MEMCG`, `CFS_BANDWIDTH`, `CGROUP_FREEZER`, `CGROUP_DEVICE`, `CGROUP_CPUACCT`, `BLK_CGROUP`, `CFQ_GROUP_IOSCHED`, `POSIX_MQUEUE`, `VETH`, `BRIDGE`, `BRIDGE_NETFILTER`, `BRIDGE_VLAN_FILTERING`, `DUMMY`, `MACVLAN`, `VXLAN`, `IP_VS` (`TCP`/`UDP`/`RR`/`NFCT`)
* **Networking / Firewall:** `NF_TABLES`, `NF_TABLES_INET`, `NF_TABLES_IPV4`, `NF_TABLES_IPV6`, `NF_TABLES_ARP`, `NF_TABLES_BRIDGE`, all `NFT_*` expressions, `TUN`, `BPF`
* **Storage / Peripherals:** `BTRFS_FS`, `NFS_FS` (`v3`/`v4`), `CIFS`, `FUSE_FS`, `ZRAM` (`lz4`), `USB_ACM`, `USB_SERIAL` (`FTDI_SIO`, `PL2303`, `CH341`, `CP210X`)

### Hard Linux `3.18` Limits (Cannot Be Added by Kconfig)
* No **cgroup v2** (Docker uses `cgroupfs` v1)
* No **in-kernel WireGuard** (Tailscale uses userspace `wireguard-go`)
* No **`io_uring`** or modern **eBPF**
* `nf_tables` is 3.18-era (standard `nft`, Docker, and Tailscale rules work; newer 4.x/5.x features like `flowtable` or rule `comment` userdata are not supported)

---

## Repository Layout

```text
.
├── .github/workflows/release-kernel.yml   # CI workflow: builds & publishes kernel Image + SHA256SUMS
├── kernel/
│   ├── config-samsung-gracerlte.aarch64   # Linux 3.18.140 config
│   └── Dockerfile                         # Ubuntu 18.04 cross-compile env (gcc-5 aarch64 + armhf compat vDSO)
├── scripts/
│   └── build-kernel.sh                    # Clones 3.18.140 source and compiles Image (and boot.img)
└── port/
    ├── device-samsung-gracerlte/          # postmarketOS device package + headless/Wi-Fi scripts
    └── linux-samsung-gracerlte/           # postmarketOS kernel package recipe
```

---

## 1. Getting or Building the Kernel (`Image` / `boot.img`)

### Option A: Download Prebuilt `Image` from GitHub Releases
Download `Image` and `SHA256SUMS` from [**Releases**](https://github.com/tkiethuynh/note-fe-postmarketos/releases).

### Option B: Build from Source Locally
```bash
./scripts/build-kernel.sh
```
This produces `kernel/Image`. If you also place your device's `dt.img` and `ramdisk.cpio.gz` into `kernel/`, the script packs `kernel/boot-pmos-docker.img` using `mkbootimg_modified` with Samsung's required offsets (`second_offset=0xf0000000`, `os_version=11`, `os_patch_level=2022-06`, `cmdline="buildvariant=userdebug"`) and `SEANDROIDENFORCE` footer, and verifies it fits inside the `40 MiB` (`41,943,040` bytes) `BOOT` partition.

To flash a packed `boot-pmos-docker.img` from Download Mode:
```bash
heimdall flash --BOOT kernel/boot-pmos-docker.img
```
Or from a running rooted shell on the device (after backing up `/dev/sda7` first!):
```sh
sudo dd if=/dev/sda7 of=/mnt/data/boot-working.img bs=4M
sudo dd if=/mnt/data/boot-pmos-docker.img of=/dev/sda7 bs=4M && sync && sudo reboot
```

---

## 2. Building a Full OS Image with `pmbootstrap`

1. Initialize `pmbootstrap` (`edge` channel, `console` UI):
   ```bash
   pmbootstrap init
   ```
2. Copy the port packages into your `pmaports` tree (`testing`):
   ```bash
   PMAPORTS="$(pmbootstrap config aports)"
   cp -r port/device-samsung-gracerlte "$PMAPORTS/device/testing/"
   cp -r port/linux-samsung-gracerlte "$PMAPORTS/device/testing/"
   ```
3. Add `kernel/Image` (from Releases or `./scripts/build-kernel.sh`), `dt.img` (extracted from your device's `boot.img`), and `gracerlte-firmware.tar.gz` (see section 3), then update checksums:
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

## 3. Extracting Proprietary Firmware

Wi-Fi (`bcm4359`) requires Samsung/Broadcom firmware blobs from `/vendor/firmware` and `/vendor/etc/wifi` (not redistributed in this repo). Extract them from your device's stock Android or Ubuntu Touch `/vendor` partition into `gracerlte-firmware.tar.gz`:

```bash
tar -czf gracerlte-firmware.tar.gz vendor/firmware vendor/etc/wifi
```

---

## 4. Post-Install Setup (Headless Server & Docker)

### First Connection (USB RNDIS)
Plug the phone into your PC via USB and SSH to the gadget IP:
```bash
ssh user@172.16.42.1
```

### Connect Wi-Fi
```sh
nmcli dev wifi connect "<SSID>" password "<PASSWORD>"
```

### Enable Docker (`cgroupfs` v1 + `/mnt/data`)
Modern OpenRC defaults to `unified` (cgroup v2), which Linux `3.18` does not support. Switch `/etc/rc.conf` to `legacy`:
```sh
sudo apk add docker docker-cli-compose nftables
sudo sed -i 's/^#rc_cgroup_mode="unified"/rc_cgroup_mode="legacy"/; s/^#rc_controller_cgroups="YES"/rc_controller_cgroups="YES"/' /etc/rc.conf
sudo adduser "$USER" docker
sudo rc-update add cgroups default
sudo rc-update add docker default
```

Store Docker images/volumes on the `~52 GiB` userdata partition (`/dev/sda23` mounted at `/mnt/data`) via `/etc/docker/daemon.json`:
```json
{
  "data-root": "/mnt/data/docker"
}
```

### Included 3.18 / Headless Fixes
1. **Prevent `v4l_id` camera kernel panic:** `/etc/udev/rules.d/60-persistent-v4l.rules -> /dev/null`
2. **Prevent `bcmdhd` Wi-Fi latency spikes:** `/etc/NetworkManager/conf.d/wifi-powersave.conf` + `/etc/NetworkManager/dispatcher.d/99-wifi-no-powersave`
3. **2 GiB `lz4` ZRAM + OLED blanking + `stay-awake`:** `port/device-samsung-gracerlte/gracerlte-headless.start`
4. **Silence monolithic kernel `modules` warning:** `sudo rc-update del modules boot`
5. **Disable redundant `sleep-inhibitor`:** `sudo rc-update del sleep-inhibitor default`
6. **`nftables` boot service:** Leave OpenRC's `nftables` service disabled if using postmarketOS's default `/etc/nftables.nft` (which uses post-3.18 `nft` syntax); Docker and Tailscale manage `nf_tables` directly via netlink.

---

## 5. Want a Screen / Desktop UI Instead of Headless?

The OLED framebuffer (`/dev/fb0`), touchscreen (`sec_touchscreen`), and S-Pen (`sec_e-pen`) work out of the box. To use an X11 desktop (e.g. `xfce4`, `lxqt`, `sxmo`) instead of a dark headless server:
1. Remove the display-blanking lines (`fb0/blank`, `bl_power=4`, `brightness=0`) in `/etc/local.d/gracerlte-headless.start`
2. Install an X11 UI (`sudo apk add postmarketos-ui-xfce4` or `sxmo-de-dwm`) with `xf86-video-fbdev`

---

## Credits & License
* Kernel source: [UBports `kernel-samsung-universal8890`](https://gitlab.com/ubports/porting/community-ports/android11/samsung-galaxy-s7/kernel-samsung-universal8890) (GPL-2.0)
* Boot image tool: [UBports `mkbootimg_modified`](https://gitlab.com/ubports/porting/community-ports/android11/samsung-galaxy-s7/samsung-exynos8890/-/tree/focal/mkbootimg_modified)
* Port recipes & scripts in this repository: MIT License
