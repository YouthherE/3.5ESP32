# 引脚分配表（GPIO Map）

> 基于当前代码实际生效配置梳理
> 生成时间：2026-09-12（2026-09-13 更新：新增无线投屏接收，RST 接 GPIO12）

---

## 1. 硬件平台

| 项目 | 值 |
|---|---|
| MCU | ESP32-S3（WROVER 模块，含 PSRAM） |
| 板型 | ESP32-S3-EYE |
| 屏幕 | 外接 3.5" ST7796 SPI LCD 480×320（LovyanGFX + LVGL，SPI3_HOST） |
| 串口 | USB-Serial-JTAG（`Serial.begin(115200)`） |
| 网络 | WiFi STA + AP 配网门户 + **无线投屏接收（TCP 8888）** |

---

## 2. 已用引脚总表（7 个）

| GPIO | 功能 | 信号 | 方向 | 依据 |
|---|---|---|---|---|
| 14 | LCD SCLK | SPI 时钟（SPI3） | 输出 | `lcd_display.cpp` `LCD_PIN_SCLK` |
| 13 | LCD MOSI | SPI 数据（SPI3） | 输出 | `lcd_display.cpp` `LCD_PIN_MOSI` |
| 11 | LCD DC | 数据/命令选择 | 输出 | `lcd_display.cpp` `LCD_PIN_DC` |
| 10 | LCD CS | SPI 片选 | 输出 | `lcd_display.cpp` `LCD_PIN_CS` |
| 15 | LCD 背光 BL | LEDC PWM（TIMER1/CH1，10kHz） | 输出 | `lcd_display.cpp` `LCD_PIN_BL` |
| 12 | LCD RST | 面板复位 | 输出 | `lcd_display.cpp` `LCD_PIN_RST` |
| 0 | 配网按钮（BOOT） | 运行时长按 3s 进配网 | 输入（上拉） | `CameraWebServer.ino` |

> LCD 复位（RST）现接 GPIO12。若不接线，需注释掉 `lcd_display.cpp` 顶部的 `#define LCD_PIN_RST 12`，
> 由面板自身复位电路负责（注意 `Panel_ST7796` 的初始化序列里没有软复位命令 SWRESET）。

---

## 3. 各模块引脚明细

### 3.1 LCD ST7796（6 个 GPIO，`lcd_display.cpp`）

| 信号 | GPIO | 备注 |
|---|---|---|
| SCLK | 14 | SPI3_HOST，`freq_write` 27MHz（花屏可降 20MHz，投屏提速可升 40MHz） |
| MOSI | 13 | SPI 数据（`pin_miso = -1`，只写不读） |
| DC | 11 | 数据/命令 |
| CS | 10 | SPI 片选 |
| RST | 12 | 由 MCU 复位（`LCD_PIN_RST 12`） |
| BL（背光） | 15 | LEDC_TIMER_1 / CHANNEL_1，10kHz，255 = 最亮 |

> 注意事项：
> - 外接屏**必须用 SPI3_HOST**（SPI2/FSPI 被 PSRAM 占用，用 SPI2 会白屏）；
> - 不要覆盖 `panel_width` / `panel_height`（`Panel_ST7796` 默认 320×480 竖屏，`setRotation(1)` 转横屏）；
> - 背光用 LEDC_TIMER_1/CH1（TIMER_0/CH0 预留给其他外设，避免冲突）；
> - 若屏幕白屏或花屏，优先核对本节引脚与实物接线是否一致；
> - 开机自检：`lcd_display.cpp` 的 `LCD_BOOT_TEST 1` 会让屏幕先闪 红→绿→蓝，跑通后可改 0 关闭。

### 3.2 配置按钮（1 个 GPIO）

| GPIO | 用途 | 行为 |
|---|---|---|
| 0 | 配网按钮（BOOT 键） | `INPUT_PULLUP`，**运行中**持续 LOW 超 3s → 清凭据 + 重启进 AP 配网 |

> ⚠️ GPIO0 是 download-mode strapping 引脚：**上电/复位瞬间拉低会进入烧录模式**，
> 因此只能在**固件运行后**长按触发配网。

---

## 4. 非 GPIO 资源占用

