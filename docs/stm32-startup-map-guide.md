# STM32 启动过程与 MAP 文件分析（本项目指南）

本指南面向本仓库工程（`Smart_energy_terminals`），结合以下资料整理，并“按目录/文件”对照讲解：

- `docs/STM32 启动文件浅析_V1.2.pdf`
- `docs/STM32 MAP文件浅析_V1.1.pdf`
- `docs/STM32F407ZGT6 探索者开发指南V1.2.pdf` 的 **第九章《STM32 启动过程分析》**

目标是让你能把“启动模式/启动文件/链接脚本/MAP 文件”四件事串成一条可落地的工程认知链路，并能直接对照本项目代码排查问题。

---

## 0. 快速总览：从复位到点灯（最小闭环）

最小闭环可以用一句话概括：

> 启动模式决定 **0x00000000** 映射到哪里；向量表给出 **MSP/Reset_Handler**；启动文件建立 C 运行时并进入 `main()`；`HAL_Init + SysTick_Handler` 提供时间基座；GPIO 初始化后循环翻转即可点灯。

对照本项目文件链路：

```text
BOOT0/BOOT1 采样 -> 0x0000_0000 重映射
  -> 向量表（.isr_vector，链接到 FLASH 起始）
  -> Reset_Handler（startup_stm32f407xx.s）
     - 拷贝 .data / 清零 .bss
     - SystemInit（system_stm32f4xx.c）
     - __libc_init_array
     - main（app/src/main.c）
        - HAL_Init -> SystemClock_Config -> MX_GPIO_Init
        - while(1) Toggle + HAL_Delay
  -> SysTick_Handler（app/src/stm32f4xx_it.c）每 1ms 调用 HAL_IncTick
```

---

## 1. `docs/`：资料、演示与阅读顺序

### 1.1 推荐阅读顺序

1) 先看《启动文件浅析》：弄懂向量表、Reset_Handler、.data/.bss、weak 中断等“通用骨架”
2) 再看《第九章 启动过程分析》：把 BOOT0/BOOT1 的启动模式与地址重映射串起来，并把启动文件和 MAP 分析联系起来
3) 最后看《MAP 文件浅析》：学会从 MAP/size 里读出 Flash/RAM 占用、段布局、符号占用

### 1.2 本仓库辅助材料

- `docs/hal-blink-minimal.md`：本项目“HAL 点灯最小闭环”对应文件与执行链路
- `docs/startup-animation.html`：启动链路动画演示（时间线 + 关键代码片段）

---

## 2. `external/ST/CMSIS/`：启动模式、向量表与寄存器定义的“地基”

CMSIS 提供两层东西：

- **Core（内核层）**：Cortex-M4 的 NVIC/SysTick/SCB 等核心寄存器定义（例如 `core_cm4.h`）
- **Device（设备层）**：STM32F407 的外设寄存器映射、IRQn 枚举、位定义（例如 `stm32f407xx.h`）

### 2.1 启动模式与地址重映射（来自《第九章 9.1 启动模式》）

复位后，内核会从 **0x0000_0000** 取 MSP 初值，从 **0x0000_0004** 取 PC 初值（指向 Reset_Handler）。

关键在于：**0x0000_0000 并不一定等于 0x0800_0000**，它取决于 BOOT 引脚采样后的“重映射”。

STM32F4 常见三种启动源（概念上）：

- 从内部 Flash 启动：0x0000_0000 映射到 0x0800_0000
- 从内部 SRAM 启动：0x0000_0000 映射到 0x2000_0000
- 从系统存储器启动：0x0000_0000 映射到系统存储器起始（用于 ISP/串口下载等）

对本项目而言：我们把应用放在 **Flash 起始（0x0800_0000）**，默认就是“内部 Flash 启动”这条链路。

### 2.2 本项目里与 CMSIS 强相关的文件

- `external/ST/CMSIS/Core/core_cm4.h`：NVIC/SysTick/SCB/FPU 等核心寄存器与基础宏
- `external/ST/CMSIS/Device/stm32f4xx.h`：设备选择入口（选择 `STM32F407xx` 并可拉入 HAL）
- `external/ST/CMSIS/Device/stm32f407xx.h`：外设寄存器映射与中断号
- `external/ST/CMSIS/Device/system_stm32f4xx.h`：`SystemInit/SystemCoreClockUpdate` 声明

