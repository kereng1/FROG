`include "dff_macros.svh"

module rv_wb
    import pkg::*;
(
    input logic clk,
    input logic rst,
    input t_wb_ctrl ctrl,
    input logic [31:0] pre_wb_data_Q104H,
    input logic [31:0] dmem_rd_data_Q104H,
    output logic [31:0] wb_data_Q104H
);

assign wb_data_Q104H = (ctrl.sel_wb_Q104H == SEL_WR_DATA)      ? pre_wb_data_Q104H :
                       (ctrl.sel_wb_Q104H == SEL_DMEM_RD_DATA) ? dmem_rd_data_Q104H :
                                                                 32'b0;

endmodule   