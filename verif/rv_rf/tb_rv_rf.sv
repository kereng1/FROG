`timescale 1ns/1ps
import pkg::*;

module tb_rv_rf();

    //----------------------------------------------------------
    // 1. Signals Declaration
    //----------------------------------------------------------
    logic        clk;
    logic        rst;
    t_dec_ctrl   ctrl;
    logic        ready_Q102H;
    logic [31:0] pc_Q101H;
    logic [31:0] instruction_Q101H;
    logic [31:0] wb_data_Q104H;
    logic [4:0]  rd_Q104H;
    logic        reg_write_en_Q104H;

    // Outputs from DUT
    logic [31:0] pc_Q102H;
    logic [31:0] imm_Q102H;
    logic [31:0] reg_data1_Q102H;
    logic [31:0] reg_data2_Q102H;

    //----------------------------------------------------------
    // 2. Unit Under Test (DUT)
    //----------------------------------------------------------
    rv_rf dut (.*); 

    //----------------------------------------------------------
    // 3. Clock Generation (100MHz)
    //----------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    //----------------------------------------------------------
    // 4. Test Stimulus
    //----------------------------------------------------------
    initial begin
        // --- Step 1: Reset System ---
        $display("Starting Testbench...");
        rst = 1;
        ready_Q102H = 1;
        ctrl = '0;
        pc_Q101H = 32'h1000;
        instruction_Q101H = 32'h0;
        wb_data_Q104H = 0;
        rd_Q104H = 0;
        reg_write_en_Q104H = 0;
        
        repeat(2) @(posedge clk);
        rst = 0;
        $display("Reset Released.");

        // --- Step 2: Write data to x1 and x2 ---
        // Simulating instructions that reached the WB stage
        @(negedge clk);
        $display("Test 1: Writing to Registers x1 and x2");
        reg_write_en_Q104H = 1;
        rd_Q104H = 5'd1;
        wb_data_Q104H = 32'hAAAA_BBBB; // Data for x1
        @(negedge clk);
        rd_Q104H = 5'd2;
        wb_data_Q104H = 32'hCCCC_DDDD; // Data for x2
        @(negedge clk);
        reg_write_en_Q104H = 0;

        // --- Step 3: Normal Read (Read x1 and x2 in Decode) ---
        $display("Test 2: Normal Read from x1 and x2");
        ctrl.rs1_Q101H = 5'd1;
        ctrl.rs2_Q101H = 5'd2;
        @(posedge clk); // Wait for data to be latched into Q102
        #1; // Small delay to check outputs after clock edge
        if (reg_data1_Q102H === 32'hAAAA_BBBB && reg_data2_Q102H === 32'hCCCC_DDDD)
            $display("PASS: Normal Read successful.");
        else
            $display("FAIL: Normal Read failed. Got %h and %h", reg_data1_Q102H, reg_data2_Q102H);

        // --- Step 4: Internal Forwarding (Bypass) Test ---
        // Reading x3 in Q101 while WB is writing to x3 in the SAME cycle
        $display("Test 3: Internal Forwarding (Bypass)");
        ctrl.rs1_Q101H = 5'd3;
        rd_Q104H = 5'd3;
        wb_data_Q104H = 32'h1234_5678;
        reg_write_en_Q104H = 1;
        
        @(posedge clk); // This clock edge writes to RF AND latches to Q102
        #1;
        if (reg_data1_Q102H === 32'h1234_5678)
            $display("PASS: Internal Forwarding successful.");
        else
            $display("FAIL: Forwarding failed. Got %h", reg_data1_Q102H);

        // --- Step 5: x0 Hardwired Zero Test ---
        $display("Test 4: Register x0 is always zero");
        rd_Q104H = 5'd0; // Try to write to x0
        wb_data_Q104H = 32'hFFFF_FFFF;
        reg_write_en_Q104H = 1;
        ctrl.rs1_Q101H = 5'd0; // Read from x0
        
        @(posedge clk);
        #1;
        if (reg_data1_Q102H === 32'h0)
            $display("PASS: x0 is still zero.");
        else
            $display("FAIL: x0 was overwritten! Got %h", reg_data1_Q102H);

        // --- Step 6: Immediate Decoding (I-Type) ---
        $display("Test 5: Immediate Generation (I-Type)");
        ctrl.imm_type = IMM_I;
        instruction_Q101H = 32'hFF000293; // ADDI x5, x0, -16 (Immediate is 0xFF0)
        
        @(posedge clk);
        #1;
        if (imm_Q102H === 32'hFFFF_FFF0) // Should be sign-extended -16
            $display("PASS: I-Type Sign Extension correct.");
        else
            $display("FAIL: Imm Gen failed. Got %h", imm_Q102H);

        $display("--- All Tests Completed ---");
        $finish;
    end

endmodule