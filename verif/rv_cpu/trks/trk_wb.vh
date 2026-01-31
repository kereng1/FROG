//------------------------------------------------------------------------------
// Title      : trk_wb
// Description: Final stage tracker - Monitors data being committed to Register File.
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
// Title      : rv_cpu_wb_tracker
// Description: Final stage tracker - Monitors data being committed to Register File.
//------------------------------------------------------------------------------

initial begin
    log_wb = $fopen("target/rv_cpu/logs/trk/trk_wb.log", "w");
    if (log_wb == 0) $display("ERROR: Could not open trk_wb.log");

    $fdisplay(log_wb, "==========================================================================================");
    $fdisplay(log_wb, " Cycle | Instruction  | Result (WB) | rd  | RegWr | Data Src    | Status");
    $fdisplay(log_wb, "==========================================================================================");
end

always @(posedge clk) begin
    if (!rst && log_wb != 0) begin
        $fdisplay(log_wb, " %5d | %-12s |  %h   | x%02d |   %b   | %-11s | %s",
            cycle_count,
            name_Q104H, 
            dut.wb_data_Q104H,
            // התיקון כאן: ניגשים ל-rd דרך ה-wb_ctrl שנמצא ב-dut
            dut.wb_ctrl.reg_dst_Q104H, 
            dut.wb_ctrl.reg_write_en_Q104H,
            (dut.u_rv_ctrl.ctrl_Q104H.wb_sel == SEL_DMEM_RD_DATA) ? "FROM_MEM" : "FROM_ALU",
            (dut.wb_ctrl.reg_write_en_Q104H && dut.wb_ctrl.reg_dst_Q104H != 0) ? "COMMITTED" : "DISCARDED"
        );
    end
end