// Memory Access stage of the pipeline
// Access D_MEM for Wrote (STORE) and Reads (LOAD)

include "dff_macros.svh"

module rv_mem
    import pkg::*;
(
    input logic clk,
    input logic rst,
    input t_mem_ctrl ctrl,
    input logic [31:0] pc_plus4_Q103H,
    input logic [31:0] alu_out_Q103H,

    output logic [31:0] pre_wb_data_Q104H
);

logic [31:0] wb_data_Q103H;

// mux for the write back data 
assign wb_data_Q103H = (ctrl.sel_wb_Q103H == SEL_PC_PLUS4) ? pc_plus4_Q103H :
                       (ctrl.sel_wb_Q103H == SEL_ALU_OUT)  ? alu_out_Q103H :
                                                             32'b0;

`DFF_EN(pre_wb_data_Q104H, wb_data_Q103H, clk, rst)

endmodule