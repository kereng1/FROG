`include "dff_macros.svh"

module rv_exe
    import pkg::*;
(
    input logic clk,
    input logic rst,
    input t_exe_ctrl    ctrl,
    input logic [31:0] pc_Q102H,
    input logic [31:0] reg_data1_Q102H,
    input logic [31:0] reg_data2_Q102H,
    input logic [31:0] imm_Q102H,
    input logic [31:0] wb_data_Q103H,
    input logic [31:0] wb_data_Q104H,

    output logic branch_cond_met_Q102H,
    output logic [31:0] pc_plus4_Q103H,
    output logic [31:0] alu_out_Q103H,
    output logic [31:0] dmem_wr_data_Q103H
);

logic [31:0] pc_plus4_Q102H;
logic [31:0] alu_out_Q102H;
logic [31:0] post_reg_data1_Q102H;
logic [31:0] post_reg_data2_Q102H;
logic [31:0] alu_in1_Q102H;
logic [31:0] alu_in2_Q102H;
logic hazard_reg1_Q102H_Q103H;
logic hazard_reg1_Q102H_Q104H;
logic hazard_reg2_Q102H_Q103H;
logic hazard_reg2_Q102H_Q104H;

// hazard detection for the forwarding unit
assign hazard_reg1_Q102H_Q103H = (ctrl.rs1_Q102H == ctrl.rd_Q103H) && ctrl.reg_write_en_Q103H;
assign hazard_reg1_Q102H_Q104H = (ctrl.rs1_Q102H == ctrl.rd_Q104H) && ctrl.reg_write_en_Q104H;
assign hazard_reg2_Q102H_Q103H = (ctrl.rs2_Q102H == ctrl.rd_Q103H) && ctrl.reg_write_en_Q103H;
assign hazard_reg2_Q102H_Q104H = (ctrl.rs2_Q102H == ctrl.rd_Q104H) && ctrl.reg_write_en_Q104H;


// mux for the forwarding unit in-case of DATA HAZARD
assign post_reg_data1_Q102H = (hazard_reg1_Q102H_Q103H) ? wb_data_Q103H :
                              (hazard_reg1_Q102H_Q104H) ? wb_data_Q104H :
                                                                     reg_data1_Q102H;

assign post_reg_data2_Q102H = (hazard_reg2_Q102H_Q103H) ? wb_data_Q103H :
                              (hazard_reg2_Q102H_Q104H) ? wb_data_Q104H :
                                                                     reg_data2_Q102H;

// mux for the ALU inputs
assign alu_in1_Q102H  = (ctrl.sel_alu_in1_Q102H == SEL_PC)       ? pc_Q102H:
                        (ctrl.sel_alu_in1_Q102H == SEL_REG_DATA1) ? post_reg_data1_Q102H :
                                                                   32'b0;

assign alu_in2_Q102H  = (ctrl.sel_alu_in2_Q102H == SEL_REG_DATA2) ? post_reg_data2_Q102H :
                        (ctrl.sel_alu_in2_Q102H == SEL_IMM)      ? imm_Q102H:
                                                                   32'b0;

assign pc_plus4_Q102H = pc_Q102H + 32'd4;

always_comb begin
    case (ctrl.alu_op)
        ALU_ADD: alu_out_Q102H = alu_in1_Q102H + alu_in2_Q102H;
        ALU_SUB: alu_out_Q102H = alu_in1_Q102H - alu_in2_Q102H;
        ALU_SLT: alu_out_Q102H = (alu_in1_Q102H < alu_in2_Q102H) ;
        ALU_SLTU: alu_out_Q102H = (alu_in1_Q102H < alu_in2_Q102H);
        ALU_SLL: alu_out_Q102H = alu_in1_Q102H << alu_in2_Q102H[4:0];
        ALU_SRL: alu_out_Q102H = alu_in1_Q102H >> alu_in2_Q102H[4:0];
        ALU_SRA: alu_out_Q102H = $signed(alu_in1_Q102H) >>> alu_in2_Q102H[4:0];
        ALU_XOR: alu_out_Q102H = alu_in1_Q102H ^ alu_in2_Q102H;
        ALU_OR: alu_out_Q102H = alu_in1_Q102H | alu_in2_Q102H;
        ALU_AND: alu_out_Q102H = alu_in1_Q102H & alu_in2_Q102H;
        default: alu_out_Q102H = 32'b0;   
    endcase
end

// branch condition
always_comb begin
    case (ctrl.branch_cond_op)
        BRANCH_COND_BEQ: branch_cond_met_Q102H = (post_reg_data1_Q102H == post_reg_data2_Q102H);
        BRANCH_COND_BNE: branch_cond_met_Q102H = (post_reg_data1_Q102H != post_reg_data2_Q102H);
        BRANCH_COND_BLT: branch_cond_met_Q102H = ($signed(post_reg_data1_Q102H) < $signed(post_reg_data2_Q102H));
        BRANCH_COND_BGE: branch_cond_met_Q102H = ($signed(post_reg_data1_Q102H) >= $signed(post_reg_data2_Q102H));
        BRANCH_COND_BLTU: branch_cond_met_Q102H = (post_reg_data1_Q102H < post_reg_data2_Q102H);
        BRANCH_COND_BGEU: branch_cond_met_Q102H = (post_reg_data1_Q102H >= post_reg_data2_Q102H);
        default:          branch_cond_met_Q102H = 1'b0; // no branch
    endcase
end

`DFF_EN(pc_plus4_Q103H, pc_plus4_Q102H, clk, rst)
`DFF_EN(alu_out_Q103H, alu_out_Q102H, clk, rst)
`DFF_EN(dmem_wr_data_Q103H, post_reg_data2_Q102H, clk, rst)

endmodule
