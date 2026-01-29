# Toolchain file for ARM GNU Embedded (arm-none-eabi) on bare-metal targets.

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)

# Select compilers
set(CMAKE_C_COMPILER arm-none-eabi-gcc CACHE FILEPATH "C compiler" FORCE)
set(CMAKE_ASM_COMPILER arm-none-eabi-gcc CACHE FILEPATH "ASM compiler" FORCE)

# Avoid CMake try-compile attempting to link executables on the host.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# Helpful tools (optional)
find_program(CMAKE_OBJCOPY arm-none-eabi-objcopy)
find_program(CMAKE_SIZE arm-none-eabi-size)

# In some Windows setups, antivirus/indexers may lock CMake try-compile scratch files,
# causing configure failures ("could not be removed: Access is denied").
# Since this is a bare-metal cross toolchain, we can safely skip these compiler checks.
set(CMAKE_C_COMPILER_WORKS TRUE)
set(CMAKE_ASM_COMPILER_WORKS TRUE)
