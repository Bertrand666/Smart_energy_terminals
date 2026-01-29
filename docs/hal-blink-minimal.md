# HAL 点灯最小闭环（STM32F407）

本文基于本仓库当前工程结构，解释从复位到 LED 翻转的最小闭环，以及关键目录/文件的职责。

---

## 1. 什么是‘HAL 点灯最小闭环’

目标是：不依赖 CubeMX/CubeIDE，也能编译/链接/下载，并让 LED 周期性闪烁。

最小闭环一般包含 5 步：
- 复位后进入 main()
- HAL_Init() 初始化 HAL 底座（含 SysTick 时基）
- 配置系统时钟（PLL/分频/Flash 延时）
- 初始化 LED GPIO（端口时钟 + 模式配置）
- 循环翻转引脚 + 延时（HAL_GPIO_TogglePin/HAL_Delay）

## 2. 从复位到闪烁：执行链路

下面这条链路就是 HAL 点灯闭环真正跑起来所依赖的关键环节：

```text
Reset (0x0800_0000 vector table)
  -> Reset_Handler  (firmware/platform/stm32f407/startup/startup_stm32f407xx.s)
     - set SP = _estack
     - copy .data  (_sidata -> _sdata.._edata)
     - zero .bss   (_sbss.._ebss)
     - SystemInit() (firmware/platform/stm32f407/system/system_stm32f4xx.c)
     - __libc_init_array()
     - main()       (firmware/app/src/main.c)
          - HAL_Init()
              - HAL_MspInit()         (firmware/app/src/stm32f4xx_hal_msp.c)
              - SysTick timebase init (HAL_InitTick)
          - SystemClock_Config()
              - HAL_RCC_OscConfig / HAL_RCC_ClockConfig
          - MX_GPIO_Init()            (firmware/drivers/gpio/gpio.c)
          - while(1)
              - HAL_GPIO_TogglePin()
              - HAL_Delay()

SysTick interrupt (every 1ms)
  -> SysTick_Handler() (firmware/app/src/stm32f4xx_it.c)
       - HAL_IncTick()  => uwTick++  => HAL_Delay() works
```
## 3. 你关心的目录/文件各有什么用？

### 3.1 external/ST/CMSIS：内核与芯片寄存器定义（‘地基’）

CMSIS 负责提供 Cortex-M4 内核、NVIC/SysTick、以及 STM32F407 外设寄存器映射与中断号定义。HAL 和你的业务代码都建立在它之上。

关键文件（本仓库）：
- external/ST/CMSIS/Core/core_cm4.h：Cortex-M4 内核寄存器与 NVIC/SysTick 定义
- external/ST/CMSIS/Device/stm32f4xx.h：设备选择入口（决定包含 stm32f407xx.h）
- external/ST/CMSIS/Device/stm32f407xx.h：外设寄存器映射/位定义/IRQn 枚举
- external/ST/CMSIS/Device/system_stm32f4xx.h：SystemInit/SystemCoreClock 声明

### 3.2 external/ST/STM32F4xx_HAL_Driver：HAL 外设驱动（‘工具箱’）

HAL Driver 提供面向外设的函数接口（GPIO/RCC/PWR/FLASH…），让你不用直接写寄存器也能完成初始化与控制。

点灯闭环最常用到的 HAL 组件：
- HAL_Init/HAL_Delay/HAL_IncTick（HAL 核心 + SysTick 时基）
- RCC/PWR/FLASH（SystemClock_Config 里会用到，用于把系统跑到目标频率）
- GPIO（HAL_GPIO_Init/HAL_GPIO_TogglePin）

### 3.3 firmware/app/inc：应用层头文件（HAL 配置与声明）

这里放‘编译期配置’与对外声明，最典型的是 HAL 的配置文件 stm32f4xx_hal_conf.h。它会决定哪些 HAL 模块参与编译，并提供 HSE/HSI 等基础参数。

本仓库对应文件：
- firmware/app/inc/stm32f4xx_hal_conf.h：HAL 模块开关 + HSE_VALUE/HSI_VALUE 等
- firmware/app/inc/stm32f4xx_it.h：中断函数声明（名字需与向量表一致）
- firmware/app/inc/main.h：公共头（当前直接 include stm32f4xx_hal.h）

### 3.4 firmware/app/src：应用入口与中断/钩子实现（‘胶水层’）

这里放 main、中断处理函数以及 HAL 的 MSP 钩子实现。点灯闭环是否‘能延时’，很大程度取决于 SysTick_Handler 是否正确调用 HAL_IncTick。