| 资源 | 占用者 |
|---|---|
| LEDC_TIMER_1 + CHANNEL_1 | LCD 背光 PWM（GPIO15） |
| SPI3_HOST | 外接 ST7796 LCD |
| SPI2_HOST | 板载 2.4" 屏（代码未初始化，但**物理焊接占用**，勿复用） |
| USB-Serial-JTAG | 串口日志（GPIO19/20 物理接 USB 口） |
| TCP 8888 | 无线投屏接收端（MJPEG over TCP，`cast_server.cpp`；PC 端用 `pc_cast.bat` 推流） |
| TCP 80 | 配网门户（仅 AP 模式下监听） |

---

## 5. 受限 / 保留引脚（不建议外接）

| GPIO | 原因 |
|---|---|
| 0 | strapping + 已用作配置按钮 |
| 3 | strapping（JTAG 信号源选择） |
| 45 | strapping（VDD_SPI 电压选择） |
| 46 | strapping（内部上拉，默认选择 flash 启动） |
| 19, 20 | USB D-/D+（USB 调试口物理占用） |
| 26 ~ 32 | SPI Flash / PSRAM（FSPI），WROVER 模块专用，**不可用** |
| 43, 44 | UART0 TX/RX（默认串口，项目走 USB CDC 时物理空闲，建议预留） |
| 36 ~ 42 | 板载 2.4" LCD（SPI2）物理占用 |

> ⚠️ 若在 IDE 里把 PSRAM 改为 **OPI PSRAM**（投屏提速时可能需要），
> GPIO33~37 会被 PSRAM 占用，第 6 节中的 33/34/35 届时不可用。

---

## 6. 自由引脚（可外接其他外设）

### 6.1 推荐优先使用（无保留、非 strapping）

| GPIO | 建议用途 | 备注 |
|---|---|---|
| 2 | GPIO/串口/传感器 | 可安全使用 |
| 33 | GPIO/ADC1 | 可安全使用（**开 OPI PSRAM 后不可用**） |
| 34 | GPIO/ADC1 | 可安全使用（**开 OPI PSRAM 后不可用**） |
| 35 | GPIO/ADC1 | 可安全使用（**开 OPI PSRAM 后不可用**） |
| 42 | GPIO | 板载屏区域内，但未被本项目占用 |
| 43 | UART0 TX | 走 USB CDC 时空闲，若想用 UART 需先确认 Serial 配置 |
| 44 | UART0 RX | 同上 |

### 6.2 可用但需谨慎

| GPIO | 注意事项 |
|---|---|
| 3 | 上电瞬间电平影响 JTAG 选择；接外设需保证上电默认电平（内部上拉） |
| 46 | 上电默认内部上拉（选择 flash 启动）；外接电路勿在上电时拉低 |
| 48 | 板载 WS2812 RGB LED；软件不驱动即可，但需注意上电默认状态 |

### 6.3 板载屏拆除后可复用（SPI2 区域）

| GPIO | 说明 |
|---|---|
| 36 ~ 41 | 若物理拆除/断开板载 2.4" LCD，可复用 |

> 自由引脚以**当前代码 + 芯片/板级约束**双重过滤得出；外接前请对照
> ESP32-S3-EYE 开发板原理图确认对应排针/焊盘是否确实引出。

---

## 7. 外接建议

1. **优先用 6.1 的 GPIO2**，干净无坑（33/34/35 在启用 OPI PSRAM 后会被占用）；
2. 外接 I2C 设备：任意两个空闲 GPIO 软件模拟即可（硬件 I2C 未占用，可配 GPIO33/34）；
3. 外接 ADC 传感器：GPIO33/34/35 均为 ADC1 通道；
4. 外接 UART：GPIO43/44（需改 `Serial` 或用 `HardwareSerial(1)` 映射）；
5. **避开**：0/3/45/46（strapping）、19/20（USB）、26-32（Flash/PSRAM）、36-41（板载屏）；
6. 若需新增外设，建议先在本表登记，避免与 LCD 冲突。

---

*本文档由代码扫描生成，与 `CameraWebServer.ino`、`lcd_display.cpp`、`cast_server.cpp`、`lv_conf.h` 保持同步。*
