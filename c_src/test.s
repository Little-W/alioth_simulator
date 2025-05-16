.section .data
val1: .word 10
val2: .word 5
val3: .word 0xF0F0F0F0
val4: .word 0x0F0F0F0F

.section .text
.globl _start
_start:
    li t0, 10         # 验证 lui + addi
    li t1, 5

    # ----------------
    # RV32I 算术指令
    # ----------------
    add t2, t0, t1     # 10 + 5 = 15
    sub t3, t0, t1     # 10 - 5 = 5
    xor t4, t0, t1     # 10 ^ 5 = 15
    or  t5, t0, t1     # 10 | 5 = 15
    and t6, t0, t1     # 10 & 5 = 0

    # 修复: 使用a0-a7寄存器代替t7
    sll a0, t0, t1     # 10 << 5 = 320
    srl t0, t0, t1     # 10 >> 5 = 0
    li  t1, -8
    sra t1, t1, 1      # -8 >> 1 (算术右移) = -4

    slt t2, t1, t0     # -4 < 0 => t2 = 1
    sltu t3, t1, t0    # 无符号 -4 < 0 => t3 = 0（因为 -4 变为很大的无符号）

    # ----------------
    # RV32I 立即数变种
    # ----------------
    li   t0, 100
    addi t1, t0, -50   # 100 - 50 = 50
    andi t2, t0, 0xF0  # 100 & 0xF0 = 0x60
    ori  t3, t0, 0x0F  # 100 | 0x0F = 0x6F
    xori t4, t0, 0xFF  # 100 ^ 0xFF = 0x9B

    slli t5, t0, 2     # 100 << 2 = 400
    srli t6, t0, 3     # 100 >> 3 = 12
    # 修复: 使用a1寄存器代替t7
    srai a1, t0, 3     # 算术右移 100 >> 3 = 12

    slti  t1, t0, 200  # 100 < 200 -> 1
    sltiu t2, t0, -1   # 100 < 0xFFFFFFFFu -> 1

    # ----------------
    # RV32I 内存访问
    # ----------------
    la   t3, val1
    lw   t4, 0(t3)     # load val1 = 10
    sw   t4, 4(t3)     # store 10 到 val2

    lb   t5, 0(t3)     # 10 => 0x0A
    lbu  t6, 0(t3)     # 同上，但零扩展
    # 修复: 使用a2寄存器代替t7
    lh   a2, 0(t3)     # 10
    lhu  t0, 0(t3)

    # ----------------
    # RV32I 跳转与分支
    # ----------------
    li   t0, 1
    li   t1, 1
    beq  t0, t1, label_equal    # 应该跳转
    li   t2, 99                 # 不应执行

label_equal:
    li   t2, 88                 # 正确跳转到这里

    bne  t0, t1, label_never    # 不跳转
    li   t3, 77                 # 应执行

    li   t0, 5
    li   t1, 3
    blt  t1, t0, label_blt      # 3 < 5, 跳
    li   t4, 66                 # 不执行

label_blt:
    li   t4, 55                 # 应执行

    # ----------------
    # RV32I 跳转指令
    # ----------------
    jal  t5, after_jal
    li   t6, 123                # 不应执行
after_jal:
    li   t6, 0xAB               # 正确执行

    la   t0, after_jalr
    jalr t1, t0
    li   t2, 99
after_jalr:
    li   t2, 0xCD               # 正确执行

    # ----------------
    # RV32M 乘除指令
    # ----------------
    li   t0, 6
    li   t1, 3
    mul  t3, t0, t1             # 6 * 3 = 18
    mulh t4, t0, t1             # 高位结果（符号）
    mulhu t5, t0, t1            # 高位结果（无符号）
    mulhsu t6, t0, t1           # 高位结果（混合）

    # 修复: 使用a3寄存器代替t7
    div  a3, t0, t1             # 6 / 3 = 2
    rem  t0, t0, t1             # 6 % 3 = 0

    li   t0, -7
    li   t1, 2
    divu t1, t0, t1             # -7 interpreted as large unsigned >> 2
    remu t2, t0, t1

    # ----------------
    # 模拟结束（陷入死循环）
    # ----------------
label_never:
end:
    j end
