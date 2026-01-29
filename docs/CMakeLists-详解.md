# `firmware/CMakeLists.txt` 逐行详解（STM32F407 + HAL + CMake/Ninja）

本文档对应当前仓库的 `firmware/CMakeLists.txt`，按“每一行做什么 + 为什么这样设计”的思路讲解，方便你后续把它演进成更工程化的形态（例如拆成 `toolchain.cmake`、按模块裁剪 HAL、支持多板卡/多目标等）。

> 说明：本文以 **CMake 3.20+**、**arm-none-eabi-gcc**、**Ninja**、目标芯片 **STM32F407（Cortex‑M4F）** 为前提。

---

## 总体设计思想（先看这个再看逐行更清晰）

这份 `CMakeLists.txt` 的核心目标是：

1. **明确交叉编译语义**：让 CMake 知道这是 “Generic/arm” 目标，不要把它当成 Windows 主机程序去做 ABI 探测/链接测试。
2. **最小闭环可跑通**：只把“能生成 `app.elf` 并能烧录”的最少源文件拉进来。
3. **路径可迁移**：用变量集中管理外部依赖路径（`external/ST/...`），避免硬编码四处散落。
4. **可裁剪可扩展**：HAL 目前只加入最小集合；后续可按需要添加/删减 HAL 外设源文件。

---

## 逐行讲解（对应 `firmware/CMakeLists.txt`）

下面按行号解释（行号以你当前文件为准）。

### 1：最低版本要求

- **第 1 行** `cmake_minimum_required(VERSION 3.20)`
  - 作用：要求 CMake 版本至少 3.20，避免使用较旧 CMake 时对生成器、目标属性等支持不一致。
  - 设计点：嵌入式项目常用现代 CMake 功能（例如 `target_*` 系列），锁定最低版本能减少踩坑。

### 3–13：交叉编译工具链与 try-compile 策略

- **第 3–4 行**：注释说明“编译器必须在 `project()` 之前设置”
  - 原因：`project()` 会触发语言启用与编译器检测；如果那之前没指定交叉编译器，CMake 很可能用主机编译器（MinGW/MSVC）导致一堆怪问题。

- **第 5 行** `set(CMAKE_SYSTEM_NAME Generic)`
  - 作用：告诉 CMake 目标系统不是 Windows/Linux，而是“通用裸机”。
  - 设计点：这是裸机交叉编译的常见写法。

- **第 6 行** `set(CMAKE_SYSTEM_PROCESSOR arm)`
  - 作用：声明目标处理器架构为 ARM。

- **第 9 行** `set(CMAKE_C_COMPILER arm-none-eabi-gcc CACHE FILEPATH ... FORCE)`
- **第 10 行** `set(CMAKE_ASM_COMPILER arm-none-eabi-gcc CACHE FILEPATH ... FORCE)`
  - 作用：强制指定 C/ASM 编译器为 ARM GNU 工具链。
  - 为什么用 `CACHE ... FORCE`：
    - `CACHE`：写进 `CMakeCache.txt`，让后续 reconfigure 保持一致。
    - `FORCE`：即使用户之前用别的编译器生成过，也强制覆盖，避免 CMake 一直沿用旧缓存。
  - 设计点：对新手更“傻瓜”，但如果你未来要支持“用户自定义工具链路径”，建议改为 toolchain 文件并通过 `-DCMAKE_TOOLCHAIN_FILE=...` 传入。

- **第 13 行** `set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)`
  - 作用：CMake 在检测编译器时会做 `try_compile`。对裸机目标，它如果尝试“链接一个可执行文件”，往往会失败或引入 host 链接逻辑。
  - 把 try-compile 目标改为静态库：避免链接阶段（只验证“能编译”），交叉编译更稳定。

### 15–18：声明工程与辅助工具

- **第 16 行** `project(smart_energy_terminal C ASM)`
  - 作用：定义工程名，启用 C 与 ASM 语言支持。

- **第 17 行** `find_program(CMAKE_OBJCOPY arm-none-eabi-objcopy)`
- **第 18 行** `find_program(CMAKE_SIZE arm-none-eabi-size)`
  - 作用：找到 `objcopy`/`size` 工具，用于生成 `.hex/.bin` 以及打印段大小。
  - 设计点：用 `find_program` 比硬编码路径更可移植。

### 20–27：CPU/FPU 编译选项（MCU_FLAGS）

- **第 22–27 行** 定义 `MCU_FLAGS`
  - 关键设计点：**用“CMake 列表”而不是一个带空格的字符串**。
    - 正确：每个 flag 是一个独立元素（`-mcpu=...`、`-mthumb` 等），传给编译器时不会被引号包成一个参数。
    - 错误（常见坑）：`"-mcpu=cortex-m4 -mthumb ..."` 会被当作“一个参数”，导致编译器报 `unrecognized -mcpu target`。
  - 参数含义：
    - `-mcpu=cortex-m4`：指定内核
    - `-mthumb`：Thumb 指令集
    - `-mfpu=fpv4-sp-d16` + `-mfloat-abi=hard`：M4F 硬浮点配置（需与工程/库一致）

### 29–42：路径变量（外部依赖与链接脚本）

- **第 30 行** `set(PROJ_ROOT ${CMAKE_CURRENT_LIST_DIR})`
  - 作用：当前 `CMakeLists.txt` 所在目录（即 `firmware/`）。

- **第 31 行** `set(EXTERNAL_ROOT ${PROJ_ROOT}/../external)`
  - 作用：定位到仓库根的 `external/`，用于引用第三方库。

- **第 33–36 行**：检查 `external/ST` 是否存在
  - 作用：如果第三方目录缺失，直接 `FATAL_ERROR`，比“编译到一半找不到头文件”更直观。

