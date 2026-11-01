# KICKPI K4B 引脚分配分析（T113-S3）

> 依据：`doc/schematic/K4B_V1.2_20250213.pdf`（K4B V1.2，17 页）+ KICKPI wiki Pinout 图。
> 本文档是 SDK 板级 dts（`buildroot/board/kickpi/k4b/dts/linux/sun8i-kickpi-k4b-linux.dts`）的依据，两者对照阅读。
> 原理图关键页：**p7 SOC2（全板 GPIO 网络总表）**、p17（30Pin 座/DEBUG/RS485/RS232/KEY ADC）、p9（LCD）、p13（CAN/SD）、p14（RMII）、p15（RTC/LED）、p16（4G）、p12（USB HUB）。

## 一、板载资源速览

| 资源 | 实现 | 关键控制 |
|---|---|---|
| SoC | T113-S3（双 A7，128MB SiP DDR3） | — |
| 存储 | SPI NAND 512MB 或 eMMC 256MB（PC 组复用），TF 卡（PF 组） | SD 卡检测 **PF6** |
| 调试串口 | **UART3**（PB6 TX / PB7 RX），3pin 座 CON1，115200 | — |
| 以太网 | RMII + IP101GR 100M（RJ45 HR911105A） | PHY 复位 **PE13**，25M 时钟 PE10 |
| USB | USB0 OTG Type-C；USB1 → **GL850G HUB** → 2x Type-A + WiFi + 4G | OTG ID **PE12**，VBUS 开关 **PD20** |
| WiFi/BT | RTL8723BU（**USB 接口，非 SDIO**） | 无 GPIO 控制，即插即用 |
| 4G | mini-PCIE（EC20/EC200M） | 使能 **PG0**（PCIE_PWREN_H） |
| LCD | MIPI DSI 4-lane / 单路 LVDS 二选一（同一 FPC 座） | 见下 LCD 一节 |
| 音频 | 内置 codec：耳机（带检测）+ 麦克风 + 喇叭 PA | PA SHDN# **PE11**（低有效），HP-DET **PD15** |
| RTC | HYM8563TS（I2C @0x51） | TWI3 **PG10/PG11** |
| LED | 绿=电源直连；蓝=心跳 | **PG1**（WORKING_LEDEN_H） |
| 按键 | RST / FEL / **USER**（LRADC 键） | USER → **GPADC0**（ADKEY0，≈0.3V） |
| CPU 供电 | SY8088 固定 0.95V | **无 PWM 调压，不支持内核 DVFS** |

## 二、30Pin 扩展座 JP1（2x15，1.27mm）

`*` = 板上默认网络（M1 别名）。括号内为该脚其他可用复用。

| 脚 | SoC | 板上网络 | 说明 |
|---|---|---|---|
| 1 | — | VCC_3V3 | 电源（3.3V 域） |
| 2 | PG12 | I2S1-LRCK* | (TWI0_SCK / UART1_TX / PWM0) |
| 3 | PG5 | UART5_RX*（RS232） | (PWM4) |
| 4 | PG13 | I2S1-BCLK* | (TWI0_SDA / UART1_RX / PWM2) |
| 5 | PG4 | UART5_TX*（RS232） | (PWM5) |
| 6 | PG14 | I2S1-DIN0* | (TWI2_SCK / UART1_RTS) |
| 7 | PD14 | GPIO | (SPI1_HOLD / UART3_CTS) |
| 8 | PG15 | I2S1-DOUT0* | (TWI2_SDA / UART1_CTS) |
| 9 | — | GND | |
| 10 | PG6 | UART1_TX*（RS485） | (TWI2_SCK / PWM1) |
| 11 | — | USB_HOST1_DP | HUB 下行 Type-A（需自接） |
| 12 | PG7 | UART1_RX*（RS485） | (TWI2_SDA) |
| 13 | — | USB_HOST1_DM | HUB 下行 Type-A |
| 14 | — | GND | |
| 15/17 | — | VCC_5V0 | 电源 |
| 16 | PG2 | UART4_TX* | |
| 18 | PG3 | UART4_RX* | |
| 19 | PD12 | SPI1_MOSI* | (TWI0_SDA) |
| 20 | PD19 | PWM3* | |
| 21 | PD13 | SPI1_MISO* | (UART3_RTS) |
| 22 | PB3 | CAN0-RXD* | (TWI0_SCK / UART4_RX) |
| 23 | PD11 | SPI1_CLK* | (UART3_RX) |
| 24 | PB2 | CAN0-TXD* | (TWI0_SDA / UART4_TX) |
| 25 | PD10 | SPI1_CS* | (UART3_TX) |
| 26 | PB4 | CAN1-RXD* | (TWI1_SCK / UART5_TX) |
| 27 | PG11 | TWI3-SDA*（RTC 总线） | (I2S1_MCLK) |
| 28 | PB5 | CAN1-TXD* | (TWI1_SDA / UART5_RX) |
| 29 | PG10 | TWI3-SCK*（RTC 总线） | (PWM3 / IR_RX) |
| 30 | GPADC0 | ADC0（USER 键） | 键值≈0.3V |