本仓库对应文件：
- firmware/app/src/main.c：HAL_Init -> SystemClock_Config -> MX_GPIO_Init -> Toggle + Delay
- firmware/app/src/stm32f4xx_it.c：SysTick_Handler() { HAL_IncTick(); }
- firmware/app/src/stm32f4xx_hal_msp.c：HAL_MspInit()（可为空；后续外设会用到）

### 3.5 firmware/app/app.ld：链接脚本（把程序放进正确的内存）

链接脚本定义 Flash/RAM/CCMRAM 的布局与段放置规则，并导出启动文件需要的符号（_estack/_sidata/_sdata/_edata/_sbss/_ebss）。没有它，启动文件无法正确初始化 .data/.bss。

### 3.6 firmware/drivers/gpio：GPIO 初始化封装（MX_GPIO_Init）

本仓库把 LED 的 GPIO 端口时钟使能与引脚模式配置放在这里，main 只负责调用 MX_GPIO_Init()。当前配置的是 PF9 推挽输出，并在循环中翻转 PF9。

### 3.7 startup_stm32f407xx.s：向量表 + Reset_Handler（把你带进 main）

启动文件负责：设置初始栈指针、拷贝 .data、清零 .bss、调用 SystemInit()、再跳到 main()；同时提供向量表，把 SysTick_Handler 等符号绑定到中断入口。

### 3.8 system_stm32f4xx.c：SystemInit/SystemCoreClock（最早期系统配置）

SystemInit() 在 Reset_Handler 里最早被调用，常见职责包括：FPU 相关设置、向量表地址（SCB->VTOR）配置、（可选）外部存储控制器初始化。SystemCoreClockUpdate() 用于在时钟改变后更新 SystemCoreClock。

## 4. 点灯闭环最容易卡住的点（排查清单）

- 芯片宏：必须定义 STM32F407xx，否则 CMSIS 可能选错设备头。
- HAL 开关：必须定义 USE_HAL_DRIVER，否则 stm32f4xx_hal.h 不会被拉进来。
- include 路径：需要把 firmware/app/inc 加到 include path，HAL 才能找到 stm32f4xx_hal_conf.h。
- SysTick：向量表要指向你的 SysTick_Handler，且其中要调用 HAL_IncTick，否则 HAL_Delay 不走时。
- 时钟源：SystemClock_Config 里假设的 HSE_VALUE 要和板子晶振一致（本仓库当前为 8MHz）。
- LED 引脚：确认板子 LED 是否真在 PF9，以及高/低电平点亮的逻辑是否一致。
- 链接脚本：.isr_vector 需要 KEEP 并放在 Flash 起始，且 _estack/_sidata/_sdata/_edata/_sbss/_ebss 要正确。

## 5. 本仓库‘点灯最小闭环’对应文件一览

- 入口与主循环：firmware/app/src/main.c
- GPIO 初始化：firmware/drivers/gpio/gpio.c
- SysTick 中断：firmware/app/src/stm32f4xx_it.c
- HAL 配置：firmware/app/inc/stm32f4xx_hal_conf.h
- 启动与向量表：firmware/platform/stm32f407/startup/startup_stm32f407xx.s
- 系统初始化：firmware/platform/stm32f407/system/system_stm32f4xx.c
- 链接脚本：firmware/app/app.ld

## 6. 最小代码形态（参考）

下面摘取本仓库当前实现的关键逻辑（省略注释与错误处理）：

```c
// firmware/app/src/main.c
HAL_Init();
SystemClock_Config();
MX_GPIO_Init();

while (1) {
  HAL_GPIO_TogglePin(GPIOF, GPIO_PIN_9);
  HAL_Delay(5000);
}
```

```c
// firmware/drivers/gpio/gpio.c
__HAL_RCC_GPIOF_CLK_ENABLE();
HAL_GPIO_WritePin(GPIOF, GPIO_PIN_9, GPIO_PIN_RESET);
GPIO_InitStruct.Pin = GPIO_PIN_9;
GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
HAL_GPIO_Init(GPIOF, &GPIO_InitStruct);
```

```c
// firmware/app/src/stm32f4xx_it.c
void SysTick_Handler(void) {
  HAL_IncTick();
}
```
\n---\n\n## 附：启动过程动画演示（HTML）\n\n- 打开：docs/startup-animation.html（浏览器直接打开即可）\n