- **第 38–40 行**：分别定义 CMSIS Core、CMSIS Device、HAL 根目录
  - 设计点：路径集中管理，后续换目录结构（比如 `external/st` vs `external/ST`）只改这里。

- **第 42 行** `set(LINKER_SCRIPT ${PROJ_ROOT}/app/app.ld)`
  - 作用：链接脚本路径（描述 Flash/RAM 布局、段映射）。

### 44–70：目标与源文件列表（app.elf）

- **第 45 行** `add_executable(app.elf)`
  - 作用：定义最终输出目标为 ELF，可供 OpenOCD 烧录和 GDB 调试。

- **第 47–70 行** `target_sources(app.elf PRIVATE ...)`
  - 作用：把参与编译/链接的源文件明确列出来。
  - 分组说明：
    - **Startup/System（第 49–50 行）**
      - `startup_stm32f407xx.s`：向量表、Reset_Handler 等
      - `system_stm32f4xx.c`：SystemInit、SystemCoreClockUpdate 等
    - **App（第 53–55 行）**
      - `main.c`：主函数（目前来自 ST Template）
      - `stm32f4xx_it.c`：中断处理（SysTick/HardFault 等）
      - `stm32f4xx_hal_msp.c`：HAL 的底层 MSP 初始化（时钟/NVIC/外设底层）
    - **Drivers（第 58 行）**
      - `drivers/gpio/gpio.c`：你新增的 GPIO 初始化/点灯相关代码
    - **HAL 最小集合（第 61–69 行）**
      - 只加入当前模板 `SystemClock_Config()` 和 GPIO 初始化可能用到的 HAL 模块（RCC/PWR/FLASH/GPIO/CORTEX 等）。
      - 设计点：**尽量按需加入**，否则会把 HAL 全家桶都编译进来，编译慢且容易因为 `stm32f4xx_hal_conf.h` 开关不一致引发链接问题。

### 72–81：头文件搜索路径

- **第 72–81 行** `target_include_directories(app.elf PRIVATE ...)`
  - 作用：把工程头文件路径加入编译器 `-I`。
  - 为什么需要这些：
    - `${PROJ_ROOT}/app/inc`：`main.h`、`stm32f4xx_it.h`、`stm32f4xx_hal_conf.h` 等
    - `${PROJ_ROOT}/drivers/gpio`：`gpio.h`
    - `${HAL_DIR}/Inc` & `Inc/Legacy`：HAL 头文件与兼容层
    - `${CMSIS_CORE_DIR}`：`core_cm4.h` 与 CMSIS 编译器适配头
    - `${CMSIS_DEVICE_DIR}`：`stm32f4xx.h`、`stm32f407xx.h`、`system_stm32f4xx.h`

### 83–86：全局编译宏

- **第 83–86 行** `target_compile_definitions(app.elf PRIVATE ...)`
  - `STM32F407xx`：选择具体芯片型号（Device header 会根据它启用对应寄存器/外设定义）
  - `USE_HAL_DRIVER`：启用 HAL 驱动相关宏路径

### 88–93：编译选项（CFLAGS）

- **第 88–93 行** `target_compile_options(app.elf PRIVATE ...)`
  - `${MCU_FLAGS}`：CPU/FPU/ABI
  - `-ffunction-sections -fdata-sections`：把函数/数据放进独立 section，便于链接器做垃圾回收
  - `-fno-common`：避免 common 符号（减少重复定义问题）
  - `-Wall -Wextra`：打开更多告警，早发现问题

### 95–103：链接选项（LDFLAGS）

- **第 95–103 行** `target_link_options(app.elf PRIVATE ...)`
  - `${MCU_FLAGS}`：链接也要保持一致的 CPU/FPU 配置
  - `-T${LINKER_SCRIPT}`：指定链接脚本
  - `-Wl,--gc-sections`：配合 `-ffunction-sections/-fdata-sections`，把未引用代码从最终固件剔除
  - `-Wl,-Map=.../app.map`：输出 map 文件，定位占用/符号来源
  - `-Wl,--cref`：交叉引用信息（map 更可读）
  - `-specs=nosys.specs`：使用弱实现的 syscalls（避免必须提供 `_write/_read/...`）
  - `-specs=nano.specs`：链接 newlib-nano（更小）

### 105–107：链接数学库

- **第 105–107 行** `target_link_libraries(app.elf PRIVATE m)`
  - 作用：链接 `libm`，常见于使用 `sin/cos/sqrt` 等数学函数时。
  - 设计点：即使当前没用也通常无害；你追求最小也可以后续按需移除。

### 109–114：后处理（生成 hex/bin + size）

- **第 109–114 行** `add_custom_command(TARGET app.elf POST_BUILD ...)`
  - 作用：在链接完成后自动生成：
    - `app.hex`（IHEX）
    - `app.bin`（raw binary）
    - 打印 `size` 信息
  - `VERBATIM`：让 CMake 保证命令参数按原样传递，避免特殊字符/空格被错误转义。

---

## 后续建议（你可以按阶段逐步演进）

1. **把工具链抽到 `firmware/cmake/toolchain-arm-none-eabi.cmake`**
   - 以后用：`cmake -S firmware -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=firmware/cmake/toolchain-arm-none-eabi.cmake`
2. **按需裁剪 HAL**
   - 你当前 `stm32f4xx_hal_conf.h` 开了很多模块，建议点灯阶段只开 GPIO/RCC/CORTEX/PWR/FLASH 等必要项，并同步删掉没用到的 HAL `Src/*.c`。
3. **增加多目标/多板卡支持**
   - `add_executable(app_explorer_v3.elf ...)` / `add_library(platform_stm32f407 ...)` 等，把 platform/board/app 分离。

