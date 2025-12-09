// Memory Access stage of the pipeline (Q103H stage)
//----------------------------------------------------------
// Access D_MEM for Writes (STORE) and Reads (LOAD) 
//----------------------------------------------------------    

`include "dff_macros.svh"

module rv_ma
    import pkg::*;
(
    input logic clk,
    input logic rst,
    input t_ma_ctrl ctrl,
    input logic [31:0] pc_plus4_Q103H,
    input logic [31:0] alu_out_Q103H,

    input  logic [31:0]    dmem_wr_data_Q103H,
    output t_core2mem_req  core2dmem_req_Q103H, 

    output logic [31:0] pre_wb_data_Q104H
);

logic [31:0] wb_data_Q103H;

// Output core2mem_request signal
assign core2dmem_req_Q103H.wr_data  = dmem_wr_data_Q103H;
assign core2dmem_req_Q103H.address  = alu_out_Q103H;
assign core2dmem_req_Q103H.wr_en    = ctrl.dmem_wr_en_Q103H;
assign core2dmem_req_Q103H.rd_en    = ctrl.dmem_rd_en_Q103H;
assign core2dmem_req_Q103H.byte_en  = ctrl.dmem_byte_en_Q103H;

// mux for the write back data 
assign wb_data_Q103H = (ctrl.sel_wb_Q103H == SEL_PC_PLUS4) ? pc_plus4_Q103H : 
                       (ctrl.sel_wb_Q103H == SEL_ALU_OUT)  ? alu_out_Q103H :
                                                             32'b0;

`DFF_EN(pre_wb_data_Q104H, wb_data_Q103H, clk, ctrl.ready_Q103H)

endmodule