注意：
- **TWI0 不在板上实际走线**（PG12/PG13 默认接 I2S1）；要扩 I2C 用 TWI3（27/29 脚，与板载 RTC 共总线）或把 2/4 脚复用为 TWI0（dts 里换 twi0_pins 并停 I2S1）。
- TWI1 = 板上 CTP 专用（PG8/PG9），不引出。
- TWI2 引脚（PG6/PG7）默认走 UART1（RS485）。

## 三、LCD（MIPI DSI / LVDS，原理图 p9）

| 信号 | SoC 引脚 | 说明 |
|---|---|---|
| DSI 4-lane | PD0~PD9 | D0P/N=PD0/1, D1P/N=PD2/3, CKP/N=PD4/5, D2P/N=PD6/7, D3P/N=PD8/9（mux4） |
| LCD_PWREN_H | **PD18** | LCD 5V 供电使能（WPM3407 PMOS） |
| LCD-RST | **PD21** | 屏复位 |
| 背光 PWM | **PD22**（PWM7） | 经三极管驱动背光 EN |
| CTP-SCK/SDA | **PG8/PG9**（TWI1） | 触摸 I2C |
| CTP-INT / CTP-RST | **PD17 / PD16** | 触摸中断/复位 |
| LCD0_ID | — | 屏识别 ADC |

LVDS 模式：PD0~PD9 复用为 lvds0（mux3），V0P~CKN 与 DSI lane 共脚。

## 四、与 MangoPi MQ-Dual 的关键差异（迁移清单）

| 项 | MQ-Dual | K4B | 动作 |
|---|---|---|---|
| 调试口 | UART0 @ PE2/PE3 (ttyS0) | **UART3 @ PB6/PB7 (ttyS3)** | 内核 cmdline、getty、uboot 后期输出均改 |
| CPU 稳压器 | PWM3 调压（PB0），支持 DVFS | SY8088 固定 0.95V | 删除 pwm regulator，**勿开 DVFS** |
| WiFi | SDIO（sdc1 + rfkill） | USB RTL8723BU | sdc1/rfkill/btlpm 全关 |
| BT | UART1 (btlpm PB4/PB5) | USB（RTL8723BU 集成） | btlpm 关 |
| CAN | 无 | CAN0 PB2/PB3、CAN1 PB4/PB5 | 需 T113 CAN 驱动（已打包为 patch） |
| SPI1 | PB8-PB12 | **PD10-PD13** | 引脚重定义 |
| TWI1 | PE14/PE15 | **PG8/PG9（CTP）** | 引脚重定义 |
| TWI3 | PB6/PB7 | **PG10/PG11（RTC）** | 引脚重定义 |
| GMAC | RMII PE0-9 | 同（PE13 复位、PE10 25M） | 保持，status=okay |
| 摄像头 | CSI + n5 传感器 | **未引出** | vind0/vinc 关闭 |
| TP 电阻触摸 | rtp | 无 | rtp 关闭 |
| 喇叭 PA | — | **PE11**（LY8006/AD51652 的 SHDN，高电平工作） | codec `gpio-spk` 设 ACTIVE_HIGH |
| USB OTG 检测 | PB6（ID） | **PE12**（USB-ID） | usbc0 改 |
| USB VBUS 开关 | PB3 | **PD20** | reg_usb1_vbus 改 |
| USER 键 | — | GPADC0（ADKEY0） | gpadc 单键 |
| 工作灯 | — | **PG1**（WORKING_LEDEN_H，高亮） | 已建 `gpio-leds` → `/sys/class/leds/k4b:work`，heartbeat |
| 4G 电源 | — | **PG0**（PCIE_PWREN_H，高有效） | 已建 `regulator-4g`，always-on |
| TV-OUT | tv0 开启 | 板上无 CVBS 座 | tv0 关闭 |