---

## 3. `firmware/app/app.ld`：链接脚本决定“段放哪里”与“启动符号从哪来”

链接脚本是启动闭环里最容易被低估的部分：启动文件里用到的 `_estack/_sidata/_sdata/_edata/_sbss/_ebss` 等符号，通常都由链接脚本导出。

### 3.1 本项目的关键点

- Flash/RAM/CCMRAM 的 **起始地址与大小** 在 `MEMORY` 中定义
- 向量表段 `.isr_vector` 被 `KEEP` 并放在 Flash 起始（保证不会被链接器裁剪）
- `.data` 运行在 RAM，但初值存放在 Flash（因此需要 `_sidata = LOADADDR(.data)`）
- `_estack` 定义为 RAM 顶部，用于启动文件设置主栈指针（MSP）

### 3.2 为什么你的 GCC 启动文件里没有 `EQU/AREA/SPACE`？

《启动文件浅析》里举例常用的是 Keil/ARMASM 语法（`EQU/AREA/SPACE`），而本项目使用 GCC/GAS 启动文件：

- 栈顶地址（`_estack`）由 `app.ld` 计算出来
- `.data/.bss` 的边界符号由 `app.ld` 导出
- 启动文件只“使用这些符号”，不负责“定义内存区域大小”

因此你在 `startup_stm32f407xx.s` 里看到的是 `ldr sp, =_estack`，而不是在启动文件里手动开辟一块 `Stack_Mem`。

---

## 4. `firmware/platform/stm32f407/startup/`：启动文件（向量表 + Reset_Handler）

文件：`firmware/platform/stm32f407/startup/startup_stm32f407xx.s`

结合《启动文件浅析》的结构，启动文件通常包含三块核心内容：

### 4.1 向量表（Vector Table）

- 第 1 项：初始 MSP（栈顶）
- 第 2 项：Reset_Handler 地址
- 后面依次是各种异常/中断的处理函数入口

本项目的向量表段名是 `.isr_vector`，由 `app.ld` 放在 Flash 起始。

### 4.2 Reset_Handler 做了什么（最小必要步骤）

1) 设置 SP（MSP）为 `_estack`
2) 拷贝 `.data`：Flash → RAM（使用 `_sidata/_sdata/_edata`）
3) 清零 `.bss`：RAM 区间置 0（使用 `_sbss/_ebss`）
4) 调 `SystemInit()`（见下一节）
5) 调 `__libc_init_array()`（C/C++ 初始化）
6) 跳到 `main()`

这正是“系统为什么能从汇编跑进 C”的核心原因。

### 4.3 weak 中断与默认处理（来自《启动文件浅析 2.4.1 weak》）

启动文件里大量 `.weak` / `.thumb_set xxx, Default_Handler` 的目的：

- 你不实现某个中断处理函数时，链接不会报错
- 真发生该中断时，会落到 `Default_Handler`（死循环），便于你用调试器定位

---

## 5. `firmware/platform/stm32f407/system/`：SystemInit 与 SystemCoreClock

文件：`firmware/platform/stm32f407/system/system_stm32f4xx.c`

### 5.1 SystemInit 的定位（来自《第九章 9.2 启动文件分析》）

SystemInit 在 `Reset_Handler` 里最早被调用，通常做：

- FPU 相关设置（若启用）
- 向量表地址设置/重定位（`SCB->VTOR`）
- （可选）外部 SRAM/SDRAM 控制器初始化

### 5.2 为什么它会影响 HAL_Delay？

HAL 的时间基座常基于 SysTick，而 SysTick 的配置与系统时钟频率相关：

- `SystemClock_Config()` 改了时钟树
- HAL 会相应更新滴答配置/Flash 延时等

所以“时钟配置不匹配”可能导致延时异常或系统不稳定。

---

## 6. `firmware/app/inc` 与 `firmware/app/src`：HAL 配置 + 入口 + SysTick 中断

### 6.1 `firmware/app/inc`（配置与声明）

