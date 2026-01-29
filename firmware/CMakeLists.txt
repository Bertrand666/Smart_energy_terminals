cmake_minimum_required(VERSION 3.20)

# STM32 bare-metal firmware (CMake + arm-none-eabi-gcc)
project(smart_energy_terminal C ASM)

# Tools are typically discovered via the toolchain file; keep a fallback here.
if(NOT CMAKE_OBJCOPY)
  find_program(CMAKE_OBJCOPY arm-none-eabi-objcopy)
endif()
if(NOT CMAKE_SIZE)
  find_program(CMAKE_SIZE arm-none-eabi-size)
endif()

# ---------- MCU flags ----------
# Keep as a CMake list (NOT a single quoted string), so each flag is passed as its own argument.
set(MCU_FLAGS
  -mcpu=cortex-m4
  -mthumb
  -mfpu=fpv4-sp-d16
  -mfloat-abi=hard
)

# ---------- Paths ----------
set(PROJ_ROOT ${CMAKE_CURRENT_LIST_DIR})
set(EXTERNAL_ROOT ${PROJ_ROOT}/../external)

set(ST_ROOT ${EXTERNAL_ROOT}/ST)
if(NOT EXISTS ${ST_ROOT})
  message(FATAL_ERROR "ST external folder not found: ${ST_ROOT}")
endif()

set(CMSIS_CORE_DIR ${ST_ROOT}/CMSIS/Core)
set(CMSIS_DEVICE_DIR ${ST_ROOT}/CMSIS/Device)
set(HAL_DIR ${ST_ROOT}/STM32F4xx_HAL_Driver)

set(LINKER_SCRIPT ${PROJ_ROOT}/app/app.ld)

# ---------- Target ----------
add_executable(app.elf)

target_sources(app.elf PRIVATE
  # Startup / system (CMSIS device template)
  ${PROJ_ROOT}/platform/stm32f407/startup/startup_stm32f407xx.s
  ${PROJ_ROOT}/platform/stm32f407/system/system_stm32f4xx.c

  # App (currently from ST Templates)
  ${PROJ_ROOT}/app/src/main.c
  ${PROJ_ROOT}/app/src/stm32f4xx_it.c
  ${PROJ_ROOT}/app/src/stm32f4xx_hal_msp.c
  ${PROJ_ROOT}/app/src/retarget.c

  # Drivers
  ${PROJ_ROOT}/drivers/gpio/gpio.c
  ${PROJ_ROOT}/drivers/uart/uart.c

  # HAL minimal set for the current template main.c/SystemClock_Config
  ${HAL_DIR}/Src/stm32f4xx_hal.c
  ${HAL_DIR}/Src/stm32f4xx_hal_cortex.c
  ${HAL_DIR}/Src/stm32f4xx_hal_gpio.c
  ${HAL_DIR}/Src/stm32f4xx_hal_uart.c
  ${HAL_DIR}/Src/stm32f4xx_hal_rcc.c
  ${HAL_DIR}/Src/stm32f4xx_hal_rcc_ex.c
  ${HAL_DIR}/Src/stm32f4xx_hal_pwr.c
  ${HAL_DIR}/Src/stm32f4xx_hal_pwr_ex.c
  ${HAL_DIR}/Src/stm32f4xx_hal_flash.c
  ${HAL_DIR}/Src/stm32f4xx_hal_flash_ex.c
)

target_include_directories(app.elf PRIVATE
  ${PROJ_ROOT}/app/inc
  ${PROJ_ROOT}/drivers/gpio
  ${PROJ_ROOT}/drivers/uart

  ${HAL_DIR}/Inc
  ${HAL_DIR}/Inc/Legacy

  ${CMSIS_CORE_DIR}
  ${CMSIS_DEVICE_DIR}
)

target_compile_definitions(app.elf PRIVATE
  STM32F407xx
  USE_HAL_DRIVER
)

target_compile_options(app.elf PRIVATE
  ${MCU_FLAGS}
  -ffunction-sections -fdata-sections
  -fno-common
  -Wall -Wextra
)

target_link_options(app.elf PRIVATE
  ${MCU_FLAGS}
  -T${LINKER_SCRIPT}
  -Wl,--gc-sections
  -Wl,-Map=${CMAKE_CURRENT_BINARY_DIR}/app.map
  -Wl,--cref
  -specs=nosys.specs
  -specs=nano.specs
)

target_link_libraries(app.elf PRIVATE
  m
)

add_custom_command(TARGET app.elf POST_BUILD
  COMMAND ${CMAKE_OBJCOPY} -O ihex $<TARGET_FILE:app.elf> ${CMAKE_CURRENT_BINARY_DIR}/app.hex
  COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:app.elf> ${CMAKE_CURRENT_BINARY_DIR}/app.bin
  COMMAND ${CMAKE_SIZE} $<TARGET_FILE:app.elf>
  VERBATIM
)