## 五、T113 CAN 驱动（本 SDK 已移植）

来源：全志在线论坛 liukia 调通方案（bbs.aw-ol.com/topic/1926），适配 sun8iw20。
补丁：`buildroot/board/kickpi/k4b/patch/linux/0001-T113-CAN-controller-support.patch`，内容：
- `drivers/net/can/sun4i_can.c`：T113 版驱动（compatible `allwinner,sunxi-t113-can`，含 reset 时序）
- `drivers/net/can/Kconfig` + `Makefile`：`CONFIG_CAN_SUN8I`
- `include/dt-bindings/clock/sun8iw20-ccu.h`：`CLK_BUS_CAN0=73 / CLK_BUS_CAN1=74`
- `include/dt-bindings/reset/sun8iw20-ccu.h`：`RST_BUS_CAN0=28 / RST_BUS_CAN1=29`
- `drivers/clk/sunxi-ng/ccu-sun8iw20.c`：CAN0/CAN1 门控（0x91C BIT4/5）与复位（BIT20/21）

dts：can0@02504000（IRQ GIC_SPI 21）、can1@02504400（IRQ GIC_SPI 22）。
内核已开 `CONFIG_CAN=y + CAN_RAW/CAN_BCM/CAN_DEV + CAN_SUN8I`。

用法：
```
ip link set can0 type can bitrate 500000
ip link set can0 up
candump can0 &
cansend can0 123#DEADBEEF
```

论坛已知坑：CAN0 与 USB1 Host 存在互相影响案例；低波特率（<100k）bittiming 报错；收发器供电电压不对会报 bus error。

## 六、其它引脚占用备忘

- PE12 = USB-ID（勿作 GPIO）；PE11 = PA-SHDN；PE10 = EPHY 25M 输出
- PD15 = HP-DET（耳机检测）；PD14 = 30Pin 脚 7 纯 GPIO；PD20 = USB VBUS 驱动
- PG0 = 4G 使能；PG1 = 蓝灯；PF6 = SD 卡检测；PB0/PB1 空闲
- SPI NAND / eMMC 在 PC 组二选一（出厂按版本贴），SD 启动不受影响
- USB HUB（GL850G）下行 4 路：Type-A x2、WiFi、4G mini-PCIE

## 七、构建与烧录

```
# WSL 内
cd /home/builder/t113/buildroot-yuzuki/buildroot
make                       # 已切到 K4B 板级配置
# 产物：output/images/sdcard.img
```

**烧录**：用 PhoenixCard（Android 模式选 "启动卡"）或 `dd if=sdcard.img of=/dev/sdX bs=1M`。K4B 的启动顺序 SD 优先，插卡上电即从卡启动。

**串口全链路（重要）**：K4B 的调试口是 **UART3（PB6/PB7，板上 3pin 座），115200 8N1**。