- `firmware/app/inc/stm32f4xx_hal_conf.h`：HAL 模块开关、HSE/HSI 数值等
- `firmware/app/inc/stm32f4xx_it.h`：中断函数声明（名字要和向量表一致）
- `firmware/app/inc/main.h`：公共头（当前直接 include `stm32f4xx_hal.h`）

### 6.2 `firmware/app/src`（入口与“胶水代码”）

- `firmware/app/src/main.c`：`HAL_Init()` → `SystemClock_Config()` → `MX_GPIO_Init()` → 循环点灯
- `firmware/app/src/stm32f4xx_it.c`：`SysTick_Handler()` 调 `HAL_IncTick()`，让 `HAL_Delay()` 走时
- `firmware/app/src/stm32f4xx_hal_msp.c`：`HAL_MspInit()`（点灯阶段可为空；后续外设会用到）

---

## 7. `firmware/drivers/gpio/`：点灯所需 GPIO 初始化封装

文件：`firmware/drivers/gpio/gpio.c`

点灯最小闭环只关心三件事：

1) 端口时钟使能（例如 `__HAL_RCC_GPIOF_CLK_ENABLE()`）
2) 引脚模式配置（推挽输出/上下拉/速度）
3) 循环翻转引脚

当前实现使用 `PF9`。若不闪，第一优先级请核对：开发板 LED 实际引脚与有效电平。

---

## 8. `build/firmware-gcc/`：本项目的 MAP 文件怎么用（GCC 版）

《MAP 文件浅析》以 MDK 的 `.axf/.map` 为例讲解，但核心思想对 GCC 同样成立：

- MAP 文件告诉你：**段/符号** 最终被放到了什么地址，占用多少
- 你能据此分析：Flash/ RAM 占用、哪个模块最“肥”、向量表是否在预期位置

本项目产物示例：

- `build/firmware-gcc/app.elf`：可执行文件（相当于 MDK 的 `.axf`）
- `build/firmware-gcc/app.map`：链接映射（map）
- `build/firmware-gcc/app.hex` / `app.bin`：下载用文件

### 8.1 你应该重点看 MAP 的哪些部分

结合《MAP 文件浅析》的“组成部分”思路，建议在 GCC map 里优先看：

1) Memory Configuration（内存区域与大小，是否与 `app.ld` 一致）
2) `.isr_vector/.text/.rodata/.data/.bss` 的地址与大小
3) 关键符号（例如 `_estack/_sidata/_sdata/_edata/_sbss/_ebss`）是否被正确解析
4) 哪些目标文件/库贡献了最多的 `.text`/`.bss`

### 8.2 辅助命令（比直接看 MAP 更快）

你可以用这些命令快速定位体积问题（路径按你实际 build 目录调整）：

```bash
arm-none-eabi-size build/firmware-gcc/app.elf
arm-none-eabi-nm --size-sort --radix=d build/firmware-gcc/app.elf | tail
arm-none-eabi-objdump -h build/firmware-gcc/app.elf
```

---

## 9. 常见问题与定位建议（按“启动链路”回溯）

1) **不进 main / 一上电就死**
   - 优先查：启动模式（BOOT0/BOOT1）、向量表是否在 Flash 起始、`ENTRY(Reset_Handler)` 是否正确

2) **能进 main 但 HAL_Delay 不走时**
   - 查：`SysTick_Handler()` 是否链接到你的实现（而不是 Default_Handler）
   - 查：`SysTick_Handler` 是否调用 `HAL_IncTick()`

3) **HardFault 随机出现**
   - 常见原因：栈不够（局部变量太大/深层调用），或时钟配置不匹配
   - 用 MAP/size 看 RAM 压力，必要时调整 `app.ld` 中的栈/堆预留策略

4) **LED 不闪但程序在跑**
   - 核对 LED 引脚与有效电平；用示波器/逻辑分析仪确认引脚是否翻转

---

## 10. 进一步建议（面向后续 Bootloader/OTA）

当你后续做 Bootloader/OTA 时，最关键的变化通常是：

- 应用不再从 0x0800_0000 启动（可能是 0x0800_8000 等偏移）
- 向量表需要重定位（`SCB->VTOR = app_base`）
- 链接脚本的 Flash ORIGIN/段放置需要同步调整

这三者（启动文件/VTOR/链接脚本）必须一致，否则表现就是“能下载但运行跑飞”。

