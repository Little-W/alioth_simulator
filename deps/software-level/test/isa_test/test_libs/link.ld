OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  /* ITCM区域 - 指令存储 */
  . = 0x80000000;
  .text.init : { *(.text.init) }
  .text : { *(.text) }
  .data : { *(.data) }
  .bss : { *(.bss) }
  _end = .;
}

