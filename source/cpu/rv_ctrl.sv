`include "dff_macros.svh"

module rv_ctrl
    import rv_pkg::*;
(
    input  logic         clk,
    input  logic         rst,
    input  logic [31:0]  instruction_Q101H,
    input  logic         branch_cond_met_Q102H, // unused in simplified stage
    output t_if_ctrl     if_ctrl,
    output t_decode_ctrl decode_ctrl,
    output t_exe_ctrl    exe_ctrl,
    output t_ma_ctrl     ma_ctrl,
    output t_wb_ctrl     wb_ctrl
);

    t_ctrl ctrl_Q101H, ctrl_Q102H, ctrl_Q103H, ctrl_Q104H;

    logic [2:0]  func3Q101H;
    logic [6:0]  func7Q101H;
    t_opcode     opcodeQ101H;

    assign func3Q101H = instruction_Q101H[14:12];
    assign func7Q101H = instruction_Q101H[31:25];
    assign opcodeQ101H = t_opcode'(instruction_Q101H[6:0]);

    // ---------------------------------------------------------------------
    // Combinational decode: only ADD/SUB, ADDI, LW, SW (BEQ optional later)
    // ---------------------------------------------------------------------
    always_comb begin
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
        ctrl_Q101H.dmem_byte_en  = 4'b1111; // word access only
        ctrl_Q101H.dmem_wr_en    = 1'b0;
        ctrl_Q101H.dmem_rd_en    = 1'b0;
        ctrl_Q101H.reg_write_en  = 1'b0;
        ctrl_Q101H.is_load       = 1'b0;
        ctrl_Q101H.uses_rs1      = 1'b0;
        ctrl_Q101H.uses_rs2      = 1'b0;

        unique case (opcodeQ101H)
            R_OP: begin
                ctrl_Q101H.sel_alu_in1 = SEL_REG_DATA1;
                ctrl_Q101H.sel_alu_in2 = SEL_REG_DATA2;
                ctrl_Q101H.reg_write_en = 1'b1;
                ctrl_Q101H.uses_rs1 = 1'b1;
                ctrl_Q101H.uses_rs2 = 1'b1;
                unique case ({func7Q101H, func3Q101H})
                    {7'b0000000, 3'b000}: ctrl_Q101H.alu_op = ALU_ADD; // ADD
                    {7'b0100000, 3'b000}: ctrl_Q101H.alu_op = ALU_SUB; // SUB
                    default:              ctrl_Q101H.alu_op = ALU_ADD;
                endcase
            end
            I_OP: begin
                ctrl_Q101H.sel_alu_in1 = SEL_REG_DATA1;
                ctrl_Q101H.sel_alu_in2 = SEL_IMM;
                ctrl_Q101H.imm_sel     = IMM_I_TYPE;
                ctrl_Q101H.reg_write_en= 1'b1;
                ctrl_Q101H.uses_rs1    = 1'b1;
                ctrl_Q101H.uses_rs2    = 1'b0;
                unique case (func3Q101H)
                    3'b000: ctrl_Q101H.alu_op = ALU_ADD; // ADDI
                    default: ctrl_Q101H.reg_write_en = 1'b0; // unsupported -> NOP
                endcase
            end
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
                    ctrl_Q101H.dmem_sign_ext = (func3Q101H[2:1] == 2'b00) ;
                unique case (func3Q101H)
                    3'b010: ctrl_Q101H.dmem_byte_en  = 4'b1111; // LW
                    3'b000: ctrl_Q101H.dmem_byte_en  = 4'b0001; // LB
                    3'b001: ctrl_Q101H.dmem_byte_en  = 4'b0011; // LH
                    3'b100: ctrl_Q101H.dmem_byte_en  = 4'b0001; // LBU
                    3'b101: ctrl_Q101H.dmem_byte_en  = 4'b0011; // LHU
                    default: ctrl_Q101H.dmem_byte_en = 4'bxxxx; // unsupported -> NOP
                endcase
            end
            STORE: begin
                    ctrl_Q101H.sel_alu_in1  = SEL_REG_DATA1;
                    ctrl_Q101H.sel_alu_in2  = SEL_IMM;
                    ctrl_Q101H.imm_sel      = IMM_S_TYPE;
                    ctrl_Q101H.alu_op       = ALU_ADD;
                    ctrl_Q101H.dmem_wr_en   = 1'b1;
                    ctrl_Q101H.uses_rs1     = 1'b1;
                    ctrl_Q101H.uses_rs2     = 1'b1;
                unique case (func3Q101H)
                    3'b010: ctrl_Q101H.dmem_byte_en  = 4'b1111; // SW
                    3'b000: ctrl_Q101H.dmem_byte_en  = 4'b0001; // SB
                    3'b001: ctrl_Q101H.dmem_byte_en  = 4'b0011; // SH
                    default: ctrl_Q101H.dmem_byte_en = 4'bxxxx; // unsupported
                endcase
            end
            default: begin
                // Everything else stays as safe NOP defaults
            end
        endcase
    end

    // ---------------------------------------------------------------------
    // Ready/PC control: fixed enables, no flush/backpressure in this version
    // ---------------------------------------------------------------------
    assign if_ctrl.ready_Q100H             = 1'b1;
    assign if_ctrl.ready_Q101H             = 1'b1;
    assign if_ctrl.sel_next_pc_alu_out_Q102H = 1'b0; // no branch/jump steering yet

    assign decode_ctrl.ready_Q101H         = 1'b1;
    assign decode_ctrl.ready_Q102H         = 1'b1;
    assign decode_ctrl.valid_Q101H         = 1'b1; // Always valid in simplified version

    // ---------------------------------------------------------------------
    // Pipe control registers
    // ---------------------------------------------------------------------
    `DFF_RST(ctrl_Q102H, ctrl_Q101H, clk, rst)
    `DFF_RST(ctrl_Q103H, ctrl_Q102H, clk, rst)
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
    assign exe_ctrl.branch_cond_op     = ctrl_Q102H.branch_cond_op; // stays NONE

    // ---------------------------------------------------------------------
    // MA stage control outputs (Q103H view)
    // ---------------------------------------------------------------------
    assign ma_ctrl.ready_Q103H         = 1'b1;
    assign ma_ctrl.sel_wb_Q103H        = ctrl_Q103H.mem_wb_sel;
    assign ma_ctrl.dmem_wr_en_Q103H    = ctrl_Q103H.dmem_wr_en;
    assign ma_ctrl.dmem_rd_en_Q103H    = ctrl_Q103H.dmem_rd_en;
    assign ma_ctrl.dmem_byte_en_Q103H  = ctrl_Q103H.dmem_byte_en;

    // ---------------------------------------------------------------------
    // WB stage control outputs (Q104H view)
    // ---------------------------------------------------------------------
    assign wb_ctrl.ready_Q104H         = 1'b1;
    assign wb_ctrl.sel_wb_Q104H        = ctrl_Q104H.wb_sel;
    assign wb_ctrl.reg_write_en_Q104H  = ctrl_Q104H.reg_write_en;
    assign wb_ctrl.reg_dst_Q104H       = ctrl_Q104H.rd;

endmodule
