# =============================================================================
# RV32I Comprehensive Test Program
# =============================================================================
# This file tests all RV32I instructions supported by the assembler.
# Use with: python3 tools/assembler.py verif/rv_cpu/input.asm
#           python3 tools/machine2sv.py output_tools/input.txt -o output_tools/load_mem.sv
# =============================================================================

# -----------------------------------------------------------------------------
# Test 1: I-type ALU - Immediate Operations
# -----------------------------------------------------------------------------
    addi  x1, x0, 10          # x1 = 0 + 10 = 10
    addi  x2, x0, 20          # x2 = 0 + 20 = 20
    addi  x3, x0, -1          # x3 = 0 + (-1) = -1 (0xFFFFFFFF)
    slti  x4, x1, 15          # x4 = (10 < 15) ? 1 : 0 = 1
    slti  x5, x1, 5           # x5 = (10 < 5) ? 1 : 0 = 0
    sltiu x6, x1, 15          # x6 = (10 <u 15) ? 1 : 0 = 1 (unsigned)
    xori  x7, x1, 0xFF        # x7 = 10 ^ 255 = 0x0A ^ 0xFF = 245
    ori   x8, x1, 0xFF        # x8 = 10 | 255 = 0x0A | 0xFF = 255
    andi  x9, x1, 0x0F        # x9 = 10 & 15 = 0x0A & 0x0F = 10

# -----------------------------------------------------------------------------
# Test 2: I-type Shift - Immediate Shifts
# -----------------------------------------------------------------------------
    slli  x10, x1, 2          # x10 = 10 << 2 = 40
    srli  x11, x1, 1          # x11 = 10 >> 1 = 5 (logical)
    srai  x12, x3, 4          # x12 = -1 >>> 4 = -1 (arithmetic, sign-extended)

# -----------------------------------------------------------------------------
# Test 3: R-type ALU - Register Operations
# -----------------------------------------------------------------------------
    add   x13, x1, x2         # x13 = x1 + x2 = 10 + 20 = 30
    sub   x14, x2, x1         # x14 = x2 - x1 = 20 - 10 = 10
    sll   x15, x1, x2         # x15 = x1 << (x2 & 31) = 10 << 20 = 10485760
    slt   x16, x1, x2         # x16 = (x1 < x2) ? 1 : 0 = (10 < 20) = 1
    sltu  x17, x1, x2         # x17 = (x1 <u x2) ? 1 : 0 = 1 (unsigned)
    xor   x18, x1, x2         # x18 = x1 ^ x2 = 10 ^ 20 = 30
    srl   x19, x1, x2         # x19 = x1 >> (x2 & 31) = 10 >> 20 = 0
    sra   x20, x3, x1         # x20 = x3 >>> (x1 & 31) = -1 >>> 10 = -1
    or    x21, x1, x2         # x21 = x1 | x2 = 10 | 20 = 30
    and   x22, x1, x2         # x22 = x1 & x2 = 10 & 20 = 0

# -----------------------------------------------------------------------------
# Test 4: U-type - Upper Immediate
# -----------------------------------------------------------------------------
    lui   x23, 0x12345        # x23 = 0x12345 << 12 = 0x12345000
    auipc x24, 0              # x24 = PC + 0 = 0x5C (current address)

# -----------------------------------------------------------------------------
# Test 5: Store and Load Operations
# -----------------------------------------------------------------------------
    sw    x13, 0(x0)          # MEM[0] = x13 = 30 (store word)
    sh    x13, 4(x0)          # MEM[4] = x13[15:0] = 30 (store half)
    sb    x13, 8(x0)          # MEM[8] = x13[7:0] = 30 (store byte)
    
    lw    x25, 0(x0)          # x25 = MEM[0] = 30 (load word)
    lh    x26, 4(x0)          # x26 = sign_ext(MEM[4]) = 30 (load half signed)
    lhu   x27, 4(x0)          # x27 = zero_ext(MEM[4]) = 30 (load half unsigned)
    lb    x28, 8(x0)          # x28 = sign_ext(MEM[8]) = 30 (load byte signed)
    lbu   x29, 8(x0)          # x29 = zero_ext(MEM[8]) = 30 (load byte unsigned)

# -----------------------------------------------------------------------------
# Test 6: Branch Instructions (Not Taken)
# -----------------------------------------------------------------------------
    beq   x1, x2, skip1       # if x1 == x2 goto skip1 (10 != 20, NOT taken)
    addi  x30, x0, 1          # x30 = 1 (executes because branch not taken)
