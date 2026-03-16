//----------------------------------------------------------
// Title      : rv32i_ref_pkg
// Project    : RISC-V Reference Model
//----------------------------------------------------------
// Description:
// Package containing instruction types and data structures
// for the RV32I reference model.
//----------------------------------------------------------

package rv32i_ref_pkg;

    //=======================================================
    // Instruction Type Enumeration
    //=======================================================
    typedef enum logic [6:0] {
        // R-type
        I_ADD, I_SUB, I_SLL, I_SLT, I_SLTU, I_XOR, I_SRL, I_SRA, I_OR, I_AND,
        // I-type ALU
        I_ADDI, I_SLTI, I_SLTIU, I_XORI, I_ORI, I_ANDI, I_SLLI, I_SRLI, I_SRAI,
        // Load
        I_LB, I_LH, I_LW, I_LBU, I_LHU,
        // Store
        I_SB, I_SH, I_SW,
        // Branch
        I_BEQ, I_BNE, I_BLT, I_BGE, I_BLTU, I_BGEU,
        // Jump
        I_JAL, I_JALR,
        // Upper Immediate
        I_LUI, I_AUIPC,
        // System
        I_ECALL, I_EBREAK, I_FENCE,
        // Invalid/NOP
        I_NOP, I_NULL
    } t_instr_type;

    //=======================================================
    // Transaction types for checker
    //=======================================================
    typedef struct packed {
        logic        valid;
        logic [4:0]  rd;
        logic [31:0] data;
        logic [31:0] pc;          // PC of instruction that caused the write
        t_instr_type instr_type;
    } t_rf_write_txn;

    typedef struct packed {
        logic        valid;
        logic [31:0] addr;
        logic [31:0] data;
        logic [3:0]  byte_en;
        logic [31:0] pc;
        t_instr_type instr_type;
    } t_dmem_write_txn;

    typedef struct packed {
        logic        valid;
        logic [31:0] addr;
        logic [31:0] data;
        logic [3:0]  byte_en;
        logic        is_signed;
        logic [31:0] pc;
        t_instr_type instr_type;
    } t_dmem_read_txn;

    //=======================================================
    // Debug info structure
    //=======================================================
    typedef struct packed {
        logic        clk;
        logic [31:0] pc;
        logic [31:0] instruction;
        t_instr_type instr_type;
        logic [4:0]  rd;
        logic [4:0]  rs1;
        logic [4:0]  rs2;
        logic [31:0] data_rd1;
        logic [31:0] data_rd2;
        logic [31:0] mem_addr;
        logic [31:0] reg_wr_data;
    } t_debug_info;

endpackage
