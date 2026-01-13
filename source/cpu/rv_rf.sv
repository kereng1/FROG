//----------------------------------------------------------
// Title      : rv_rf 
// Project    : RISC-V 5-Stage Pipeline
// Stage      : Decode (Q101H)
//----------------------------------------------------------
// Description:
// 1. Manages the Register File (RF) access.
// 2. Handles internal forwarding (Write-to-Read in the same cycle).
// 3. Passes immediate and PC values to the next stage (Execute).
//----------------------------------------------------------

`include "dff_macros.svh"
import pkg::*;
module rv_rf 
#(parameter RF_NUM_MSB = 31) // Standard RISC-V has 32 regs (x0 is hardwired zero)
(
    input  logic        clk,
    input  logic        rst,
    
    // Control interface from Control Unit
    input  t_dec_ctrl   ctrl,         // Contains rs1, rs2, rd, and write_en signals
    input  logic        ready_Q102H,  // Pipeline enable for next stage registers
    
    // Data inputs
    input  logic [31:0] pc_Q101H,     // PC from IF stage
    input  logic [31:0] instruction_Q101H,    // Instruction from i_mem


    // Data outputs to EXE stage
    output logic [31:0] pc_Q102H,
    output logic [31:0] imm_Q102H,
    output logic [31:0] reg_data1_Q102H,
    output logic [31:0] reg_data2_Q102H,
    
    // Data inputs from write back stage
    input  logic [31:0] wb_data_Q104H,
    input  logic [4:0]  rd_Q104H,
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
    case (ctrl.imm_type)
        IMM_I:   imm_Q101H = {{20{instruction_Q101H[31]}}, instruction_Q101H[31:20]};
        IMM_S:   imm_Q101H = {{20{instruction_Q101H[31]}}, instruction_Q101H[31:25], instruction_Q101H[11:7]};
        IMM_B:   imm_Q101H = {{19{instruction_Q101H[31]}}, instruction_Q101H[31], instruction_Q101H[7], instruction_Q101H[30:25], instruction_Q101H[11:8], 1'b0};
        IMM_U:   imm_Q101H = {instruction_Q101H[31:12], 12'b0};
        IMM_J:   imm_Q101H = {{11{instruction_Q101H[31]}}, instruction_Q101H[31], instruction_Q101H[19:12], instruction_Q101H[20], instruction_Q101H[30:21], 1'b0};
        default: imm_Q101H = 32'b0;
    endcase
end

//==========================================================
// 2. Register File Write (Matches MAFIA_EN_DFF in reference)
//==========================================================
`DFF_EN(rf[rd_Q104H], wb_data_Q104H, clk, (reg_write_en_Q104H && (rd_Q104H != 5'b0)))

//==========================================================
// 3. Register File Read & Forwarding (Exact logic from reference)
//==========================================================
assign match_rs1_aftr_wb_Q101H = (ctrl.rs1_Q101H == rd_Q104H) && (reg_write_en_Q104H);
assign reg_rd_data1_Q101H = (ctrl.rs1_Q101H == 5'b0)       ? 32'b0 :
                            (match_rs1_aftr_wb_Q101H)     ? wb_data_Q104H : 
                                                            rf[ctrl.rs1_Q101H];

assign match_rs2_aftr_wb_Q101H = (ctrl.rs2_Q101H == rd_Q104H) && (reg_write_en_Q104H);
assign reg_rd_data2_Q101H = (ctrl.rs2_Q101H == 5'b0)       ? 32'b0 :
                            (match_rs2_aftr_wb_Q101H)     ? wb_data_Q104H : 
                                                            rf[ctrl.rs2_Q101H];

//==========================================================
// 4. Pipeline Transition (Matches the 4 DFFs at end of reference)
//==========================================================
`DFF_EN(pc_Q102H,        pc_Q101H,           clk, ready_Q102H)
`DFF_EN(imm_Q102H,       imm_Q101H,          clk, ready_Q102H)
`DFF_EN(reg_data1_Q102H, reg_rd_data1_Q101H, clk, ready_Q102H)
`DFF_EN(reg_data2_Q102H, reg_rd_data2_Q101H, clk, ready_Q102H)

endmodule