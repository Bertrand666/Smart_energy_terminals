/*
 * Minimal linker script for STM32F407ZGT6 (1MB Flash, 128KB SRAM, 64KB CCM).
 *
 * Use case: standalone application (NO bootloader), vector table at 0x08000000.
 * Toolchain: arm-none-eabi-gcc / GNU ld.
 */

/* Entry Point */
ENTRY(Reset_Handler)

/* Program headers (avoid RWX load segments) */
PHDRS
{
  flash PT_LOAD FLAGS(5); /* R + X */
  ram   PT_LOAD FLAGS(6); /* R + W */
}

/* Memories definition */
MEMORY
{
  FLASH  (rx)  : ORIGIN = 0x08000000, LENGTH = 1024K
  RAM    (xrw) : ORIGIN = 0x20000000, LENGTH = 128K
  CCMRAM (xrw) : ORIGIN = 0x10000000, LENGTH = 64K
}

/* Highest address of the user mode stack */
_estack = ORIGIN(RAM) + LENGTH(RAM);

/* Minimal heap/stack (tune as needed) */
_Min_Heap_Size  = 0x00000400; /* 1KB */
_Min_Stack_Size = 0x00000800; /* 2KB */

SECTIONS
{
  /* Vector table */
  .isr_vector :
  {
    . = ALIGN(4);
    KEEP(*(.isr_vector))
    . = ALIGN(4);
  } > FLASH :flash

  /* Code and read-only data */
  .text :
  {
    . = ALIGN(4);
    *(.text)
    *(.text*)
    *(.glue_7)
    *(.glue_7t)
    *(.eh_frame*)

    KEEP(*(.init))
    KEEP(*(.fini))

    . = ALIGN(4);
    _etext = .;
  } > FLASH :flash

  .rodata :
  {
    . = ALIGN(4);
    *(.rodata)
    *(.rodata*)
    . = ALIGN(4);
  } > FLASH :flash

  /* Exception unwinding */
  .ARM.extab :
  {
    *(.ARM.extab* .gnu.linkonce.armextab.*)
  } > FLASH :flash

  .ARM.exidx :
  {
    __exidx_start = .;
    *(.ARM.exidx*)
    __exidx_end = .;
  } > FLASH :flash

  /* C++ constructors/destructors */
  .preinit_array :
  {
    PROVIDE_HIDDEN(__preinit_array_start = .);
    KEEP(*(.preinit_array*))
    PROVIDE_HIDDEN(__preinit_array_end = .);
  } > FLASH :flash

  .init_array :
  {
    PROVIDE_HIDDEN(__init_array_start = .);
    KEEP(*(SORT(.init_array.*)))
    KEEP(*(.init_array*))
    PROVIDE_HIDDEN(__init_array_end = .);
  } > FLASH :flash

  .fini_array :
  {
    PROVIDE_HIDDEN(__fini_array_start = .);
    KEEP(*(SORT(.fini_array.*)))
    KEEP(*(.fini_array*))
    PROVIDE_HIDDEN(__fini_array_end = .);
  } > FLASH :flash

  /* Used by startup to initialize .data */
  _sidata = LOADADDR(.data);

  /* Initialized data */
  .data :
  {
    . = ALIGN(4);
    _sdata = .;
    *(.data)
    *(.data*)
    . = ALIGN(4);
    _edata = .;
  } > RAM AT> FLASH :ram

  /* Uninitialized data */
  .bss (NOLOAD) :
  {
    . = ALIGN(4);
    _sbss = .;
    __bss_start__ = _sbss;
    *(.bss)
    *(.bss*)
    *(COMMON)
    . = ALIGN(4);
    _ebss = .;
    __bss_end__ = _ebss;
  } > RAM :ram

  /* Optional CCM RAM section (NOLOAD by default) */
  .ccmram (NOLOAD) :
  {
    . = ALIGN(4);
    *(.ccmram)
    *(.ccmram*)
    . = ALIGN(4);
  } > CCMRAM :ram

  /* Heap and stack area check */
  ._user_heap_stack (NOLOAD) :
  {
    . = ALIGN(8);
    PROVIDE(end = .);
    PROVIDE(_end = .);
    . = . + _Min_Heap_Size;
    . = . + _Min_Stack_Size;
    . = ALIGN(8);
  } > RAM :ram

  .ARM.attributes 0 : { *(.ARM.attributes) }
}
