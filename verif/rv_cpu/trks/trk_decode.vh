//------------------------------------------------------------------------------
// Title      : trk_decode
// Description: Monitors the Decode stage based on rv_decode.sv signals
//------------------------------------------------------------------------------
/*
-------------------------------------------------------------------------------------------
       ID STAGE TRACKER COLUMN EXPLANATIONS
-------------------------------------------------------------------------------------------
1. Cycle      : Clock cycle count.
2. PC (ID)    : Program Counter of the instruction currently being decoded.
3. Instr Name : Human-readable instruction name (e.g., ADDI, LW).
4. rs1/rs2/rd : Indices of source and destination registers (x0-x31).
5. rs1/2 Data : Values read from the Register File (after internal forwarding).
6. Immediate  : The sign-extended immediate value calculated from the bits.
7. Fwd Match  : Internal RF Forwarding (rs1/rs2 status).
                - 1/0: Match on rs1. Data taken directly from WB stage (bypass RF).
                - 0/1: Match on rs2. Data taken directly from WB stage (bypass RF).
                - 0/0: No match. Data read normally from Register File memory.
                This solves the Hazard where an instruction reads a register 
                at the same time it is being written by the WB stage.
-------------------------------------------------------------------------------------------
*/

initial begin
    log_id = $fopen("target/rv_cpu/logs/trk/trk_decode.log", "w");
    if (log_id == 0) $display("ERROR: Could not open trk_decode.log");

    $fdisplay(log_id, "==========================================================================================================================");
    $fdisplay(log_id, " Cycle |  PC (ID)  | Instr Name | rs1 | rs2 | rd  |   rs1 Data   |   rs2 Data   |   Immediate  | Fwd Match");
    $fdisplay(log_id, "==========================================================================================================================");
end

always @(posedge clk) begin
    if (!rst && log_id != 0) begin
        // Print aligned data without Imm Type column
        $fdisplay(log_id, " %5d | %h | %-10s | x%02d | x%02d | x%02d |   %h   |   %h   |   %h   |   %b/%b",
            cycle_count,
            dut.u_rv_decode.pc_Q101H,
            inst_name,
            dut.u_rv_decode.ctrl.reg_src1_Q101H,
            dut.u_rv_decode.ctrl.reg_src2_Q101H,
            dut.u_rv_decode.ctrl.rd_Q101H,
            dut.u_rv_decode.reg_rd_data1_Q101H,
            dut.u_rv_decode.reg_rd_data2_Q101H,
            dut.u_rv_decode.imm_Q101H,
            dut.u_rv_decode.match_rs1_aftr_wb_Q101H,
            dut.u_rv_decode.match_rs2_aftr_wb_Q101H
        );
    end
end