//------------------------------------------------------------------------------
// trk_rtl_commit - RTL commit tracker (valid instructions only, no HW bubbles)
// Logs only when ctrl_Q104H.valid (committed). NOP from instruction is valid;
// NOP from flush/stall bubble is not. Format matches trk_ref_commit for diff.
// pc/instr pipelined from Q101H/Q102H to Q104H in TB.
//------------------------------------------------------------------------------

initial begin
    log_rtl_commit = $fopen("target/rv_cpu/logs/trk/rtl_commit.log", "w");
    if (log_rtl_commit == 0) $display("ERROR: Could not open rtl_commit.log");
    $fdisplay(log_rtl_commit, "pc       | instr     | rd  | wr_data");
    $fdisplay(log_rtl_commit, "---------|-----------|-----|--------");
end

always @(posedge clk) begin
    if (rst) begin
        rtl_pc_Q103H_tb    <= 32'd0;
        rtl_pc_Q104H_tb    <= 32'd0;
        rtl_instr_Q102H_tb  <= 32'd0;
        rtl_instr_Q103H_tb  <= 32'd0;
        rtl_instr_Q104H_tb  <= 32'd0;
    end else begin
        rtl_pc_Q103H_tb    <= dut.pc_Q102H;
        rtl_pc_Q104H_tb    <= rtl_pc_Q103H_tb;
        rtl_instr_Q102H_tb  <= dut.instruction_Q101H;
        rtl_instr_Q103H_tb  <= rtl_instr_Q102H_tb;
        rtl_instr_Q104H_tb  <= rtl_instr_Q103H_tb;
    end
end

always @(posedge clk) begin
    if (!rst && log_rtl_commit != 0 && dut.u_rv_ctrl.ctrl_Q104H.valid && !ebreak_seen) begin
        if (dut.wb_ctrl.reg_write_en_Q104H)
            $fdisplay(log_rtl_commit, "%08h | %08h | x%02d | %08h",
                rtl_pc_Q104H_tb, rtl_instr_Q104H_tb,
                dut.wb_ctrl.reg_dst_Q104H, dut.wb_data_Q104H);
        else
            $fdisplay(log_rtl_commit, "%08h | %08h | x%02d | ---",
                rtl_pc_Q104H_tb, rtl_instr_Q104H_tb,
                dut.wb_ctrl.reg_dst_Q104H);
    end
end
