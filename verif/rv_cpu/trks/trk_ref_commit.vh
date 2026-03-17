//------------------------------------------------------------------------------
// trk_ref_commit - Reference model commit tracker
// Logs every committed instruction: pc | instruction | rd | wr_data
// Format matches trk_rtl_commit for diff. If no RF write, wr_data = "---"
//------------------------------------------------------------------------------

initial begin
    log_ref_commit = $fopen("target/rv_cpu/logs/trk/ref_commit.log", "w");
    if (log_ref_commit == 0) $display("ERROR: Could not open ref_commit.log");
    $fdisplay(log_ref_commit, "pc       | instr     | rd  | wr_data");
    $fdisplay(log_ref_commit, "---------|-----------|-----|--------");
end

always @(posedge clk) begin
    if (!rst && log_ref_commit != 0 && run && !ebreak_seen) begin
        if (ref_rf_write.valid)
            $fdisplay(log_ref_commit, "%08h | %08h | x%02d | %08h",
                ref_pc, ref_instruction, ref_rf_write.rd, ref_rf_write.data);
        else
            $fdisplay(log_ref_commit, "%08h | %08h | x%02d | ---",
                ref_pc, ref_instruction, ref_rf_write.rd);
    end
end
