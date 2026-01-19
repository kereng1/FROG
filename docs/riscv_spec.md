# RISC-V RV32I Base Integer ISA

## Instruction Formats

### R-type
| 31:25   | 24:20 | 19:15 | 14:12  | 11:7 | 6:0    |
|---------|-------|-------|--------|------|--------|
| funct7  | rs2   | rs1   | funct3 | rd   | opcode |

### I-type
| 31:20    | 19:15 | 14:12  | 11:7 | 6:0    |
|----------|-------|--------|------|--------|
| imm[11:0]| rs1   | funct3 | rd   | opcode |

### S-type
| 31:25     | 24:20 | 19:15 | 14:12  | 11:7     | 6:0    |
|-----------|-------|-------|--------|----------|--------|
| imm[11:5] | rs2   | rs1   | funct3 | imm[4:0] | opcode |

### B-type
| 31:25        | 24:20 | 19:15 | 14:12  | 11:7        | 6:0    |
|--------------|-------|-------|--------|-------------|--------|
| imm[12,10:5] | rs2   | rs1   | funct3 | imm[4:1,11] | opcode |

### U-type
| 31:12      | 11:7 | 6:0    |
|------------|------|--------|
| imm[31:12] | rd   | opcode |

### J-type
| 31:12             | 11:7 | 6:0    |
|-------------------|------|--------|
| imm[20,10:1,11,19:12] | rd   | opcode |

---

## Complete Instruction Table

### R-Type Instructions (opcode = 0110011 = R_OP)

| Instruction | funct7    | funct3 | Operation           |
|-------------|-----------|--------|---------------------|
| ADD         | 0000000   | 000    | rd = rs1 + rs2      |
| SUB         | 0100000   | 000    | rd = rs1 - rs2      |
| SLL         | 0000000   | 001    | rd = rs1 << rs2[4:0]|
| SLT         | 0000000   | 010    | rd = (rs1 < rs2) ? 1 : 0 (signed) |
| SLTU        | 0000000   | 011    | rd = (rs1 < rs2) ? 1 : 0 (unsigned) |
| XOR         | 0000000   | 100    | rd = rs1 ^ rs2      |
| SRL         | 0000000   | 101    | rd = rs1 >> rs2[4:0] (logical) |
| SRA         | 0100000   | 101    | rd = rs1 >> rs2[4:0] (arithmetic) |
| OR          | 0000000   | 110    | rd = rs1 \| rs2     |
| AND         | 0000000   | 111    | rd = rs1 & rs2      |

### I-Type ALU Instructions (opcode = 0010011 = I_OP)

| Instruction | imm[11:5] | funct3 | Operation           |
|-------------|-----------|--------|---------------------|
| ADDI        | -         | 000    | rd = rs1 + imm      |
| SLTI        | -         | 010    | rd = (rs1 < imm) ? 1 : 0 (signed) |
| SLTIU       | -         | 011    | rd = (rs1 < imm) ? 1 : 0 (unsigned) |
| XORI        | -         | 100    | rd = rs1 ^ imm      |
| ORI         | -         | 110    | rd = rs1 \| imm     |
| ANDI        | -         | 111    | rd = rs1 & imm      |
| SLLI        | 0000000   | 001    | rd = rs1 << imm[4:0]|
| SRLI        | 0000000   | 101    | rd = rs1 >> imm[4:0] (logical) |
| SRAI        | 0100000   | 101    | rd = rs1 >> imm[4:0] (arithmetic) |

### Load Instructions (opcode = 0000011 = LOAD)

| Instruction | funct3 | Operation                    |
|-------------|--------|------------------------------|
| LB          | 000    | rd = SignExt(mem[rs1+imm][7:0]) |
| LH          | 001    | rd = SignExt(mem[rs1+imm][15:0]) |
| LW          | 010    | rd = mem[rs1+imm][31:0]      |
| LBU         | 100    | rd = ZeroExt(mem[rs1+imm][7:0]) |
| LHU         | 101    | rd = ZeroExt(mem[rs1+imm][15:0]) |

### Store Instructions (opcode = 0100011 = STORE)

| Instruction | funct3 | Operation                    |
|-------------|--------|------------------------------|
| SB          | 000    | mem[rs1+imm][7:0] = rs2[7:0] |
| SH          | 001    | mem[rs1+imm][15:0] = rs2[15:0] |
| SW          | 010    | mem[rs1+imm][31:0] = rs2[31:0] |

### Branch Instructions (opcode = 1100011 = BRANCH)

| Instruction | funct3 | Operation                    |
|-------------|--------|------------------------------|
| BEQ         | 000    | if (rs1 == rs2) PC += imm    |
| BNE         | 001    | if (rs1 != rs2) PC += imm    |
| BLT         | 100    | if (rs1 < rs2) PC += imm (signed) |
| BGE         | 101    | if (rs1 >= rs2) PC += imm (signed) |
| BLTU        | 110    | if (rs1 < rs2) PC += imm (unsigned) |
| BGEU        | 111    | if (rs1 >= rs2) PC += imm (unsigned) |

### Jump Instructions

| Instruction | opcode  | Type | Operation              |
|-------------|---------|------|------------------------|
| JAL         | 1101111 | J    | rd = PC+4; PC += imm   |
| JALR        | 1100111 | I    | rd = PC+4; PC = (rs1+imm) & ~1 |

### Upper Immediate Instructions

| Instruction | opcode  | Type | Operation              |
|-------------|---------|------|------------------------|
| LUI         | 0110111 | U    | rd = imm << 12         |
| AUIPC       | 0010111 | U    | rd = PC + (imm << 12)  |

### System Instructions (opcode = 1110011 = SYSTEM)

| Instruction | imm[11:0]    | funct3 | Operation           |
|-------------|--------------|--------|---------------------|
| ECALL       | 000000000000 | 000    | Environment call    |
| EBREAK      | 000000000001 | 000    | Debugger breakpoint |

---

## Opcode Map Summary

| opcode    | Hex  | Type   | Instructions          |
|-----------|------|--------|-----------------------|
| 0110111   | 0x37 | U      | LUI                   |
| 0010111   | 0x17 | U      | AUIPC                 |
| 1101111   | 0x6F | J      | JAL                   |
| 1100111   | 0x67 | I      | JALR                  |
| 1100011   | 0x63 | B      | BEQ/BNE/BLT/BGE/BLTU/BGEU |
| 0000011   | 0x03 | I      | LB/LH/LW/LBU/LHU      |
| 0100011   | 0x23 | S      | SB/SH/SW              |
| 0010011   | 0x13 | I      | ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI |
| 0110011   | 0x33 | R      | ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND |
| 1110011   | 0x73 | I      | ECALL/EBREAK          |

---

## Registers

| Register | ABI Name | Description          |
|----------|----------|----------------------|
| x0       | zero     | Hardwired zero       |
| x1       | ra       | Return address       |
| x2       | sp       | Stack pointer        |
| x3       | gp       | Global pointer       |
| x4       | tp       | Thread pointer       |
| x5-x7    | t0-t2    | Temporaries          |
| x8       | s0/fp    | Saved / Frame pointer|
| x9       | s1       | Saved register       |
| x10-x11  | a0-a1    | Args / Return values |
| x12-x17  | a2-a7    | Arguments            |
| x18-x27  | s2-s11   | Saved registers      |
| x28-x31  | t3-t6    | Temporaries          |