skip1:
    bne   x1, x1, skip2       # if x1 != x1 goto skip2 (10 == 10, NOT taken)
    addi  x31, x0, 2          # x31 = 2 (executes because branch not taken)
skip2:

# -----------------------------------------------------------------------------
# Test 7: Branch Instructions (Taken) - Reset test values
# -----------------------------------------------------------------------------
    addi  x1, x0, 5           # x1 = 5 (reset for branch tests)
    addi  x2, x0, 10          # x2 = 10

    beq   x1, x1, beq_target  # if x1 == x1 goto beq_target (5 == 5, TAKEN)
    addi  x3, x0, 99          # x3 = 99 (SKIPPED - branch taken)
beq_target:
    addi  x3, x0, 3           # x3 = 3 (branch target, executes)

    bne   x1, x2, bne_target  # if x1 != x2 goto bne_target (5 != 10, TAKEN)
    addi  x4, x0, 99          # x4 = 99 (SKIPPED - branch taken)
bne_target:
    addi  x4, x0, 4           # x4 = 4 (branch target, executes)

    blt   x1, x2, blt_target  # if x1 < x2 goto blt_target (5 < 10, TAKEN)
    addi  x5, x0, 99          # x5 = 99 (SKIPPED - branch taken)
blt_target:
    addi  x5, x0, 5           # x5 = 5 (branch target, executes)

    bge   x2, x1, bge_target  # if x2 >= x1 goto bge_target (10 >= 5, TAKEN)
    addi  x6, x0, 99          # x6 = 99 (SKIPPED - branch taken)
bge_target:
    addi  x6, x0, 6           # x6 = 6 (branch target, executes)

    bltu  x1, x2, bltu_target # if x1 <u x2 goto bltu_target (5 <u 10, TAKEN)
    addi  x7, x0, 99          # x7 = 99 (SKIPPED - branch taken)
bltu_target:
    addi  x7, x0, 7           # x7 = 7 (branch target, executes)

    bgeu  x2, x1, bgeu_target # if x2 >=u x1 goto bgeu_target (10 >=u 5, TAKEN)
    addi  x8, x0, 99          # x8 = 99 (SKIPPED - branch taken)
bgeu_target:
    addi  x8, x0, 8           # x8 = 8 (branch target, executes)

# -----------------------------------------------------------------------------
# Test 8: JAL - Jump and Link
# -----------------------------------------------------------------------------
    jal   x1, jal_target      # x1 = PC+4 = 0xE4, jump to jal_target
    addi  x9, x0, 99          # x9 = 99 (SKIPPED - flushed by JAL)
    addi  x10, x0, 99         # x10 = 99 (SKIPPED - flushed by JAL)
jal_target:
    addi  x9, x0, 9           # x9 = 9 (JAL target, executes)

# -----------------------------------------------------------------------------
# Test 9: JALR - Jump and Link Register
# -----------------------------------------------------------------------------
    auipc x10, 0              # x10 = PC = 0xF0
    addi  x10, x10, 16        # x10 = 0xF0 + 16 = 0x100 (jalr_target address)
    jalr  x11, x10, 0         # x11 = PC+4 = 0xFC, jump to x10 (0x100)
    addi  x12, x0, 99         # x12 = 99 (SKIPPED - flushed by JALR)
jalr_target:
    addi  x12, x0, 12         # x12 = 12 (JALR target, executes)

# -----------------------------------------------------------------------------
# Test 10: NOP (Pseudo-instruction)
# -----------------------------------------------------------------------------
    nop                       # No operation (addi x0, x0, 0)
    nop                       # No operation
    nop                       # No operation

# -----------------------------------------------------------------------------
# Test 11: Loop Example - Count from 0 to 5
# -----------------------------------------------------------------------------
    addi  x20, x0, 0          # x20 = 0 (counter)
    addi  x21, x0, 5          # x21 = 5 (limit)
loop:
    addi  x20, x20, 1         # x20 = x20 + 1 (increment counter)
    bne   x20, x21, loop      # if x20 != x21 goto loop (loop until x20 == 5)

# -----------------------------------------------------------------------------
# End of Program - Infinite Loop
# -----------------------------------------------------------------------------
end:
    jal   x0, end             # Jump to self (infinite loop, x0 not modified)
