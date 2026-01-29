<div align="center">
  <h1>⚡ Smart Energy Terminal</h1>
  <hr/>
  <p>
    <b>智能能源监控终端</b> | <b>STM32F407ZGT6</b> · <b>Bare Metal</b>（点灯起步） → <b>FreeRTOS</b> → <b>ESP8266 AT</b> → <b>Modbus RTU</b>
  </p>
  <p>
    <img alt="Stage" src="https://img.shields.io/badge/Stage-Bare%20Metal-informational?style=flat-square" />
    <img alt="MCU" src="https://img.shields.io/badge/MCU-STM32F407ZGT6-blue?style=flat-square" />
    <img alt="RTOS" src="https://img.shields.io/badge/RTOS-FreeRTOS%20(planned)-green?style=flat-square" />
    <img alt="Network" src="https://img.shields.io/badge/Network-ESP8266%20AT%20(planned)-brightgreen?style=flat-square" />
    <img alt="Protocol" src="https://img.shields.io/badge/Protocol-Modbus%20RTU%20(planned)-orange?style=flat-square" />
    <img alt="License" src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" />
  </p>
</div>

> 当前目标：**裸机点灯（LED Blink）**，先把“能编译、能烧录、能稳定运行”的最小闭环跑通。

---

## 目录

- [项目简介](#项目简介)
- [项目进度](#项目进度)
- [技术栈](#技术栈)
- [硬件平台（目标）](#硬件平台目标)
- [快速开始](#快速开始)
- [目录结构](#目录结构)
- [目录说明](#目录说明)
- [分层约定（简版）](#分层约定简版)
- [后续扩展建议（放置位置）](#后续扩展建议放置位置)
- [License](#license)

## 项目简介

Smart Energy Terminal 旨在构建一个 **可演示、可测试、可扩展** 的能源监控终端原型。

项目采用“先最小闭环、再逐步扩展”的路线：

1. **Bare Metal 点灯**（本阶段）
2. 引入 **HAL/LL**（可选）与更规范的驱动抽象
3. 引入 **FreeRTOS**，形成任务/服务化业务组织
4. 引入 **ESP8266 AT** 联网（UART + DMA + IDLE + RingBuffer）
5. 引入 **Modbus RTU** 协议栈与寄存器模型
6. 逐步扩展 **LVGL / FatFs / OTA** 等能力

## 项目进度

> 更新时间：2026-01-28

| 模块 | 状态 | 说明 |
|---|---|---|
| 最小闭环（裸机点灯） | 进行中 | GPIO 初始化 + 周期翻转 + 延时 |
| 工具链（CMake + GCC + OpenOCD） | 进行中 | 不依赖 CubeMX/CubeIDE |
| HAL（可选） | 规划 | 手动移植/裁剪，仅引入所需外设 |
| RTOS（FreeRTOS） | 规划 | 裸机稳定后再引入 |
| 联网（ESP8266 AT） | 规划 | UART + DMA + IDLE + RingBuffer |
| 协议（Modbus RTU） | 规划 | 寄存器建模、异常码、CRC |
| UI（LVGL） | 规划 | TFT/触摸/局部刷新 |
| 外部存储（Flash/TF + FatFs） | 规划 | W25Qxx + FatFs |
| OTA/Bootloader | 规划 | 分区/镜像/回滚策略 |

## 技术栈

- MCU：STM32F407（Cortex-M4F）
- 当前阶段：Bare Metal（无 RTOS）
- 构建：CMake / Ninja / arm-none-eabi-gcc
- 烧录/调试：OpenOCD + Cortex-Debug（VS Code）
- 规划：FreeRTOS、ESP8266 AT、Modbus RTU、LVGL、FatFs、CAN

## 硬件平台（目标）

- 开发板：正点原子探索者 V3（STM32F407ZGT6）
- 联网（规划）：ESP8266（AT 指令，UART + DMA + IDLE + RingBuffer）
- 工业协议（规划）：Modbus RTU（从站）
- 显示（规划）：4.3 寸 TFT，800×480（竖屏），FSMC/8080 并口
- 外部存储（规划）：W25Q128（SPI Flash）+ TF（FatFs）
- 总线（规划）：CAN

## 快速开始

> 建议先完成最小验证：**点灯闪烁稳定**（可选再加串口打印）。

### 1) 构建

```bash
cmake --preset default
cmake --build --preset default
```

### 2) 烧录（示例：OpenOCD）

```bash
openocd -f interface/cmsis-dap.cfg -f target/stm32f4x.cfg -c "transport select swd; adapter speed 2000; program firmware/build/out/app.elf verify reset exit"
```

连接不稳定时的经验项：

- 将 `adapter speed` 调低到 `1000` 或 `500`
- 尽量连接 `NRST`

### 3) 调试（VS Code）

- 调试配置通常放在 `.vscode/launch.json`，使用 `Cortex-Debug + OpenOCD`
- 你可能需要按自己的调试器补齐 `configFiles` / `svdFile` 等

## 目录结构

> 说明：当前仓库以“目录骨架”为主，后续会逐步填充源码与文档。

```text
Smart_energy_terminals/
├─ README.md
├─ LICENSE
├─ docs/
├─ external/
│  ├─ st/
│  │  ├─ CMSIS/
│  │  │  ├─ Core/
│  │  │  └─ Device/
│  │  └─ STM32F4xx_HAL_Driver/
│  │     ├─ Inc/
│  │     └─ Src/
│  ├─ FreeRTOS/
│  ├─ FatFs/
│  └─ LVGL/
├─ tools/
└─ firmware/
   ├─ CMakeLists.txt
   ├─ CMakePresets.json
   ├─ cmake/
   ├─ linker/
   ├─ config/
   ├─ platform/
   │  └─ stm32f407/
   │     ├─ include/
   │     ├─ src/
   │     ├─ startup/
   │     └─ system/
   ├─ boards/
   │  └─ explorer_v3/
   │     ├─ include/
   │     └─ src/
   ├─ drivers/
   │  ├─ gpio/
   │  ├─ uart/
   │  ├─ spi/
   │  └─ comm/
   ├─ common/
   │  ├─ log/
   │  └─ utils/
   ├─ app/
   └─ tests/
```

## 目录说明

- `docs/`：项目文档（架构/硬件资源/协议/升级等），用于沉淀设计与约束
- `external/`：第三方依赖的“原始代码”统一放置（尽量不在此处写业务逻辑）
- `external/st/`：ST 官方基础库
- `external/st/CMSIS/`：CMSIS Core + Device（启动、中断、寄存器映射等最底层依赖）
- `external/st/STM32F4xx_HAL_Driver/`：HAL 驱动库（可选；需要时手动裁剪引入）
- `external/FreeRTOS/`：FreeRTOS（规划；后期引入）
- `external/FatFs/`：FatFs（规划；后期引入）
- `external/LVGL/`：LVGL（规划；后期引入）
- `tools/`：PC 侧工具与脚本（烧录/打包/辅助工具）

- `firmware/`：固件工程本体（自研代码为主）
- `firmware/cmake/`：CMake 工具链文件、通用宏与构建封装
- `firmware/linker/`：链接脚本（`.ld`），描述 Flash/RAM 布局与段映射
- `firmware/config/`：工程/产品级配置头文件（后期集中管理开关与参数）
- `firmware/platform/stm32f407/`：平台适配层（与芯片强绑定）
- `firmware/platform/stm32f407/startup/`：启动文件（向量表、复位入口等）
- `firmware/platform/stm32f407/system/`：系统初始化（时钟、FPU、SysTick 等）
- `firmware/platform/stm32f407/include/`：平台层对外头文件（自研，避免再放一份 CMSIS）
- `firmware/platform/stm32f407/src/`：平台层实现（如 clock、irq、tick 等封装）
- `firmware/boards/`：板级“真相源”（只描述硬件事实：引脚/外设占用/LED 有效电平等）
- `firmware/drivers/`：驱动层（尽量不依赖 RTOS；上层通过接口调用）
- `firmware/drivers/gpio/`：GPIO 基础驱动/封装（点灯阶段会优先使用）
- `firmware/drivers/uart/`：UART 驱动（后期用于日志与 ESP8266）
- `firmware/drivers/spi/`：SPI 驱动（后期用于 W25Qxx 等）
- `firmware/drivers/comm/`：通信相关驱动（规划：ESP8266 AT 协议解析/收发）
- `firmware/common/`：与芯片无关的通用库
- `firmware/common/log/`：日志模块（规划/逐步落地）
- `firmware/common/utils/`：小工具（ringbuffer/crc/delay 等）
- `firmware/app/`：应用入口与业务编排（裸机 main / 后期 RTOS task 也在此）
- `firmware/tests/`：测试（可选：host 侧单测/静态检查等）

## 分层约定（简版）

- `external/`：只放第三方“原始库”；若需要改动，优先用补丁/适配层方式隔离
- `platform/`：芯片级平台适配（启动/时钟/中断等），向上提供稳定接口
- `boards/`：仅放板级事实与薄适配（引脚/外设资源映射/句柄创建），不写业务状态机、不写 UI/协议
- `drivers/`：设备/外设驱动尽量纯 C，不依赖 RTOS；需要互斥/队列的策略放到 `app/`
- `app/`：应用入口与业务编排（当前裸机；后期可演进为 RTOS 任务/服务）
- `common/`：通用工具库，与芯片无关

## 后续扩展建议（放置位置）

- 裸机点灯：`firmware/app/` + `firmware/drivers/gpio/` + `firmware/boards/` + `firmware/platform/`
- HAL（可选）：HAL 源码放 `external/st/STM32F4xx_HAL_Driver/`，工程内只编译用到的外设模块
- FreeRTOS：源码放 `external/FreeRTOS/`，适配与任务编排放 `firmware/app/`
- ESP8266 AT：底层 UART/DMA 在 `firmware/drivers/uart/`，协议收发/解析放 `firmware/drivers/comm/`
- Modbus RTU：协议状态机/寄存器模型建议放 `firmware/app/`（或后续新增 `services/` 目录）
- LVGL/FatFs：第三方放 `external/`，板级/驱动/适配放 `firmware/`（display/storage 等目录后续按需新增）

## License

MIT License，详见 `LICENSE`。
