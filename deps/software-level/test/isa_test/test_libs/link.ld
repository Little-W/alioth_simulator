OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  /* ITCM区域 - 指令存储 */
  . = 0x80000000;
  .text.init : { *(.text.init) }
  .text : { *(.text) }
  
  /* DTCM区域 - 数据存储 */
  . = 0x80100000;
  .data : { *(.data) }
  .bss : { *(.bss) }
  _end = .;
}

