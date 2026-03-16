`include "dff_macros.svh"

module rv_ctrl
    import rv_pkg::*;
(
    input  logic         clk,
    input  logic         rst,
    input  logic [31:0]  instruction_Q101H,
    input  logic         branch_cond_met_Q102H,
    output t_if_ctrl     if_ctrl,
    output t_decode_ctrl decode_ctrl,
    output t_exe_ctrl    exe_ctrl,
    output t_ma_ctrl     ma_ctrl,
    output t_wb_ctrl     wb_ctrl
);

    // Pipeline control registers
    t_ctrl ctrl_Q101H, ctrl_Q102H, ctrl_Q103H, ctrl_Q104H;
    
    // Effective control after flush/stall
    t_ctrl ctrl_Q101H_eff, ctrl_Q102H_eff;

    // Instruction fields
    logic [2:0]  func3Q101H;
    logic [6:0]  func7Q101H;
    t_opcode     opcodeQ101H;

    assign func3Q101H = instruction_Q101H[14:12];
    assign func7Q101H = instruction_Q101H[31:25];
    assign opcodeQ101H = t_opcode'(instruction_Q101H[6:0]);

    // ---------------------------------------------------------------------
    // Hazard Detection & Pipeline Control
    // ---------------------------------------------------------------------
    logic load_use_hazard;
    logic branch_taken_Q102H;
    logic flush_Q101H;
    logic flush_Q102H;
    logic stall_Q100H;
    logic stall_Q101H;
    
    // Load-use hazard: instruction in Q102H uses a register that Q103H is loading
    assign load_use_hazard = ctrl_Q103H.is_load && (
        ((ctrl_Q102H.uses_rs1 && (ctrl_Q102H.rs1 == ctrl_Q103H.rd) && (ctrl_Q103H.rd != 5'd0))) ||
        ((ctrl_Q102H.uses_rs2 && (ctrl_Q102H.rs2 == ctrl_Q103H.rd) && (ctrl_Q103H.rd != 5'd0)))
    );
    
    // Branch/jump taken detection
    assign branch_taken_Q102H = (ctrl_Q102H.is_branch && branch_cond_met_Q102H) || ctrl_Q102H.is_jump;
    
    // Flush the instruction in Q101H (fetched speculatively before branch resolved)
    assign flush_Q101H = branch_taken_Q102H;
    assign flush_Q102H = 1'b0;
    
    // Stall signals (for load-use hazard)
    assign stall_Q100H = load_use_hazard;
    assign stall_Q101H = load_use_hazard;

    // ---------------------------------------------------------------------
    // Combinational Decode: Full RV32I Instruction Set
    // ---------------------------------------------------------------------
    always_comb begin
        // Default values (NOP-like)
        ctrl_Q101H = '0;
        ctrl_Q101H.rd            = instruction_Q101H[11:7];
        ctrl_Q101H.rs1           = instruction_Q101H[19:15];
        ctrl_Q101H.rs2           = instruction_Q101H[24:20];
        ctrl_Q101H.imm_sel       = IMM_I_TYPE;
        ctrl_Q101H.sel_alu_in1   = SEL_REG_DATA1;
        ctrl_Q101H.sel_alu_in2   = SEL_IMM;
        ctrl_Q101H.alu_op        = ALU_ADD;
        ctrl_Q101H.branch_cond_op= BRANCH_COND_NONE;
        ctrl_Q101H.mem_wb_sel    = SEL_ALU_OUT;
        ctrl_Q101H.wb_sel        = SEL_WR_DATA;
        ctrl_Q101H.dmem_byte_en  = 4'b1111;
        ctrl_Q101H.dmem_wr_en    = 1'b0;
        ctrl_Q101H.dmem_rd_en    = 1'b0;
        ctrl_Q101H.reg_write_en  = 1'b0;
        ctrl_Q101H.is_load       = 1'b0;
        ctrl_Q101H.is_branch     = 1'b0;
        ctrl_Q101H.is_jump       = 1'b0;
        ctrl_Q101H.is_jalr       = 1'b0;
        ctrl_Q101H.uses_rs1      = 1'b0;
        ctrl_Q101H.uses_rs2      = 1'b0;
        ctrl_Q101H.dmem_sign_ext = 1'b0;
        ctrl_Q101H.valid         = 1'b1;

        unique case (opcodeQ101H)
            // =================================================================
            // R-Type Instructions (ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND)
            // =================================================================
            R_OP: begin
                ctrl_Q101H.sel_alu_in1  = SEL_REG_DATA1;
                ctrl_Q101H.sel_alu_in2  = SEL_REG_DATA2;
                ctrl_Q101H.reg_write_en = 1'b1;
                ctrl_Q101H.uses_rs1     = 1'b1;
                ctrl_Q101H.uses_rs2     = 1'b1;
                unique case ({func7Q101H, func3Q101H})
                    {7'b0000000, 3'b000}: ctrl_Q101H.alu_op = ALU_ADD;  // ADD
                    {7'b0100000, 3'b000}: ctrl_Q101H.alu_op = ALU_SUB;  // SUB
                    {7'b0000000, 3'b001}: ctrl_Q101H.alu_op = ALU_SLL;  // SLL
                    {7'b0000000, 3'b010}: ctrl_Q101H.alu_op = ALU_SLT;  // SLT
                    {7'b0000000, 3'b011}: ctrl_Q101H.alu_op = ALU_SLTU; // SLTU
                    {7'b0000000, 3'b100}: ctrl_Q101H.alu_op = ALU_XOR;  // XOR
                    {7'b0000000, 3'b101}: ctrl_Q101H.alu_op = ALU_SRL;  // SRL
                    {7'b0100000, 3'b101}: ctrl_Q101H.alu_op = ALU_SRA;  // SRA
                    {7'b0000000, 3'b110}: ctrl_Q101H.alu_op = ALU_OR;   // OR
                    {7'b0000000, 3'b111}: ctrl_Q101H.alu_op = ALU_AND;  // AND
                    default: begin
                        ctrl_Q101H.alu_op = ALU_ADD;
                        ctrl_Q101H.reg_write_en = 1'b0; // Invalid -> NOP
                    end
                endcase
            end

            // =================================================================
            // I-Type ALU Instructions (ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI)
            // =================================================================
            I_OP: begin
                ctrl_Q101H.sel_alu_in1  = SEL_REG_DATA1;
                ctrl_Q101H.sel_alu_in2  = SEL_IMM;
                ctrl_Q101H.imm_sel      = IMM_I_TYPE;
                ctrl_Q101H.reg_write_en = 1'b1;
                ctrl_Q101H.uses_rs1     = 1'b1;
                unique case (func3Q101H)
                    3'b000: ctrl_Q101H.alu_op = ALU_ADD;  // ADDI
                    3'b010: ctrl_Q101H.alu_op = ALU_SLT;  // SLTI
                    3'b011: ctrl_Q101H.alu_op = ALU_SLTU; // SLTIU
                    3'b100: ctrl_Q101H.alu_op = ALU_XOR;  // XORI
                    3'b110: ctrl_Q101H.alu_op = ALU_OR;   // ORI
                    3'b111: ctrl_Q101H.alu_op = ALU_AND;  // ANDI
                    3'b001: begin // SLLI
                        if (func7Q101H == 7'b0000000)
                            ctrl_Q101H.alu_op = ALU_SLL;
                        else
                            ctrl_Q101H.reg_write_en = 1'b0; // Invalid
                    end
                    3'b101: begin // SRLI / SRAI
                        if (func7Q101H == 7'b0000000)
                            ctrl_Q101H.alu_op = ALU_SRL;  // SRLI
                        else if (func7Q101H == 7'b0100000)
                            ctrl_Q101H.alu_op = ALU_SRA;  // SRAI
                        else
                            ctrl_Q101H.reg_write_en = 1'b0; // Invalid
                    end
                    default: ctrl_Q101H.reg_write_en = 1'b0; // Unsupported -> NOP
                endcase
            end

            // =================================================================
            // Load Instructions (LB, LH, LW, LBU, LHU)
            // =================================================================
            LOAD: begin
                ctrl_Q101H.sel_alu_in1  = SEL_REG_DATA1;
                ctrl_Q101H.sel_alu_in2  = SEL_IMM;
                ctrl_Q101H.imm_sel      = IMM_I_TYPE;
                ctrl_Q101H.alu_op       = ALU_ADD;
                ctrl_Q101H.dmem_rd_en   = 1'b1;
                ctrl_Q101H.reg_write_en = 1'b1;
                ctrl_Q101H.wb_sel       = SEL_DMEM_RD_DATA;
                ctrl_Q101H.is_load      = 1'b1;
                ctrl_Q101H.uses_rs1     = 1'b1;
                // Sign extension: LB, LH are signed; LBU, LHU, LW are unsigned/no-ext
                ctrl_Q101H.dmem_sign_ext = (func3Q101H == 3'b000) || (func3Q101H == 3'b001);
                unique case (func3Q101H)
                    3'b000: ctrl_Q101H.dmem_byte_en = 4'b0001; // LB
                    3'b001: ctrl_Q101H.dmem_byte_en = 4'b0011; // LH
                    3'b010: ctrl_Q101H.dmem_byte_en = 4'b1111; // LW
                    3'b100: ctrl_Q101H.dmem_byte_en = 4'b0001; // LBU
                    3'b101: ctrl_Q101H.dmem_byte_en = 4'b0011; // LHU
                    default: begin
                        ctrl_Q101H.dmem_byte_en = 4'b1111;
                        ctrl_Q101H.reg_write_en = 1'b0; // Unsupported -> NOP
                    end
                endcase
            end

            // =================================================================
            // Store Instructions (SB, SH, SW)
            // =================================================================
            STORE: begin
                ctrl_Q101H.sel_alu_in1  = SEL_REG_DATA1;
                ctrl_Q101H.sel_alu_in2  = SEL_IMM;
                ctrl_Q101H.imm_sel      = IMM_S_TYPE;
                ctrl_Q101H.alu_op       = ALU_ADD;
                ctrl_Q101H.dmem_wr_en   = 1'b1;
                ctrl_Q101H.uses_rs1     = 1'b1;
                ctrl_Q101H.uses_rs2     = 1'b1;
                unique case (func3Q101H)
                    3'b000: ctrl_Q101H.dmem_byte_en = 4'b0001; // SB
                    3'b001: ctrl_Q101H.dmem_byte_en = 4'b0011; // SH
                    3'b010: ctrl_Q101H.dmem_byte_en = 4'b1111; // SW
                    default: begin
                        ctrl_Q101H.dmem_byte_en = 4'b1111;
                        ctrl_Q101H.dmem_wr_en = 1'b0; // Unsupported -> NOP
                    end
                endcase
            end

            // =================================================================
            // Branch Instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
            // =================================================================
            BRANCH: begin
                ctrl_Q101H.sel_alu_in1  = SEL_PC;        // PC + offset
                ctrl_Q101H.sel_alu_in2  = SEL_IMM;
                ctrl_Q101H.imm_sel      = IMM_B_TYPE;
                ctrl_Q101H.alu_op       = ALU_ADD;       // Compute branch target
                ctrl_Q101H.is_branch    = 1'b1;
                ctrl_Q101H.uses_rs1     = 1'b1;
                ctrl_Q101H.uses_rs2     = 1'b1;
                unique case (func3Q101H)
                    3'b000: ctrl_Q101H.branch_cond_op = BRANCH_COND_BEQ;  // BEQ
                    3'b001: ctrl_Q101H.branch_cond_op = BRANCH_COND_BNE;  // BNE
                    3'b100: ctrl_Q101H.branch_cond_op = BRANCH_COND_BLT;  // BLT
                    3'b101: ctrl_Q101H.branch_cond_op = BRANCH_COND_BGE;  // BGE
                    3'b110: ctrl_Q101H.branch_cond_op = BRANCH_COND_BLTU; // BLTU
                    3'b111: ctrl_Q101H.branch_cond_op = BRANCH_COND_BGEU; // BGEU
                    default: ctrl_Q101H.is_branch = 1'b0; // Invalid -> NOP
                endcase
            end

            // =================================================================
            // JAL (Jump and Link)
            // =================================================================
            JAL: begin
                ctrl_Q101H.sel_alu_in1  = SEL_PC;        // PC + offset
                ctrl_Q101H.sel_alu_in2  = SEL_IMM;
                ctrl_Q101H.imm_sel      = IMM_J_TYPE;
                ctrl_Q101H.alu_op       = ALU_ADD;
                ctrl_Q101H.mem_wb_sel   = SEL_PC_PLUS4;  // rd = PC + 4
                ctrl_Q101H.reg_write_en = 1'b1;
                ctrl_Q101H.is_jump      = 1'b1;
                ctrl_Q101H.branch_cond_op = BRANCH_COND_ALWAYS;
            end

            // =================================================================
            // JALR (Jump and Link Register)
            // =================================================================
            JALR: begin
                ctrl_Q101H.sel_alu_in1  = SEL_REG_DATA1; // rs1 + offset
                ctrl_Q101H.sel_alu_in2  = SEL_IMM;
                ctrl_Q101H.imm_sel      = IMM_I_TYPE;
                ctrl_Q101H.alu_op       = ALU_ADD;
                ctrl_Q101H.mem_wb_sel   = SEL_PC_PLUS4;  // rd = PC + 4
                ctrl_Q101H.reg_write_en = 1'b1;
                ctrl_Q101H.is_jump      = 1'b1;
                ctrl_Q101H.is_jalr      = 1'b1;          // Need to mask LSB of target
                ctrl_Q101H.uses_rs1     = 1'b1;
                ctrl_Q101H.branch_cond_op = BRANCH_COND_ALWAYS;
            end

            // =================================================================
            // LUI (Load Upper Immediate)
            // =================================================================
            LUI: begin
                ctrl_Q101H.sel_alu_in1  = SEL_REG_DATA1; // Will be ignored (use 0)
                ctrl_Q101H.sel_alu_in2  = SEL_IMM;
                ctrl_Q101H.imm_sel      = IMM_U_TYPE;
                ctrl_Q101H.alu_op       = ALU_PASS_B;    // rd = imm
                ctrl_Q101H.reg_write_en = 1'b1;
            end

            // =================================================================
            // AUIPC (Add Upper Immediate to PC)
            // =================================================================
            AUIPC: begin
                ctrl_Q101H.sel_alu_in1  = SEL_PC;        // PC + imm
                ctrl_Q101H.sel_alu_in2  = SEL_IMM;
                ctrl_Q101H.imm_sel      = IMM_U_TYPE;
                ctrl_Q101H.alu_op       = ALU_ADD;
                ctrl_Q101H.reg_write_en = 1'b1;
            end

            // =================================================================
            // SYSTEM Instructions (ECALL, EBREAK)
            // =================================================================
            SYSTEM: begin
                // For now, treat ECALL/EBREAK as NOPs
                // In a full implementation, these would trigger exceptions
                // Could add $finish for simulation
            end

            // =================================================================
            // MISC_MEM (FENCE) - treat as NOP
            // =================================================================
            MISC_MEM: begin
                // FENCE instruction - no-op in simple implementation
            end

            default: begin
                // Unknown opcode - NOP
            end
        endcase
    end

    // ---------------------------------------------------------------------
    // Effective control after flush (insert bubbles)
    // ---------------------------------------------------------------------
    always_comb begin
        if (flush_Q101H) begin
            ctrl_Q101H_eff = '0;  // Insert bubble (NOP)
        end else begin
            ctrl_Q101H_eff = ctrl_Q101H;
        end
    end

    always_comb begin
        if (flush_Q102H) begin
            ctrl_Q102H_eff = '0;  // Insert bubble (NOP)
        end else if (load_use_hazard) begin
            ctrl_Q102H_eff = '0;  // Insert bubble for stall
        end else begin
            ctrl_Q102H_eff = ctrl_Q102H;
        end
    end

    // ---------------------------------------------------------------------
    // Pipeline Control Signals
    // ---------------------------------------------------------------------
    assign if_ctrl.ready_Q100H = !stall_Q100H;
    assign if_ctrl.ready_Q101H = !stall_Q101H;
    assign if_ctrl.sel_next_pc_alu_out_Q102H = branch_taken_Q102H;

    assign decode_ctrl.ready_Q101H = !stall_Q101H;
    assign decode_ctrl.ready_Q102H = 1'b1;
    assign decode_ctrl.valid_Q101H = !flush_Q101H && !stall_Q101H;

    // ---------------------------------------------------------------------
    // Pipe control registers (with stall support)
    // ---------------------------------------------------------------------
    // Q101H -> Q102H: stall holds value, otherwise update
    always_ff @(posedge clk) begin
        if (rst)
            ctrl_Q102H <= '0;
        else if (!load_use_hazard)
            ctrl_Q102H <= ctrl_Q101H_eff;
        // else: stall - keep current value
    end
    
    // Q102H -> Q103H: always update (with effective value for flush)
    always_ff @(posedge clk) begin
        if (rst)
            ctrl_Q103H <= '0;
        else
            ctrl_Q103H <= ctrl_Q102H_eff;
    end
    
    // Q103H -> Q104H: always update
    `DFF_RST(ctrl_Q104H, ctrl_Q103H, clk, rst)

    // ---------------------------------------------------------------------
    // Decode-stage outward control (to rv_decode / regfile)
    // ---------------------------------------------------------------------
    assign decode_ctrl.reg_src1_Q101H        = ctrl_Q101H.rs1;
    assign decode_ctrl.reg_src2_Q101H        = ctrl_Q101H.rs2;
    assign decode_ctrl.rd_Q101H              = ctrl_Q101H.rd;
    assign decode_ctrl.uses_reg_src1_Q101H   = ctrl_Q101H.uses_rs1;
    assign decode_ctrl.uses_reg_src2_Q101H   = ctrl_Q101H.uses_rs2;
    assign decode_ctrl.sel_imm_type_Q101H    = ctrl_Q101H.imm_sel;

    // ---------------------------------------------------------------------
    // EXE stage control outputs (Q102H view)
    // ---------------------------------------------------------------------
    assign exe_ctrl.ready_Q102H        = 1'b1;
    assign exe_ctrl.rs1_Q102H          = ctrl_Q102H.rs1;
    assign exe_ctrl.rs2_Q102H          = ctrl_Q102H.rs2;
    assign exe_ctrl.rd_Q103H           = ctrl_Q103H.rd;
    assign exe_ctrl.rd_Q104H           = ctrl_Q104H.rd;
    assign exe_ctrl.reg_write_en_Q103H = ctrl_Q103H.reg_write_en && !ctrl_Q103H.is_load;
    assign exe_ctrl.reg_write_en_Q104H = ctrl_Q104H.reg_write_en;
    assign exe_ctrl.sel_alu_in1_Q102H  = ctrl_Q102H.sel_alu_in1;
    assign exe_ctrl.sel_alu_in2_Q102H  = ctrl_Q102H.sel_alu_in2;
    assign exe_ctrl.alu_op             = ctrl_Q102H.alu_op;
    assign exe_ctrl.branch_cond_op     = ctrl_Q102H.branch_cond_op;
    assign exe_ctrl.is_load_Q103H      = ctrl_Q103H.is_load;

    // ---------------------------------------------------------------------
    // MA stage control outputs (Q103H view)
    // ---------------------------------------------------------------------
    assign ma_ctrl.ready_Q103H         = 1'b1;
    assign ma_ctrl.sel_wb_Q103H        = ctrl_Q103H.mem_wb_sel;
    assign ma_ctrl.dmem_wr_en_Q103H    = ctrl_Q103H.dmem_wr_en;
    assign ma_ctrl.dmem_rd_en_Q103H    = ctrl_Q103H.dmem_rd_en;
    assign ma_ctrl.dmem_byte_en_Q103H  = ctrl_Q103H.dmem_byte_en;
    assign ma_ctrl.dmem_sign_ext_Q103H = ctrl_Q103H.dmem_sign_ext;

    // ---------------------------------------------------------------------
    // WB stage control outputs (Q104H view)
    // ---------------------------------------------------------------------
    assign wb_ctrl.ready_Q104H         = 1'b1;
    assign wb_ctrl.sel_wb_Q104H        = ctrl_Q104H.wb_sel;
    assign wb_ctrl.reg_write_en_Q104H  = ctrl_Q104H.reg_write_en;
    assign wb_ctrl.reg_dst_Q104H       = ctrl_Q104H.rd;

endmodule
