//----------------------------------------------------------
// Title      : rv_decode 
// Project    : RISC-V 5-Stage Pipeline
// Stage      : Decode (Q101H)
//----------------------------------------------------------
// Description:
// 1. Manages the Register File (RF) access.
// 2. Handles internal forwarding (Write-to-Read in the same cycle).
// 3. Generates immediate values based on instruction type.
// 4. Passes immediate and PC values to the next stage (Execute).
//----------------------------------------------------------

`include "dff_macros.svh"

module rv_decode 
import pkg::*;
#(parameter RF_NUM_MSB = 31) // Standard RISC-V has 32 regs (x0 is hardwired zero)
(
    input  logic        clk,
    input  logic        rst,
    
    // Control interface from Control Unit
    input  t_decode_ctrl   ctrl,         // Contains rs1, rs2, rd, imm_type, and ready signals
    
    input  logic [31:0] pc_Q101H,         // PC from IF stage
    input  logic [31:0] instruction_Q101H, // Instruction from i_mem
    output logic [31:0] pc_Q102H,
    output logic [31:0] imm_Q102H,
    output logic [31:0] reg_data1_Q102H,
    output logic [31:0] reg_data2_Q102H,
    
    // Data inputs from write back stage
    input  logic [31:0] wb_data_Q104H,
    input  logic [4:0]  reg_dst_Q104H,
    input  logic        reg_write_en_Q104H
);

//----------------------------------------------------------
// Register File Definition
// RISC-V defines 32 registers (x0-x31). x0 is hardwired to 0.
//----------------------------------------------------------
logic [RF_NUM_MSB:1][31:0] rf;

// Internal signals for combinatorial read logic and internal forwarding (Hazard detection)
logic [31:0] reg_rd_data1_Q101H; // Data read from register 1
logic [31:0] reg_rd_data2_Q101H; // Data read from register 2
logic        match_rs1_aftr_wb_Q101H; // Hazard detection for rs1
logic        match_rs2_aftr_wb_Q101H; // Hazard detection for rs2

logic [31:0] imm_Q101H; // Internal signal for the calculated immediate

//==========================================================
// 1. Immediate Generator (Sign Extension)
//==========================================================
always_comb begin
    case (ctrl.sel_imm_type_Q101H)
        IMM_I_TYPE: imm_Q101H = {{20{instruction_Q101H[31]}}, instruction_Q101H[31:20]};
        IMM_S_TYPE: imm_Q101H = {{20{instruction_Q101H[31]}}, instruction_Q101H[31:25], instruction_Q101H[11:7]};
        IMM_B_TYPE: imm_Q101H = {{19{instruction_Q101H[31]}}, instruction_Q101H[31], instruction_Q101H[7], instruction_Q101H[30:25], instruction_Q101H[11:8], 1'b0};
        IMM_U_TYPE: imm_Q101H = {instruction_Q101H[31:12], 12'b0};
        IMM_J_TYPE: imm_Q101H = {{11{instruction_Q101H[31]}}, instruction_Q101H[31], instruction_Q101H[19:12], instruction_Q101H[20], instruction_Q101H[30:21], 1'b0};
        default:    imm_Q101H = 32'b0;
    endcase
end

//==========================================================
// 2. Register File Write
//==========================================================
`DFF_EN(rf[reg_dst_Q104H], wb_data_Q104H, clk, (reg_write_en_Q104H && (reg_dst_Q104H != 5'b0)))

//==========================================================
// 3. Register File Read & Forwarding
//    Handles rd after write when WB writes to a register that decode reads in the same cycle
//==========================================================
assign match_rs1_aftr_wb_Q101H = (ctrl.reg_src1_Q101H == reg_dst_Q104H) && reg_write_en_Q104H && (reg_dst_Q104H != 5'b0);
assign reg_rd_data1_Q101H = (ctrl.reg_src1_Q101H == 5'b0)  ? 32'b0 :                   // x0 is hardwired to 0
                            (match_rs1_aftr_wb_Q101H)      ? wb_data_Q104H :           // forwards WrDataQ104H -> RdDataQ101H
                                                             rf[ctrl.reg_src1_Q101H];  // reads from register file

assign match_rs2_aftr_wb_Q101H = (ctrl.reg_src2_Q101H == reg_dst_Q104H) && reg_write_en_Q104H && (reg_dst_Q104H != 5'b0);
assign reg_rd_data2_Q101H = (ctrl.reg_src2_Q101H == 5'b0)  ? 32'b0 :                   // x0 is hardwired to 0
                            (match_rs2_aftr_wb_Q101H)      ? wb_data_Q104H :           // forwards WrDataQ104H -> RdDataQ101H
                                                             rf[ctrl.reg_src2_Q101H];

//==========================================================
// 4. Pipeline Transition to EXE stage (Q102H)
//==========================================================
`DFF_EN(pc_Q102H,        pc_Q101H,           clk, ctrl.ready_Q102H)
`DFF_EN(imm_Q102H,       imm_Q101H,          clk, ctrl.ready_Q102H)
`DFF_EN(reg_data1_Q102H, reg_rd_data1_Q101H, clk, ctrl.ready_Q102H)
`DFF_EN(reg_data2_Q102H, reg_rd_data2_Q101H, clk, ctrl.ready_Q102H)

endmodule
