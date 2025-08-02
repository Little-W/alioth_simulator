.section .text
    .globl _start
_start:
    # ITCM/DTCM地址范围
    li t0, 0x80000000      # ITCM_START
    li t2, 0x80100000      # DTCM_START

    # 统一先加载所有数据
    li s1, 0x11111111
    li s2, 0x22222222
    li s3, 0x33333333
    li s4, 0x44444444
    li s5, 0xAAAAAAA1
    li s6, 0xAAAAAAA2
    li s7, 0xAAAAAAA3
    li s8, 0xAAAAAAA4

    # ITCM和DTCM连续写入（写入指令连续），偏移0x000
    li t0, 0x80000000
    li t2, 0x80100000
    sw s1, 0(t0)
    sw s2, 4(t0)
    sw s3, 8(t0)
    sw s4, 12(t0)
    sw s5, 0(t2)
    sw s6, 4(t2)
    sw s7, 8(t2)
    sw s8, 12(t2)

    # ITCM和DTCM连续读取（读取指令连续）
    lw a1, 0(t0)
    lw a2, 4(t0)
    lw a3, 8(t0)
    lw a4, 12(t0)
    lw a5, 0(t2)
    lw a6, 4(t2)
    lw a7, 8(t2)
    lw s9, 12(t2)

    # 统一校验
    bne a1, s1, fail
    bne a2, s2, fail
    bne a3, s3, fail
    bne a4, s4, fail
    bne a5, s5, fail
    bne a6, s6, fail
    bne a7, s7, fail
    bne s9, s8, fail

    # 隔离
    nop; nop; nop; nop

    # ITCM/DTCM交错写入，偏移0x100
    li t0, 0x80000100
    li t2, 0x80100100
    sw s1, 0(t0)
    sw s5, 0(t2)
    sw s2, 4(t0)
    sw s6, 4(t2)
    sw s3, 8(t0)
    sw s7, 8(t2)
    sw s4, 12(t0)
    sw s8, 12(t2)

    # ITCM/DTCM交错读取
    lw a1, 0(t0)
    lw a5, 0(t2)
    lw a2, 4(t0)
    lw a6, 4(t2)
    lw a3, 8(t0)
    lw a7, 8(t2)
    lw a4, 12(t0)
    lw s9, 12(t2)

    # 校验
    bne a1, s1, fail
    bne a2, s2, fail
    bne a3, s3, fail
    bne a4, s4, fail
    bne a5, s5, fail
    bne a6, s6, fail
    bne a7, s7, fail
    bne s9, s8, fail

    # 隔离
    nop; nop; nop; nop

    # 单区域（ITCM）读写交错，偏移0x200
    li t0, 0x80000200
    sw s1, 0(t0)
    lw a1, 0(t0)
    sw s2, 4(t0)
    lw a2, 4(t0)
    sw s3, 8(t0)
    lw a3, 8(t0)
    sw s4, 12(t0)
    lw a4, 12(t0)

    # 校验
    bne a1, s1, fail
    bne a2, s2, fail
    bne a3, s3, fail
    bne a4, s4, fail

    # 隔离
    nop; nop; nop; nop

    # 单区域（DTCM）写后读交错，偏移0x300
    li t2, 0x80100300
    sw s5, 0(t2)
    sw s6, 4(t2)
    lw a5, 0(t2)
    sw s7, 8(t2)
    lw a6, 4(t2)
    sw s8, 12(t2)
    lw a7, 8(t2)
    lw s9, 12(t2)

    # 校验
    bne a5, s5, fail
    bne a6, s6, fail
    bne a7, s7, fail
    bne s9, s8, fail

    # 隔离
    nop; nop; nop; nop

    # 双区域写后读交错，偏移0x400
    li t0, 0x80000400
    li t2, 0x80100400
    sw s1, 0(t0)
    sw s5, 0(t2)
    lw a1, 0(t0)
    sw s2, 4(t0)
    lw a5, 0(t2)
    sw s6, 4(t2)
    lw a2, 4(t0)
    sw s3, 8(t0)
    lw a6, 4(t2)
    sw s7, 8(t2)
    lw a3, 8(t0)
    sw s4, 12(t0)
    lw a7, 8(t2)
    sw s8, 12(t2)
    lw a4, 12(t0)
    lw s9, 12(t2)

    # 校验
    bne a1, s1, fail
    bne a2, s2, fail
    bne a3, s3, fail
    bne a4, s4, fail
    bne a5, s5, fail
    bne a6, s6, fail
    bne a7, s7, fail
    bne s9, s8, fail

    j pass

pass:
    j 4

fail:
    j 8
