#define REGBYTES  4
#define STORE     sw
#define LOAD      lw

    .section      .text.vector
    .align 2
    .global trap_entry
    .global vector_table

vector_table:
    .word illegal_instruction_handler
    .word instruction_addr_misaligned_handler
    .word ecall_handler
    .word ebreak_handler
    .word load_misaligned_handler
    .word store_misaligned_handler
    .word handle_exception_unknown
    .word handle_exception_unknown
    /* 12个外部中断，优先级顺序：Timer[3:0], SPI, I2C0, I2C1, UART0, UART1, GPIO0, GPIO1 */
    .word timer0_event_handler      // [0] Timer0
    .word timer1_event_handler      // [1] Timer1
    .word timer2_event_handler      // [2] Timer2
    .word timer3_event_handler      // [3] Timer3
    .word spi_event_handler         // [4] SPI
    .word i2c0_interrupt_handler    // [5] I2C0
    .word i2c1_interrupt_handler    // [6] I2C1
    .word uart0_event_handler       // [7] UART0
    .word uart1_event_handler       // [8] UART1
    .word gpio0_int_handler         // [9] GPIO0
    .word gpio1_int_handler         // [10] GPIO1


.weak illegal_instruction_handler
.weak instruction_addr_misaligned_handler
.weak ecall_handler
.weak ebreak_handler
.weak load_misaligned_handler
.weak store_misaligned_handler
.weak handle_exception_unknown
.weak timer0_event_handler
.weak timer1_event_handler
.weak timer2_event_handler
.weak timer3_event_handler
.weak spi_event_handler
.weak i2c0_interrupt_handler
.weak i2c1_interrupt_handler
.weak uart0_event_handler
.weak uart1_event_handler
.weak gpio0_int_handler
.weak gpio1_int_handler

handle_exception_unknown:
    j handle_exception_unknown

illegal_instruction_handler:
#ifdef SIMULATION
    call sim_ctrl_init
    la a0, illegal_instruction_msg
    jal ra, xputs
#endif
illegal_instruction_loop:
    j illegal_instruction_loop

instruction_addr_misaligned_handler:
    j instruction_addr_misaligned_handler

ecall_handler:
    j ecall_handler

ebreak_handler:
    j ebreak_handler

load_misaligned_handler:
    j load_misaligned_handler

store_misaligned_handler:
    j store_misaligned_handler

timer_events_handler:
    j timer_events_handler

gpio_int_handler:
    j gpio_int_handler

i2c_interrupt_handler:
    j i2c_interrupt_handler

spi_event_handler:
    j spi_event_handler

uart_event_handler:
    j uart_event_handler

/* 异常和中断总入口 */
trap_entry:
    addi sp, sp, -32*17
    sw x1,   0*4(sp)
    sw x5,   1*4(sp)
    sw x6,   2*4(sp)
    sw x7,   3*4(sp)
    sw x10,  4*4(sp)
    sw x11,  5*4(sp)
    sw x12,  6*4(sp)
    sw x13,  7*4(sp)
    sw x14,  8*4(sp)
    sw x15,  9*4(sp)
    sw x16, 10*4(sp)
    sw x17, 11*4(sp)
    sw x28, 12*4(sp)
    sw x29, 13*4(sp)
    sw x30, 14*4(sp)
    sw x31, 15*4(sp)
    /* 保存异常(中断)返回地址 */
    csrr x10, mepc
    sw x10, 16*4(sp)

    /* 使能全局中断 */
    csrrsi x0, mstatus, 0x8

    /* 读取异常(中断)号 */
    csrr a1, mcause
    /* 计算偏移地址: id * 4 */
    slli a1, a1, 2
    la a0, vector_table
    add a1, a0, a1
    /* 读取异常(中断)处理函数地址 */
    lw a1, 0(a1)
    /* 跳转到异常(中断)处理函数 */
    jalr ra, 0(a1)

    /* 恢复异常(中断)返回地址 */
    lw x10,  16*4(sp)
    csrw mepc, x10
    lw x1,   0*4(sp)
    lw x5,   1*4(sp)
    lw x6,   2*4(sp)
    lw x7,   3*4(sp)
    lw x10,  4*4(sp)
    lw x11,  5*4(sp)
    lw x12,  6*4(sp)
    lw x13,  7*4(sp)
    lw x14,  8*4(sp)
    lw x15,  9*4(sp)
    lw x16, 10*4(sp)
    lw x17, 11*4(sp)
    lw x28, 12*4(sp)
    lw x29, 13*4(sp)
    lw x30, 14*4(sp)
    lw x31, 15*4(sp)
    addi sp, sp, 32*17
    mret

#ifdef SIMULATION
.section .rodata
illegal_instruction_msg:
	.string "illegal instruction exception handler entered\n"
#endif