| 阶段 | 串口 | 说明 |
|---|---|---|
| boot0 / uboot | UART0（PE2/PE3）| boot0 头部的 `uart_port` 决定，本 SDK 的 boot0 用 UART0；**K4B 上这段没有输出是正常的，不是板子没启动** |
| 内核 / 用户态 | **UART3（ttyS3）** | dts 的 `&uart3` pinctrl 把 PB6/PB7 切成 uart3，`earlyprintk=sunxi-uart,0x02500c00` + `console=ttyS3,115200` 由板级 `env.cfg` 提供 |

板级 `env.cfg` 放在 `board/kickpi/k4b/script/env.cfg`，由 `board/kickpi/k4b/script/post-build.sh` 在通用 post-build 之后重新 `mkenvimage` 覆盖 —— 因为公共的 `board/allwinner-generic/sun8i-t113/bin/env.cfg` 是 MQ-Dual 的 `console=ttyS0`，直接用会导致 K4B 串口全程无输出（这是本次踩到的最大坑）。

Buildroot 无登录密码，回车直接进 shell。


## 八、本次 dts 落地清单（已全量编译 + dtb 反编译验证）

板级 dts：`buildroot/board/kickpi/k4b/dts/linux/sun8i-kickpi-k4b-linux.dts`（902 行）

| 外设 | 节点 / 引脚 | 状态 |
|---|---|---|
| 调试串口 | uart3 = PB6/PB7 | okay（ttyS3，cmdline `console=ttyS3`） |
| RS485 | uart1 = PG6/PG7 | okay |
| 30Pin 串口 | uart4 = PG2/PG3、uart5 = PG4/PG5（RS232） | okay |
| 串口 0/2 | uart0 PF2/PF4、uart2 | disabled |
| 触摸 | twi1 = PG8/PG9 + `ctp@14`（int=PD17, rst/wakeup=PD16） | okay |
| RTC | twi3 = PG10/PG11 + `hym8563@51` | okay |
| TWI0/TWI2 | — | disabled |
| SPI1 | PD11/12/13 + CS PD10，挂 spidev（`rohm,dh2228fv`） | okay |
| SPI0 | PC 组（=SPI NAND 版本才启用） | disabled |
| CAN0 / CAN1 | PB2/PB3、PB4/PB5；`can@02504000` / `can@02504400` | okay（驱动内置） |
| 以太网 | gmac0 RMII，phy-rst=PE13，use_ephy25m | okay |
| USB0 OTG | id=PE12，det-vbus=PD20，reg_usb1_vbus=PD20 | okay |
| USB1 Host | ehci1/ohci1（GL850G HUB → 2×Type-A + WiFi + 4G） | okay |
| 音频 | codec + sndcodec，`gpio-spk`=PE11 高有效；I2S1=PG12-15 | okay |
| 显示 | disp `screen0_output_type=1`(LCD)；lcd0 DSI 4-lane，PWREN=PD18、RST=PD21、背光 PWM7=PD22 | okay（默认 1080p panel，附 LVDS 模板注释） |
| SD 卡 | sdc0 PF 组 4-bit，cd-gpios=PF6 | okay |
| 板载 eMMC | sdc2 PC 组（与 SPI0 二选一） | disabled |
| GPADC | 单键 GPADC0（`key0_vol=300`, `key0_val=28`） | okay |
| LED / 4G | gpio-leds(PG1)、regulator-4g(PG0) | okay |
| 关闭项 | dmic/daudio0/spdif/vind/vinc0/vinc1/s_cir0/ir1/rtp/ledc/sdc1/tv0 | disabled |

编译验证结果：
- `make linux` + `make` 全程无错，`output/images/sdcard.img` = 320,868,352 字节
- dtb 47,637 字节，反编译确认 `model = "KICKPI K4B (Allwinner T113-S3)"`
- 内核确认 `CONFIG_CAN=y`、`CONFIG_CAN_SUN8I=y`，`drivers/net/can/sun4i_can.o` 已生成，vmlinux 内含 `allwinner,sunxi-t113-can` 字符串
- 产物已归档：`D:\t113-s3\images\k4b\`（sdcard.img / zImage / dtb / boot.img / boot_package.fex / u-boot-sun8iw20p1.bin）

