.section .init // 初始化段
	.globl   _start // 声明全局入口符号
	.type    _start,@function // 声明_start为函数类型

	//       程序入口
_start:
	.option  push
	.option  norelax
	la       gp, __global_pointer$ // 加载全局指针寄存器
	.option  pop
	la       sp, _sp // 初始化堆栈指针
#ifdef SIMULATION
	csrrwi   x0, sstatus, 0x0 // 清除仿真结果标志
#endif

	//       拷贝.data段数据到RAM
	la       a0, _data_lma // a0 = .data段LMA（存储在flash/itcm的起始地址）
	la       a1, _data // a1 = .data段VMA（RAM/dtcm中的起始地址）
	la       a2, _edata // a2 = .data段结束地址
	bgeu     a1, a2, 2f // 如果a1 >= a2，跳转到2f
1:
	lw       t0, (a0) // 从LMA读取数据
	sw       t0, (a1) // 写入VMA
	addi     a0, a0, 4
	addi     a1, a1, 4
	bltu     a1, a2, 1b // 如果a1 < a2，继续循环
2:

	//       清零.bss段
	la       a0, __bss_start // a0 = .bss段起始地址
	la       a1, _end // a1 = .bss段结束地址
	bgeu     a0, a1, 2f // 如果a0 >= a1，跳转到2f
1:
	sw       zero, (a0) // 清零
	addi     a0, a0, 4
	bltu     a0, a1, 1b // 如果a0 < a1，继续循环
2:

	//       设置异常和中断入口地址
	la       a0, trap_entry
	csrw     mtvec, a0

	// 调用SystemInit
	call     SystemInit

	li       a0, 0 // main函数参数a0 = 0
	li       a1, 0 // main函数参数a1 = 0
	call     main // 调用main函数

loop:
	j        loop // 死循环，防止main返回
