# T113-S3 Linux Board Support: KICKPI K4B

> Native Buildroot board port for the **KICKPI K4B** (Allwinner T113-S3).

KICKPI ships this board as a **prebuilt image only** — no SDK, no BSP source tree, no device tree. Everything in this folder was reconstructed from the **K4B V1.2 schematic (17 pages)** plus the vendor wiki, then written as an upstream-style board directory that drops straight into an existing sun8iw20 Buildroot tree.

The reference SDK is **[Buildroot-YuzukiSBC](https://gitee.com/GloomyGhost/Buildroot-YuzukiSBC)**, which targets the MangoPi MQ-Dual. This port replaces that board's pin map with the K4B's real one — about 15 subsystems differ, and several of them will bite you silently if you assume the boards are compatible.

---

## 📋 Board at a glance

| Item | Implementation | Control line |
| :--- | :--- | :--- |
| SoC | T113-S3, dual Cortex-A7, 128 MB SiP DDR3 | — |
| Storage | SPI NAND 512 MB **or** eMMC 256 MB (shared PC group), plus TF card | SD detect **PF6** |
| Debug UART | **UART3** (PB6 TX / PB7 RX), 3-pin header, 115200 8N1 | — |
| Ethernet | RMII + IP101GR (100 M) | PHY reset **PE13**, 25 MHz out PE10 |
| USB | USB0 OTG Type-C; USB1 → **GL850G hub** → 2× Type-A + WiFi + 4G | OTG ID **PE12**, VBUS **PD20** |
| WiFi / BT | RTL8723BU — **USB, not SDIO** | none, plug and play |
| 4G | mini-PCIe (EC20 / EC200M) | power enable **PG0** |
| Display | MIPI DSI 4-lane **or** single LVDS, same FPC connector | PWREN **PD18**, RST **PD21**, BL PWM7 **PD22** |
| Touch | Capacitive, TWI1 | SDA/SCK **PG9/PG8**, INT **PD17**, RST **PD16** |
| Audio | On-chip codec: HP (with detect) + mic + speaker PA | PA SHDN **PE11** (active **high**), HP-DET **PD15** |
| RTC | HYM8563TS @ 0x51 | TWI3 **PG10/PG11** |
| LED | Green = power, blue = heartbeat | **PG1** |
| User key | LRADC key | **GPADC0**, ≈0.3 V |
| CPU rail | SY8088 fixed 0.95 V | **no DVFS support** |

---

## 📂 What's inside

```
buildroot/
├── configs/
│   └── kickpi_k4b_defconfig            # buildroot entry point (make kickpi_k4b_defconfig)
└── board/kickpi/k4b/
    ├── dts/linux/sun8i-kickpi-k4b-linux.dts     # full board DTS, 900+ lines
    ├── dts/uboot/sun8i-kickpi-k4b-uboot.dts     # U-Boot DTS (display init off)
    ├── configs/linux/linux_kickpi_k4b_defconfig # kernel config, CAN enabled
    ├── configs/uboot/uboot_kickpi_k4b_defconfig
    ├── patch/linux/0001-T113-CAN-controller-support.patch
    ├── patch/linux/0002-rename-dtb-k4b.patch
    ├── script/env.cfg                  # U-Boot env: console=ttyS3 (see below)
    ├── script/genimage.cfg
    ├── script/post-build.sh
    └── rootfs_overlay/etc/init.d/S99launcher
```

`docs/K4B_引脚分配分析.md` holds the full pin-by-pin analysis (Chinese) — the 30-pin header table, LCD pinout, and the complete MQ-Dual → K4B migration list.

---

## 🔌 Key pin assignments

| Function | Pins | Notes |
| :--- | :--- | :--- |
| Debug console | **PB6 / PB7** | UART3 → `ttyS3`, not `ttyS0` |
| RS485 | PG6 / PG7 | UART1 |
| RS232 | PG4 / PG5 | UART5 |
| 30-pin UART | PG2 / PG3 | UART4 |
| SPI1 | PD11 / PD12 / PD13 + CS PD10 | exposed on 30-pin header |
| **CAN0** | **PB2 / PB3** | needs the driver patch |
| **CAN1** | **PB4 / PB5** | needs the driver patch |
| I2S1 | PG12 / PG13 / PG14 / PG15 | 30-pin header |
| TWI1 (touch) | PG8 / PG9 | not on header |
| TWI3 (RTC) | PG10 / PG11 | free for your own I2C devices |
| DSI lanes | PD0 – PD9 | 4-lane, mux 4 |
| SD card | PF0 – PF5 | SDC0, 4-bit |
| eMMC / SPI NAND | PC0 – PC7 | factory fitted one or the other |
| PWM3 (header) | PD19 | 30-pin pin 20 |
| GPADC0 | — | user key, 30-pin pin 30 |

Header reference (JP1, 2×15 @ 1.27 mm) is in `docs/` pin by pin.

---

## ⚠️ The UART trap

Two separate things will make the board look dead on a serial console. Both are fixed here, but you should know why.

**1. The stock `env.cfg` points at the wrong UART.** The generic sun8i-t113 board in the SDK ships `console=ttyS0` and `earlyprintk=sunxi-uart,0x02500000`. On the K4B, UART0 is not wired to anything — the debug header is UART3. Flash an image built with the generic env and you get **zero output from power-on to login**, which looks exactly like a bricked board.

This port adds `board/kickpi/k4b/script/env.cfg` (`console=ttyS3` + `earlyprintk=sunxi-uart,0x02500c00`) and a `post-build.sh` that re-runs `mkenvimage` **after** the shared post-build script, so the generic file can't overwrite it.

**2. Boot0 logs to UART0 regardless.** The UART used before the kernel is picked from `uart_port` in the boot0 header, not from the DTS. The stock boot0 uses UART0, so the first 1–2 seconds of boot are silent on the K4B header — **this is expected, not a failure**. Kernel output starts at `earlyprintk`.

---

## 🚌 CAN support

T113 has two CAN controllers that the vendor BSP simply omits — there is no `sun4i_can.c` in this kernel tree. `0001-T113-CAN-controller-support.patch` adds the driver ported from the Allwinner community forum ([bbs.aw-ol.com/topic/1926](https://bbs.aw-ol.com/topic/1926), user *liukia*), along with the missing CCU gates and resets:

| Addition | Detail |
| :--- | :--- |
| `drivers/net/can/sun4i_can.c` | compatible `allwinner,sunxi-t113-can`, with reset assert/deassert sequencing |
| `Kconfig` / `Makefile` | `CONFIG_CAN_SUN8I` |
| `sun8iw20-ccu.h` (clock) | `CLK_BUS_CAN0=73`, `CLK_BUS_CAN1=74` |
| `sun8iw20-ccu.h` (reset) | `RST_BUS_CAN0=28`, `RST_BUS_CAN1=29` |
| `ccu-sun8iw20.c` | gates at `0x91C` BIT4/5, resets BIT20/21 |

Nodes are at `can@02504000` (IRQ 21) and `can@02504400` (IRQ 22). Kernel config already has `CONFIG_CAN=y`, `CAN_RAW`, `CAN_BCM`, `CAN_DEV`, `CAN_SUN8I`.

```sh
ip link set can0 type can bitrate 500000
ip link set can0 up
candump can0 &
cansend can0 123#DEADBEEF
```

Known quirks: bitrates below 100 k fail to compute bittiming on this driver; CAN0 and USB1 host have been reported to interfere; a transceiver powered from the wrong rail produces bus errors.

---

## 🛠️ Applying to the SDK

```sh
git clone https://gitee.com/GloomyGhost/Buildroot-YuzukiSBC.git
cd Buildroot-YuzukiSBC

# drop the board directory and the defconfig in place
cp -r /path/to/02-t113-k4b-board/buildroot/* buildroot/

cd buildroot
make kickpi_k4b_defconfig
make
```

Output lands in `output/images/`. The kernel tarball (`linux/1.0.0.tar.gz`, ~211 MB) is no longer on `sources.buildroot.net` — pre-seed your `DL_DIR` with a copy or the fetch step will 404.

### Flashing

```sh
# PhoenixCard: load sdcard.img, choose "startup card" mode
# or raw write:
sudo dd if=output/images/sdcard.img of=/dev/sdX bs=1M status=progress
```

The K4B boots from SD before eMMC/NAND, so a card with a valid image always takes precedence. Serial console: **PB6/PB7 at 115200**, no login password.

---

## ✅ Status

| Stage | State |
| :--- | :--- |
| DTS compiles | ✅ clean, `dtb` 47,637 bytes, decompiled to verify every node |
| Full Buildroot image | ✅ `sdcard.img` 320,868,352 bytes |
| CAN driver built in | ✅ `sun4i_can.o` linked, `allwinner,sunxi-t113-can` present in `vmlinux` |
| Boot on physical board | ⏳ pending — this port was written against the schematic, before the board was on the bench |

Corrections and board-tested reports are welcome via YouTube comments on the build video.

---

## 📝 Notes for anyone porting a sun8iw20 board

Three things cost the most time here; they'll cost you the same.

1. **Never trim pin groups the shared DTSI still references.** `&sdc0` pulls in `sdc0_pins_d` / `sdc0_pins_e` (uart0 + jtag muxes) and `&sdc1` pulls `sdc1_pins_a` / `sdc1_pins_b`, even when both nodes are `disabled`. Delete the group and `dtc` aborts with a phandle error that names the DTSI, not your board file.
2. **`env.cfg` is global.** It lives in the shared `board/allwinner-generic/<soc>/bin/` path, so one wrong `console=` breaks every board derived from it. Always override per board in post-build.
3. **The vendor wiki can be wrong.** It lists the speaker PA shutdown as active-low; the V1.2 schematic and the LY8006 datasheet say active-high. Read the schematic.

---

## 📜 Credits & licence

* SDK and sun8iw20 BSP: [YuzukiHD / Buildroot-YuzukiSBC](https://gitee.com/GloomyGhost/Buildroot-YuzukiSBC)
* T113 CAN driver: Allwinner community forum, user *liukia*
* Board port, DTS, schematic analysis: MakeCycle-Lab

MIT, excluding third-party assets.
