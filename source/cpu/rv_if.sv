// Instruction fetch (Q100H stage)
//----------------------------------------------------------
// 1. Send the PC (program counter) to the I_MEM
// 2. Calculate the next PC (program counter)
//----------------------------------------------------------

`include "dff_macros.svh"

module rv_if
    import pkg::*;
(
    input logic clk,
    input logic rst,
    input logic sel_next_pc_alu_out_Q102H,  // input  var t_ctrl_if    Ctrl,
    input logic [31:0] alu_out_Q102H,
    input  logic        ready_Q100H,
    input  logic        ready_Q101H,
    output logic [31:0] pc_Q100H,
    output logic [31:0] pc_Q101H
);

logic [31:0] pc_plus4_Q100H;
logic [31:0] next_pc_Q100H;

// Compute pc_plus4 = pc_out + 4 (instruction indexing)
assign pc_plus4_Q100H = pc_Q100H + 32'd4;

// Mux to choose between pc_plus4 and alu_out
assign next_pc_Q100H  = sel_next_pc_alu_out_Q102H ? alu_out_Q102H : pc_plus4_Q100H;

`DFF_EN(pc_Q100H, next_pc_Q100H, clk, ready_Q100H)
`DFF_EN(pc_Q101H, pc_Q100H, clk, ready_Q101H)

endmodule


