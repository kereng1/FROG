//----------------------------------------------------------
// Title      : rv_cpu_tb
// Project    : RISC-V 5-Stage Pipeline
//----------------------------------------------------------
// Description:
// Simple testbench for rv_cpu
// Tests basic instructions: ADDI, ADD, SUB, LW, SW
//----------------------------------------------------------

`timescale 1ns/1ps

module rv_cpu_tb;
    import pkg::*;

    //----------------------------------------------------------
    // Parameters
    //----------------------------------------------------------
    parameter CLK_PERIOD = 10;
    parameter IMEM_SIZE  = 64;   // 64 words = 256 bytes
    parameter DMEM_SIZE  = 256;  // 256 words = 1KB

    //----------------------------------------------------------
    // Signals
    //----------------------------------------------------------
    logic        clk;
    logic        rst;
    
    // Instruction Memory Interface
    logic [31:0] imem_addr;
    logic [31:0] imem_rd_data;
    
    // Data Memory Interface
    t_core2mem_req core2dmem_req;
    logic [31:0]   dmem_rd_data;

    //----------------------------------------------------------
    // Clock Generation
    //----------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //----------------------------------------------------------
    // DUT Instantiation
    //----------------------------------------------------------
    rv_cpu u_dut (
        .clk            (clk),
        .rst            (rst),
        .imem_addr      (imem_addr),
        .imem_rd_data   (imem_rd_data),
        .core2dmem_req  (core2dmem_req),
        .dmem_rd_data   (dmem_rd_data)
    );

    //----------------------------------------------------------
    // Instruction Memory (Simple ROM)
    //----------------------------------------------------------
    logic [31:0] imem [0:IMEM_SIZE-1];
    
    // Word-aligned address for instruction memory
    logic [31:0] imem_word_addr;
    assign imem_word_addr = imem_addr[31:2];
    
    // Instruction read (combinational - 0 cycle latency)
    assign imem_rd_data = (imem_word_addr < IMEM_SIZE) ? imem[imem_word_addr] : 32'h00000013; // NOP (ADDI x0, x0, 0)

    //----------------------------------------------------------
    // Data Memory (Using wrap_mem)
    //----------------------------------------------------------
    wrap_mem #(
        .MEM_SIZE_BYTES(DMEM_SIZE * 4)
    ) u_dmem (
        .clk      (clk),
        .addr     (core2dmem_req.address),
        .wr_data  (core2dmem_req.wr_data),
        .wr_en    (core2dmem_req.wr_en),
        .is_signed(1'b1),  // Sign extend for loads
        .byte_en  (core2dmem_req.byte_en),
        .rd_data  (dmem_rd_data)
    );

    //----------------------------------------------------------
    // Test Program
    //----------------------------------------------------------
    // Simple test program:
    // 0x00: ADDI x1, x0, 10      # x1 = 10
    // 0x04: ADDI x2, x0, 20      # x2 = 20
    // 0x08: ADD  x3, x1, x2      # x3 = x1 + x2 = 30
    // 0x0C: SUB  x4, x2, x1      # x4 = x2 - x1 = 10
    // 0x10: SW   x3, 0(x0)       # mem[0] = x3 = 30
    // 0x14: LW   x5, 0(x0)       # x5 = mem[0] = 30
    // 0x18: ADDI x6, x5, 5       # x6 = x5 + 5 = 35
    // 0x1C: NOP                  # (ADDI x0, x0, 0)
    
    initial begin
        // Initialize instruction memory
        for (int i = 0; i < IMEM_SIZE; i++) begin
            imem[i] = 32'h00000013; // NOP
        end
        
        // Load test program
        imem[0] = 32'h00A00093;  // ADDI x1, x0, 10
        imem[1] = 32'h01400113;  // ADDI x2, x0, 20
        imem[2] = 32'h002081B3;  // ADD  x3, x1, x2
        imem[3] = 32'h40110233;  // SUB  x4, x2, x1
        imem[4] = 32'h00302023;  // SW   x3, 0(x0)
        imem[5] = 32'h00002283;  // LW   x5, 0(x0)
        imem[6] = 32'h00528313;  // ADDI x6, x5, 5
        imem[7] = 32'h00000013;  // NOP
    end

    //----------------------------------------------------------
    // Test Sequence
    //----------------------------------------------------------
    initial begin
        $display("========================================");
        $display("  RISC-V CPU Testbench Started");
        $display("========================================");
        
        // Initialize
        rst = 1;
        
        // Hold reset for a few cycles
        repeat(3) @(posedge clk);
        rst = 0;
        
        $display("[%0t] Reset released", $time);
        
        // Run for enough cycles to execute all instructions
        // 5-stage pipeline + 8 instructions + some margin
        repeat(30) @(posedge clk);
        
        // Check results
        $display("\n========================================");
        $display("  Test Results");
        $display("========================================");
        
        // Access register file through hierarchy
        $display("Register File Contents:");
        $display("  x1 = %0d (expected: 10)", u_dut.u_rv_decode.rf[1]);
        $display("  x2 = %0d (expected: 20)", u_dut.u_rv_decode.rf[2]);
        $display("  x3 = %0d (expected: 30)", u_dut.u_rv_decode.rf[3]);
        $display("  x4 = %0d (expected: 10)", u_dut.u_rv_decode.rf[4]);
        $display("  x5 = %0d (expected: 30)", u_dut.u_rv_decode.rf[5]);
        $display("  x6 = %0d (expected: 35)", u_dut.u_rv_decode.rf[6]);
        
        $display("\nData Memory Contents:");
        $display("  mem[0] = %0d (expected: 30)", u_dmem.memory.mem[0]);
        
        // Simple pass/fail check
        if (u_dut.u_rv_decode.rf[1] == 10 &&
            u_dut.u_rv_decode.rf[2] == 20 &&
            u_dut.u_rv_decode.rf[3] == 30 &&
            u_dut.u_rv_decode.rf[4] == 10 &&
            u_dut.u_rv_decode.rf[6] == 35) begin
            $display("\n========================================");
            $display("  TEST PASSED!");
            $display("========================================");
        end else begin
            $display("\n========================================");
            $display("  TEST FAILED!");
            $display("========================================");
        end
        
        $finish;
    end

    //----------------------------------------------------------
    // Waveform Dump (optional - for debugging)
    //----------------------------------------------------------
    initial begin
        $dumpfile("rv_cpu_tb.vcd");
        $dumpvars(0, rv_cpu_tb);
    end

    //----------------------------------------------------------
    // Monitor (optional - for debugging pipeline)
    //----------------------------------------------------------
    always @(posedge clk) begin
        if (!rst) begin
            $display("[%0t] PC=%08h Instr=%08h", $time, imem_addr, imem_rd_data);
        end
    end

endmodule

