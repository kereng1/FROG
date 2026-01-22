//----------------------------------------------------------
// Title      : rv_cpu_tb
// Project    : RISC-V 5-Stage Pipeline
//----------------------------------------------------------
// Simple testbench with XMR IMEM loading and signal tracking
// Note: rv_cpu now has internal memory (rv_mem_wrap)
//----------------------------------------------------------

`timescale 1ns/1ps

module rv_cpu_tb;
    import rv_pkg::*;

    //----------------------------------------------------------
    // Parameters
    //----------------------------------------------------------
    parameter CLK_PERIOD = 20;
    parameter IMEM_SIZE_WORDS = 256;  // Size of instruction memory
    parameter DMEM_SIZE_BYTES = 1024; // Size of data memory

    //----------------------------------------------------------
    // Signals
    //----------------------------------------------------------
    logic clk;
    logic rst;

    int log_if;
    int log_id;
    int log_exe;
    int log_mem;
    int log_wb;
    int cycle_count;

    //----------------------------------------------------------
    // DUT - rv_cpu now has internal memory
    //----------------------------------------------------------
    rv_cpu dut (
        .clk (clk),
        .rst (rst)
    );

    //----------------------------------------------------------
    // Clock + Reset
    //----------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        #100; // 100ns delay
        rst = 1'b0;
    end

    //----------------------------------------------------------
    // Load the program into instruction memory via XMR
    // Path: dut -> u_rv_mem_wrap -> i_mem -> mem
    //----------------------------------------------------------
    initial begin
        // 1. First, clear memory or fill with NOPs (optional but recommended)
        for (int i = 0; i < IMEM_SIZE_WORDS; i++) begin
            dut.u_rv_mem_wrap.i_mem.mem[i] = 32'h00000013; // NOP
        end

        // 2. Load the program from the HEX file using XMR
        $display("TB: Loading program from verif/rv_cpu/inst_mem.hex into IMEM");
        $readmemh("verif/rv_cpu/inst_mem.hex", dut.u_rv_mem_wrap.i_mem.mem);
    end

    //----------------------------------------------------------
    // Trackers
    //----------------------------------------------------------
    `include "verif/rv_cpu/trks/trk_if.vh"
    `include "verif/rv_cpu/trks/trk_decode.vh"
    `include "verif/rv_cpu/trks/trk_exe.vh"
    // Pipeline for Instruction Names to keep trackers synced
    string name_Q101H, name_Q102H, name_Q103H, name_Q104H;

    always @(posedge clk) begin
        if (rst) begin
            name_Q101H <= "NOP";
            name_Q102H <= "NOP";
            name_Q103H <= "NOP";
            name_Q104H <= "NOP";
        end else begin
            name_Q101H <= inst_name; // inst_name is the current decode result
            name_Q102H <= name_Q101H;
            name_Q103H <= name_Q102H;
            name_Q104H <= name_Q103H;
        end
    end
    `include "verif/rv_cpu/trks/trk_mem.vh"
    `include "verif/rv_cpu/trks/trk_wb.vh"
    //----------------------------------------------------------
    // End simulation
    //----------------------------------------------------------
    initial begin
        #2000;
        if (log_if != 0) $fclose(log_if);
        if (log_id != 0) $fclose(log_id);
        if (log_exe != 0) $fclose(log_exe);
        if (log_mem != 0) $fclose(log_mem);
        if (log_wb != 0) $fclose(log_wb);
        $finish;
    end

endmodule
