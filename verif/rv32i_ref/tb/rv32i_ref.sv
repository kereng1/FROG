//----------------------------------------------------------
// Title      : rv32i_ref
// Project    : RISC-V Reference Model
//----------------------------------------------------------
// Description:
// Naive behavioral reference model for RV32I CPU.
// Executes one instruction per clock cycle.
// Outputs RF write and DMEM transactions for comparison.
//----------------------------------------------------------

`include "dff_macros.svh"

module rv32i_ref 
    import rv32i_ref_pkg::*;
#(
    parameter IMEM_SIZE_WORDS = 256,
    parameter DMEM_SIZE_BYTES = 1024,
    parameter DMEM_SIZE_WORDS = DMEM_SIZE_BYTES / 4
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        run,          // Enable execution

    // Transaction outputs (for checker comparison)
    output t_rf_write_txn   rf_write_txn,
    output t_dmem_write_txn dmem_write_txn,
    output t_dmem_read_txn  dmem_read_txn,

    // Debug outputs
    output logic [31:0] ref_pc,
    output logic [31:0] ref_instruction,
    output t_instr_type ref_instr_type
);

    //=======================================================
    // Internal State
    //=======================================================
    logic [31:0] pc, next_pc;
    logic [31:0] instruction;
    t_instr_type instr_type;

    // Memory arrays (loaded from external file)
    logic [31:0] imem [0:IMEM_SIZE_WORDS-1];
    logic [31:0] dmem [0:DMEM_SIZE_WORDS-1];
    logic [31:0] next_dmem [0:DMEM_SIZE_WORDS-1];

    // Register file (x0 is hardwired to 0)
    logic [31:0] regfile [0:31];
    logic [31:0] next_regfile [0:31];

    // End of simulation flag
    logic ebreak_called;
    logic ecall_called;

    //=======================================================
    // Instruction Fields
    //=======================================================
    logic [6:0]  opcode;
    logic [4:0]  rd, rs1, rs2;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [31:0] data_rd1, data_rd2;

    // Immediate values
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    // Memory addresses
    logic [31:0] mem_rd_addr, mem_wr_addr;

    // Control signals
    logic        reg_wr_en;
    logic        dmem_wr_en;
    logic        dmem_rd_en;
    logic [3:0]  dmem_byte_en;
    logic        dmem_is_signed;
    logic [31:0] reg_wr_data;

    //=======================================================
    // Instruction Decode
    //=======================================================
    assign instruction = imem[pc[31:2]];
    assign opcode  = instruction[6:0];
    assign rd      = instruction[11:7];
    assign rs1     = instruction[19:15];
    assign rs2     = instruction[24:20];
    assign funct3  = instruction[14:12];
    assign funct7  = instruction[31:25];

    // Register read (x0 always returns 0)
    assign data_rd1 = (rs1 == 5'd0) ? 32'd0 : regfile[rs1];
    assign data_rd2 = (rs2 == 5'd0) ? 32'd0 : regfile[rs2];

    // Immediate generation
    assign imm_i = {{20{instruction[31]}}, instruction[31:20]};
    assign imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
    assign imm_b = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    assign imm_u = {instruction[31:12], 12'b0};
    assign imm_j = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};

    // Memory addresses
    assign mem_rd_addr = data_rd1 + imm_i;
    assign mem_wr_addr = data_rd1 + imm_s;

    //=======================================================
    // Load Data from Memory
    //=======================================================
    logic [31:0] dmem_word;
    logic [1:0]  byte_offset;
    logic [31:0] lb_data, lh_data, lw_data, lbu_data, lhu_data;

    assign dmem_word = dmem[mem_rd_addr[31:2]];
    assign byte_offset = mem_rd_addr[1:0];

    // Extract and sign-extend byte
    always_comb begin
        case (byte_offset)
            2'b00: lb_data = {{24{dmem_word[7]}},  dmem_word[7:0]};
            2'b01: lb_data = {{24{dmem_word[15]}}, dmem_word[15:8]};
            2'b10: lb_data = {{24{dmem_word[23]}}, dmem_word[23:16]};
            2'b11: lb_data = {{24{dmem_word[31]}}, dmem_word[31:24]};
        endcase
    end

    // Extract and zero-extend byte
    always_comb begin
        case (byte_offset)
            2'b00: lbu_data = {24'd0, dmem_word[7:0]};
            2'b01: lbu_data = {24'd0, dmem_word[15:8]};
            2'b10: lbu_data = {24'd0, dmem_word[23:16]};
            2'b11: lbu_data = {24'd0, dmem_word[31:24]};
        endcase
    end

    // Extract and sign-extend halfword
    always_comb begin
        case (byte_offset[1])
            1'b0: lh_data = {{16{dmem_word[15]}}, dmem_word[15:0]};
            1'b1: lh_data = {{16{dmem_word[31]}}, dmem_word[31:16]};
        endcase
    end

    // Extract and zero-extend halfword
    always_comb begin
        case (byte_offset[1])
            1'b0: lhu_data = {16'd0, dmem_word[15:0]};
            1'b1: lhu_data = {16'd0, dmem_word[31:16]};
        endcase
    end

    // Word load
    assign lw_data = dmem_word;

    //=======================================================
    // Main Execution Logic
    //=======================================================
    always_comb begin
        // Default values
        next_pc         = pc + 4;
        next_regfile    = regfile;
        next_dmem       = dmem;
        reg_wr_en       = 1'b0;
        reg_wr_data     = 32'd0;
        dmem_wr_en      = 1'b0;
        dmem_rd_en      = 1'b0;
        dmem_byte_en    = 4'b0000;
        dmem_is_signed  = 1'b0;
        ebreak_called   = 1'b0;
        ecall_called    = 1'b0;
        instr_type      = I_NOP;

        // Default: preserve x0 as zero
        next_regfile[0] = 32'd0;

        casez (instruction)
            //===============================================
            // LUI
            //===============================================
            32'b????????????????????_?????_0110111: begin
                instr_type       = I_LUI;
                next_regfile[rd] = imm_u;
                reg_wr_en        = 1'b1;
                reg_wr_data      = imm_u;
            end

            //===============================================
            // AUIPC
            //===============================================
            32'b????????????????????_?????_0010111: begin
                instr_type       = I_AUIPC;
                next_regfile[rd] = pc + imm_u;
                reg_wr_en        = 1'b1;
                reg_wr_data      = pc + imm_u;
            end

            //===============================================
            // JAL
            //===============================================
            32'b????????????????????_?????_1101111: begin
                instr_type       = I_JAL;
                next_regfile[rd] = pc + 4;
                reg_wr_en        = 1'b1;
                reg_wr_data      = pc + 4;
                next_pc          = pc + imm_j;
            end

            //===============================================
            // JALR
            //===============================================
            32'b????????????_?????_000_?????_1100111: begin
                instr_type       = I_JALR;
                next_regfile[rd] = pc + 4;
                reg_wr_en        = 1'b1;
                reg_wr_data      = pc + 4;
                next_pc          = (data_rd1 + imm_i) & 32'hFFFFFFFE; // Clear LSB
            end

            //===============================================
            // Branch Instructions
            //===============================================
            32'b???????_?????_?????_000_?????_1100011: begin // BEQ
                instr_type = I_BEQ;
                if (data_rd1 == data_rd2) next_pc = pc + imm_b;
            end
            32'b???????_?????_?????_001_?????_1100011: begin // BNE
                instr_type = I_BNE;
                if (data_rd1 != data_rd2) next_pc = pc + imm_b;
            end
            32'b???????_?????_?????_100_?????_1100011: begin // BLT
                instr_type = I_BLT;
                if ($signed(data_rd1) < $signed(data_rd2)) next_pc = pc + imm_b;
            end
            32'b???????_?????_?????_101_?????_1100011: begin // BGE
                instr_type = I_BGE;
                if ($signed(data_rd1) >= $signed(data_rd2)) next_pc = pc + imm_b;
            end
            32'b???????_?????_?????_110_?????_1100011: begin // BLTU
                instr_type = I_BLTU;
                if (data_rd1 < data_rd2) next_pc = pc + imm_b;
            end
            32'b???????_?????_?????_111_?????_1100011: begin // BGEU
                instr_type = I_BGEU;
                if (data_rd1 >= data_rd2) next_pc = pc + imm_b;
            end

            //===============================================
            // Load Instructions
            //===============================================
            32'b???????_?????_?????_000_?????_0000011: begin // LB
                instr_type       = I_LB;
                next_regfile[rd] = lb_data;
                reg_wr_en        = 1'b1;
                reg_wr_data      = lb_data;
                dmem_rd_en       = 1'b1;
                dmem_byte_en     = 4'b0001;
                dmem_is_signed   = 1'b1;
            end
            32'b???????_?????_?????_001_?????_0000011: begin // LH
                instr_type       = I_LH;
                next_regfile[rd] = lh_data;
                reg_wr_en        = 1'b1;
                reg_wr_data      = lh_data;
                dmem_rd_en       = 1'b1;
                dmem_byte_en     = 4'b0011;
                dmem_is_signed   = 1'b1;
            end
            32'b???????_?????_?????_010_?????_0000011: begin // LW
                instr_type       = I_LW;
                next_regfile[rd] = lw_data;
                reg_wr_en        = 1'b1;
                reg_wr_data      = lw_data;
                dmem_rd_en       = 1'b1;
                dmem_byte_en     = 4'b1111;
                dmem_is_signed   = 1'b0;
            end
            32'b???????_?????_?????_100_?????_0000011: begin // LBU
                instr_type       = I_LBU;
                next_regfile[rd] = lbu_data;
                reg_wr_en        = 1'b1;
                reg_wr_data      = lbu_data;
                dmem_rd_en       = 1'b1;
                dmem_byte_en     = 4'b0001;
                dmem_is_signed   = 1'b0;
            end
            32'b???????_?????_?????_101_?????_0000011: begin // LHU
                instr_type       = I_LHU;
                next_regfile[rd] = lhu_data;
                reg_wr_en        = 1'b1;
                reg_wr_data      = lhu_data;
                dmem_rd_en       = 1'b1;
                dmem_byte_en     = 4'b0011;
                dmem_is_signed   = 1'b0;
            end

            //===============================================
            // Store Instructions
            //===============================================
            32'b???????_?????_?????_000_?????_0100011: begin // SB
                instr_type   = I_SB;
                dmem_wr_en   = 1'b1;
                dmem_byte_en = 4'b0001;
                case (mem_wr_addr[1:0])
                    2'b00: next_dmem[mem_wr_addr[31:2]][7:0]   = data_rd2[7:0];
                    2'b01: next_dmem[mem_wr_addr[31:2]][15:8]  = data_rd2[7:0];
                    2'b10: next_dmem[mem_wr_addr[31:2]][23:16] = data_rd2[7:0];
                    2'b11: next_dmem[mem_wr_addr[31:2]][31:24] = data_rd2[7:0];
                endcase
            end
            32'b???????_?????_?????_001_?????_0100011: begin // SH
                instr_type   = I_SH;
                dmem_wr_en   = 1'b1;
                dmem_byte_en = 4'b0011;
                case (mem_wr_addr[1])
                    1'b0: next_dmem[mem_wr_addr[31:2]][15:0]  = data_rd2[15:0];
                    1'b1: next_dmem[mem_wr_addr[31:2]][31:16] = data_rd2[15:0];
                endcase
            end
            32'b???????_?????_?????_010_?????_0100011: begin // SW
                instr_type   = I_SW;
                dmem_wr_en   = 1'b1;
                dmem_byte_en = 4'b1111;
                next_dmem[mem_wr_addr[31:2]] = data_rd2;
            end

            //===============================================
            // I-Type ALU Instructions
            //===============================================
            32'b???????_?????_?????_000_?????_0010011: begin // ADDI
                instr_type       = I_ADDI;
                next_regfile[rd] = data_rd1 + imm_i;
                reg_wr_en        = 1'b1;
                reg_wr_data      = data_rd1 + imm_i;
            end
            32'b???????_?????_?????_010_?????_0010011: begin // SLTI
                instr_type       = I_SLTI;
                next_regfile[rd] = ($signed(data_rd1) < $signed(imm_i)) ? 32'd1 : 32'd0;
                reg_wr_en        = 1'b1;
                reg_wr_data      = ($signed(data_rd1) < $signed(imm_i)) ? 32'd1 : 32'd0;
            end
            32'b???????_?????_?????_011_?????_0010011: begin // SLTIU
                instr_type       = I_SLTIU;
                next_regfile[rd] = (data_rd1 < imm_i) ? 32'd1 : 32'd0;
                reg_wr_en        = 1'b1;
                reg_wr_data      = (data_rd1 < imm_i) ? 32'd1 : 32'd0;
            end
            32'b???????_?????_?????_100_?????_0010011: begin // XORI
                instr_type       = I_XORI;
                next_regfile[rd] = data_rd1 ^ imm_i;
                reg_wr_en        = 1'b1;
                reg_wr_data      = data_rd1 ^ imm_i;
            end
            32'b???????_?????_?????_110_?????_0010011: begin // ORI
                instr_type       = I_ORI;
                next_regfile[rd] = data_rd1 | imm_i;
                reg_wr_en        = 1'b1;
                reg_wr_data      = data_rd1 | imm_i;
            end
            32'b???????_?????_?????_111_?????_0010011: begin // ANDI
                instr_type       = I_ANDI;
                next_regfile[rd] = data_rd1 & imm_i;
                reg_wr_en        = 1'b1;
                reg_wr_data      = data_rd1 & imm_i;
            end
            32'b0000000_?????_?????_001_?????_0010011: begin // SLLI
                instr_type       = I_SLLI;
                next_regfile[rd] = data_rd1 << imm_i[4:0];
                reg_wr_en        = 1'b1;
                reg_wr_data      = data_rd1 << imm_i[4:0];
            end
            32'b0000000_?????_?????_101_?????_0010011: begin // SRLI
                instr_type       = I_SRLI;
                next_regfile[rd] = data_rd1 >> imm_i[4:0];
                reg_wr_en        = 1'b1;
                reg_wr_data      = data_rd1 >> imm_i[4:0];
            end
            32'b0100000_?????_?????_101_?????_0010011: begin // SRAI
                instr_type       = I_SRAI;
                next_regfile[rd] = $signed(data_rd1) >>> imm_i[4:0];
                reg_wr_en        = 1'b1;
                reg_wr_data      = $signed(data_rd1) >>> imm_i[4:0];
            end

            //===============================================
            // R-Type ALU Instructions
            //===============================================
            32'b0000000_?????_?????_000_?????_0110011: begin // ADD
                instr_type       = I_ADD;
                next_regfile[rd] = data_rd1 + data_rd2;
                reg_wr_en        = 1'b1;
                reg_wr_data      = data_rd1 + data_rd2;
            end
            32'b0100000_?????_?????_000_?????_0110011: begin // SUB
                instr_type       = I_SUB;
                next_regfile[rd] = data_rd1 - data_rd2;
                reg_wr_en        = 1'b1;
                reg_wr_data      = data_rd1 - data_rd2;
            end
            32'b0000000_?????_?????_001_?????_0110011: begin // SLL
                instr_type       = I_SLL;
                next_regfile[rd] = data_rd1 << data_rd2[4:0];
                reg_wr_en        = 1'b1;
                reg_wr_data      = data_rd1 << data_rd2[4:0];
            end
            32'b0000000_?????_?????_010_?????_0110011: begin // SLT
                instr_type       = I_SLT;
                next_regfile[rd] = ($signed(data_rd1) < $signed(data_rd2)) ? 32'd1 : 32'd0;
                reg_wr_en        = 1'b1;
                reg_wr_data      = ($signed(data_rd1) < $signed(data_rd2)) ? 32'd1 : 32'd0;
            end
            32'b0000000_?????_?????_011_?????_0110011: begin // SLTU
                instr_type       = I_SLTU;
                next_regfile[rd] = (data_rd1 < data_rd2) ? 32'd1 : 32'd0;
                reg_wr_en        = 1'b1;
                reg_wr_data      = (data_rd1 < data_rd2) ? 32'd1 : 32'd0;
            end
            32'b0000000_?????_?????_100_?????_0110011: begin // XOR
                instr_type       = I_XOR;
                next_regfile[rd] = data_rd1 ^ data_rd2;
                reg_wr_en        = 1'b1;
                reg_wr_data      = data_rd1 ^ data_rd2;
            end
            32'b0000000_?????_?????_101_?????_0110011: begin // SRL
                instr_type       = I_SRL;
                next_regfile[rd] = data_rd1 >> data_rd2[4:0];
                reg_wr_en        = 1'b1;
                reg_wr_data      = data_rd1 >> data_rd2[4:0];
            end
            32'b0100000_?????_?????_101_?????_0110011: begin // SRA
                instr_type       = I_SRA;
                next_regfile[rd] = $signed(data_rd1) >>> data_rd2[4:0];
                reg_wr_en        = 1'b1;
                reg_wr_data      = $signed(data_rd1) >>> data_rd2[4:0];
            end
            32'b0000000_?????_?????_110_?????_0110011: begin // OR
                instr_type       = I_OR;
                next_regfile[rd] = data_rd1 | data_rd2;
                reg_wr_en        = 1'b1;
                reg_wr_data      = data_rd1 | data_rd2;
            end
            32'b0000000_?????_?????_111_?????_0110011: begin // AND
                instr_type       = I_AND;
                next_regfile[rd] = data_rd1 & data_rd2;
                reg_wr_en        = 1'b1;
                reg_wr_data      = data_rd1 & data_rd2;
            end

            //===============================================
            // FENCE
            //===============================================
            32'b????????????_?????_???_?????_0001111: begin
                instr_type = I_FENCE;
                // No operation needed - order is preserved
            end

            //===============================================
            // ECALL / EBREAK
            //===============================================
            32'b000000000000_00000_000_00000_1110011: begin
                instr_type   = I_ECALL;
                ecall_called = 1'b1;
            end
            32'b000000000001_00000_000_00000_1110011: begin
                instr_type    = I_EBREAK;
                ebreak_called = 1'b1;
            end

            //===============================================
            // NOP (ADDI x0, x0, 0) and Unknown
            //===============================================
            default: begin
                if (instruction == 32'h00000013)
                    instr_type = I_NOP;
                else
                    instr_type = I_NULL;
            end
        endcase

        // x0 is always zero
        next_regfile[0] = 32'd0;
    end

    //=======================================================
    // Sequential State Update
    //=======================================================
    `DFF_RST_EN(pc,      next_pc,      clk, run, rst, 32'd0)
    `DFF_RST_EN(regfile,  next_regfile, clk, run, rst, '{default: 32'd0})
    `DFF_RST_EN(dmem,     next_dmem,    clk, run, rst, '{default: 32'd0})

    //=======================================================
    // Transaction Outputs (combinational from current state)
    //=======================================================
    always_comb begin
        rf_write_txn.valid      = reg_wr_en && run && !rst;  // include x0 writes (retired, no RF effect)
        rf_write_txn.rd         = rd;
        rf_write_txn.data       = reg_wr_data;
        rf_write_txn.pc         = pc;
        rf_write_txn.instr_type = instr_type;

        dmem_write_txn.valid      = dmem_wr_en && run && !rst;
        dmem_write_txn.addr       = mem_wr_addr;
        dmem_write_txn.data       = data_rd2;
        dmem_write_txn.byte_en    = dmem_byte_en;
        dmem_write_txn.pc         = pc;
        dmem_write_txn.instr_type = instr_type;

        dmem_read_txn.valid      = dmem_rd_en && run && !rst;
        dmem_read_txn.addr       = mem_rd_addr;
        dmem_read_txn.data       = reg_wr_data;
        dmem_read_txn.byte_en    = dmem_byte_en;
        dmem_read_txn.is_signed  = dmem_is_signed;
        dmem_read_txn.pc         = pc;
        dmem_read_txn.instr_type = instr_type;
    end

    //=======================================================
    // Debug Outputs
    //=======================================================
    assign ref_pc          = pc;
    assign ref_instruction = instruction;
    assign ref_instr_type  = instr_type;

endmodule
