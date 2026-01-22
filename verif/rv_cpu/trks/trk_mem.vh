//------------------------------------------------------------------------------
// Title      : trk_mem
// Description: Monitors Data Memory access using pipelined instruction names.
//------------------------------------------------------------------------------

/*
-------------------------------------------------------------------------------------------
       MEM STAGE TRACKER COLUMN EXPLANATIONS
-------------------------------------------------------------------------------------------
1. Cycle      : Clock cycle count.
2. Instruction: Pipelined name of the instruction in MEM stage (Q103H).
3. Addr (Byte): The full 32-bit byte address calculated by the ALU.
4. BE         : The 4-bit raw byte enable from Control Unit.
5. Shift BE   : The aligned byte enable actually sent to the memory array.
6. Write Data : Data to be stored (for SW/SH/SB instructions).
7. Read Data  : Data returned from memory (valid in Q104H).
-------------------------------------------------------------------------------------------
*/

initial begin
    log_mem = $fopen("target/rv_cpu/logs/trk/trk_mem.log", "w");
    if (log_mem == 0) $display("ERROR: Could not open trk_mem.log");

    $fdisplay(log_mem, "===============================================================================================================================");
    $fdisplay(log_mem, " Cycle | Instruction  | Addr (Byte) | BE | Shift BE | Write Data | Read (Q104) | Memory Activity");
    $fdisplay(log_mem, "===============================================================================================================================");
end

always @(posedge clk) begin
    if (!rst && log_mem != 0) begin
        $fdisplay(log_mem, " %5d | %-12s |  %h   | %b |   %b   |  %h  |  %h   | %s",
            cycle_count,
            name_Q103H, // Strictly synced to the MEM stage
            dut.u_rv_mem_wrap.u_dmem_wrap.addr_Q103H,
            dut.u_rv_mem_wrap.u_dmem_wrap.byte_en_Q103H,
            dut.u_rv_mem_wrap.u_dmem_wrap.shifted_byte_en_Q103H,
            dut.u_rv_mem_wrap.u_dmem_wrap.wr_data_Q103H,
            dut.u_rv_mem_wrap.u_dmem_wrap.rd_data_Q104H,
            (dut.u_rv_mem_wrap.u_dmem_wrap.wr_en_Q103H) ? "WRITE" : 
            (dut.u_rv_mem_wrap.u_dmem_wrap.byte_en_Q103H != 0) ? "READ " : "IDLE "
        );
    end
end