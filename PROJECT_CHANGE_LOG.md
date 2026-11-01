# PROJECT_CHANGE_LOG — KICKPI K4B 板级适配

记录本目录每一次改动：改了什么、为什么、结果。

**基线**：`Buildroot-YuzukiSBC` @ `377bdb4`（MangoPi MQ-Dual 板级配置，2023-07）
**依据**：`K4B_V1.2_20250213.pdf`（17 页原理图）+ KICKPI wiki

---

## 2026-11-01 初版

### 背景

K4B 官方只提供预编译 img，不含 SDK、BSP 源码与设备树。手上现成的 sun8iw20 buildroot 树是给 MangoPi MQ-Dual 的，直接烧到 K4B 上会出现：串口无输出、以太网不通、WiFi 找不到设备、屏不亮、按键无反应等问题。因此按原理图逐项重写板级 dts 与配置。

### 改动

1. **新增板级目录** `board/kickpi/k4b/`
   - `dts/linux/sun8i-kickpi-k4b-linux.dts`（902 行）：按 K4B V1.2 重定义全部外设
   - `dts/uboot/sun8i-kickpi-k4b-uboot.dts`：关闭 uboot 显示初始化（`disp_init_enable=0`、`lcd_used=0`）
   - `configs/linux/linux_kickpi_k4b_defconfig`：`console=ttyS3`，追加 CAN 全套配置
   - `configs/uboot/uboot_kickpi_k4b_defconfig`
   - `script/genimage.cfg`：dtb 名改为 `sun8i-kickpi-k4b-linux.dtb`
   - `script/env.cfg` + `script/post-build.sh`：覆盖通用 env 的 `console=ttyS0`（见下方坑 1）
   - `rootfs_overlay/etc/init.d/S99launcher`：LVGL launcher 自启

2. **CAN 支持** `patch/linux/0001-T113-CAN-controller-support.patch`
   - 新增 `sun4i_can.c`（T113 版，论坛调通方案）、`CAN_SUN8I` Kconfig/Makefile
   - 补 CCU：`CLK_BUS_CAN0/1`、`RST_BUS_CAN0/1`、`ccu-sun8iw20.c` 门控与复位
   - dts 内联 `can@02504000` / `can@02504400`

3. **dtb 改名补丁** `patch/linux/0002-rename-dtb-k4b.patch`
   - `arch/arm/boot/dts/Makefile` 的 dtb 目标名对齐板名

4. **buildroot 入口** `configs/kickpi_k4b_defconfig`
   - hostname `k4b`、getty `ttyS3`、kernel/uboot 路径全部指向 kickpi/k4b

### 关键差异（相对 MQ-Dual）

| 项 | MQ-Dual | K4B |
|---|---|---|
| 调试串口 | UART0 @ PE2/PE3 | **UART3 @ PB6/PB7** |
| WiFi | SDIO | **USB RTL8723BU** |
| CAN | 无 | CAN0 PB2/PB3、CAN1 PB4/PB5 |
| SPI1 | PB8-PB12 | **PD10-PD13** |
| TWI1 / TWI3 | PE14/15、PB6/7 | **PG8/9（触摸）、PG10/11（RTC）** |
| CPU 调压 | PWM3 调压，支持 DVFS | SY8088 固定 0.95V，**无 DVFS** |
| 喇叭 PA | — | PE11，**高电平工作** |
| 摄像头 / 电阻屏 / TV-OUT | 有 | **板上来没有，全部关闭** |

### 结果

- `make` 全量通过，`sdcard.img` = 320,868,352 B，dtb = 47,637 B
- dtb 反编译确认 `model = "KICKPI K4B (Allwinner T113-S3)"`
- 内核 `CONFIG_CAN=y` / `CAN_SUN8I=y` 生效，`sun4i_can.o` 生成，`vmlinux` 含 `allwinner,sunxi-t113-can`

### 踩过的坑

1. **通用 `env.cfg` 是 `console=ttyS0`** —— post-build 会把它 `mkenvimage` 进镜像，K4B 上从开机到登录**一个字都没有**，表现为"板子像砖"。修法是板级 `env.cfg` + 在通用 post-build 之后再覆盖一次。
2. **dtsi 依赖的引脚组不能删** —— `&sdc0` 引用 `sdc0_pins_d/e`，`&sdc1` 引用 `sdc1_pins_a/b`，即使节点 `disabled`，label 也必须存在，否则 dtc 报 phandle 错误且指向 dtsi，容易误判。
3. **vendor wiki 有错** —— wiki 写功放 SHDN 低有效，V1.2 原理图与 LY8006 手册是高有效。以原理图为准。
4. 交叉编译器用 buildroot 自己的 `output/host/bin/arm-linux-gnueabi-`，系统里没有 `arm-linux-gnueabihf-gcc`。

### 未做

- **上板验证**：本目录写于板子到手前，只做到编译 + dtb 级验证。
- **boot0/uboot 串口**：仍走 UART0（boot0 头部 `uart_port` 决定），K4B 上前 1~2 秒静默属正常。要让 uboot 也输出到 UART3 需改 boot0，收益低，暂缓。
- 默认屏参是 `s6e3fa0_1080p_video`（4-lane DSI），dts 内附 LVDS 1366×768 注释模板，换屏改 `lcd0` 段即可。
