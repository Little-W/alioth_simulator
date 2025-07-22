
./dram.bin:     file format binary


Disassembly of section .data:


### FUNC_START 80100000 ###
80100000 <.data>:
	...
8010000c:	abcd                	j	0x801005fe
8010000e:	1234                	add	a3,sp,296
80100010:	7788                	flw	fa0,40(a5)
80100012:	5566                	lw	a0,120(sp)
	...
8010001c:	00ff ff00 0000 0000 	.insn	10, 0xff0000ff
80100024:	0000 
	...
### FUNC_END   80100000 ###

===== CALL GRAPH =====
0x80100000 -> (none)
===== EXIT POINTS =====
(未检测到 ecall / wfi / 死循环)
