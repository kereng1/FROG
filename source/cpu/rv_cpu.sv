//----------------------------------------------------------
// Title      : rv_cpu
// Project    : RISC-V 5-Stage Pipeline
//----------------------------------------------------------
// Description:
// Top-level CPU module integrating all 5 pipeline stages:
//   Q100H - Instruction Fetch (rv_if)
//   Q101H - Decode + Register File (rv_decode, rv_ctrl)
//   Q102H - Execute (rv_exe)
//   Q103H - Memory Access (rv_ma)
//   Q104H - Write Back (rv_wb)
//----------------------------------------------------------

`include "dff_macros.svh"

module rv_cpu
    import pkg::*;
(
    input  logic        clk,
    input  logic        rst,
    
    // Instruction Memory Interface
    output logic [31:0] imem_addr,          // PC to instruction memory
    input  logic [31:0] imem_rd_data,       // Instruction from memory
    
    // Data Memory Interface
    output t_core2mem_req core2dmem_req,    // Core request to data memory
    input  logic [31:0]   dmem_rd_data      // Read data from data memory
);

//----------------------------------------------------------
// Internal Signals
//----------------------------------------------------------

// Control signals for each stage
t_if_ctrl     if_ctrl;
t_decode_ctrl decode_ctrl;
t_exe_ctrl    exe_ctrl;
t_ma_ctrl     ma_ctrl;
t_wb_ctrl     wb_ctrl;

// IF stage signals
logic [31:0] pc_Q100H;
logic [31:0] pc_Q101H;

// Decode stage signals  
logic [31:0] pc_Q102H;
logic [31:0] imm_Q102H;
logic [31:0] reg_data1_Q102H;
logic [31:0] reg_data2_Q102H;

// EXE stage signals
logic        branch_cond_met_Q102H;
logic [31:0] pc_plus4_Q103H;
logic [31:0] alu_out_Q102H;
logic [31:0] alu_out_Q103H;
logic [31:0] dmem_wr_data_Q103H;

// MA stage signals
logic [31:0] pre_wb_data_Q104H;

// WB stage signals
logic [31:0] wb_data_Q104H;

// Pipeline signal for dmem read data (Q104H)
logic [31:0] dmem_rd_data_Q104H;

//----------------------------------------------------------
// Instruction Memory Interface
//----------------------------------------------------------
assign imem_addr = pc_Q100H;

// Instruction available at Q101H (1 cycle after PC is sent)
logic [31:0] instruction_Q101H;
assign instruction_Q101H = imem_rd_data;

//----------------------------------------------------------
// Data Memory Read Pipeline Register (Q103H -> Q104H)
//----------------------------------------------------------
`DFF_EN(dmem_rd_data_Q104H, dmem_rd_data, clk, ma_ctrl.ready_Q103H)

//----------------------------------------------------------
// Module Instantiations
//----------------------------------------------------------

// Control Unit - generates all control signals
rv_ctrl u_rv_ctrl (
    .clk                    (clk),
    .rst                    (rst),
    .instruction_Q101H      (instruction_Q101H),
    .branch_cond_met_Q102H  (branch_cond_met_Q102H),
    .if_ctrl                (if_ctrl),
    .decode_ctrl            (decode_ctrl),
    .exe_ctrl               (exe_ctrl),
    .ma_ctrl                (ma_ctrl),
    .wb_ctrl                (wb_ctrl)
);

// Instruction Fetch Stage (Q100H/Q101H)
rv_if u_rv_if (
    .clk            (clk),
    .rst            (rst),
    .alu_out_Q102H  (alu_out_Q102H),
    .ctrl           (if_ctrl),
    .pc_Q100H       (pc_Q100H),
    .pc_Q101H       (pc_Q101H)
);

// Decode Stage with Register File (Q101H)
rv_decode u_rv_decode (
    .clk                (clk),
    .rst                (rst),
    .ctrl               (decode_ctrl),
    .pc_Q101H           (pc_Q101H),
    .instruction_Q101H  (instruction_Q101H),
    .pc_Q102H           (pc_Q102H),
    .imm_Q102H          (imm_Q102H),
    .reg_data1_Q102H    (reg_data1_Q102H),
    .reg_data2_Q102H    (reg_data2_Q102H),
    .wb_data_Q104H      (wb_data_Q104H),
    .reg_dst_Q104H      (wb_ctrl.reg_dst_Q104H),
    .reg_write_en_Q104H (wb_ctrl.reg_write_en_Q104H)
);

// Execute Stage (Q102H)
rv_exe u_rv_exe (
    .clk                    (clk),
    .rst                    (rst),
    .ctrl                   (exe_ctrl),
    .pc_Q102H               (pc_Q102H),
    .reg_data1_Q102H        (reg_data1_Q102H),
    .reg_data2_Q102H        (reg_data2_Q102H),
    .imm_Q102H              (imm_Q102H),
    .wb_data_Q103H          (alu_out_Q103H),     // Forwarding from MA stage
    .wb_data_Q104H          (wb_data_Q104H),     // Forwarding from WB stage
    .branch_cond_met_Q102H  (branch_cond_met_Q102H),
    .pc_plus4_Q103H         (pc_plus4_Q103H),
    .alu_out_Q103H          (alu_out_Q103H),
    .dmem_wr_data_Q103H     (dmem_wr_data_Q103H)
);

// Tap ALU output before pipeline register for branch target
assign alu_out_Q102H = u_rv_exe.alu_out_Q102H;

// Memory Access Stage (Q103H)
rv_ma u_rv_ma (
    .clk                (clk),
    .rst                (rst),
    .ctrl               (ma_ctrl),
    .pc_plus4_Q103H     (pc_plus4_Q103H),
    .alu_out_Q103H      (alu_out_Q103H),
    .dmem_wr_data_Q103H (dmem_wr_data_Q103H),
    .core2dmem_req_Q103H(core2dmem_req),
    .pre_wb_data_Q104H  (pre_wb_data_Q104H)
);

// Write Back Stage (Q104H)
rv_wb u_rv_wb (
    .clk                (clk),
    .rst                (rst),
    .ctrl               (wb_ctrl),
    .pre_wb_data_Q104H  (pre_wb_data_Q104H),
    .dmem_rd_data_Q104H (dmem_rd_data_Q104H),
    .wb_data_Q104H      (wb_data_Q104H)
);

endmodule

