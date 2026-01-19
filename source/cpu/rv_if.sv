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
    input logic [31:0] alu_out_Q102H,
    input t_if_ctrl ctrl,
    output logic [31:0] pc_Q100H,
    output logic [31:0] pc_Q101H
);

logic [31:0] pc_plus4_Q100H;
logic [31:0] next_pc_Q100H;

// Compute pc_plus4 = pc_out + 4 (instruction indexing)
assign pc_plus4_Q100H = pc_Q100H + 32'd4;

// Mux to choose between pc_plus4 and alu_out
assign next_pc_Q100H  = ctrl.sel_next_pc_alu_out_Q102H ? alu_out_Q102H : pc_plus4_Q100H;

`DFF_RST_EN(pc_Q100H, next_pc_Q100H, clk, ctrl.ready_Q100H, rst, 32'h0)
`DFF_RST_EN(pc_Q101H, pc_Q100H, clk, ctrl.ready_Q101H, rst, 32'h0)

endmodule


