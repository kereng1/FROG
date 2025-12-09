



module rv_ctrl
    import pkg::*;
(
    input  logic         clk,
    input  logic         rst,
    input  logic [31:0]  instruction_Q101H,
    input  logic         branch_cond_met_Q102H
    output t_if_ctrl     if_ctrl,
    output t_decode_ctrl decode_ctrl,
    output t_exe_ctrl    exe_ctrl,
    output t_mem_ctrl    mem_ctrl,
    output t_wb_ctrl     wb_ctrl,
);






endmodule