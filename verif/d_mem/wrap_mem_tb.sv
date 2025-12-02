`timescale 1ns/1ps

module wrap_mem_tb;

    // -----------------------
    // Parameters & Signals
    // -----------------------
    parameter MEM_SIZE = 16; // Small size for testing
    logic clk;
    logic [31:0] addr;
    logic [31:0] wr_data;
    logic [31:0] rd_data;
    logic wr_en;
    logic [1:0] size;

    // Instantiate wrap_mem
    wrap_mem #(.MEM_SIZE_WORDS(MEM_SIZE)) dut (
        .clk(clk),
        .addr(addr),
        .wr_data(wr_data),
        .wr_en(wr_en),
        .size(size),
        .rd_data(rd_data)
    );

    // -----------------------
    // Clock generation
    // -----------------------
    initial clk = 0;
    always #5 clk = ~clk; // 10ns period

    // -----------------------
    // Test sequence
    // -----------------------
    initial begin
        // Initialize
        wr_en = 0; addr = 0; wr_data = 0; size = 2'b10;
        #10;

        $display("\n--- BYTE WRITE/READ (SB/LB) ---");
        // Byte write to unaligned address 5
        addr = 5; wr_data = 8'hAA; wr_en = 1; size = 2'b00; 
        #10; wr_en = 0;

        // Read back byte at addr 5
        addr = 5; size = 2'b00; 
        #10; $display("Read byte at addr 5: %h (expected AA)", rd_data[7:0]);

        // Byte write to unaligned address 6
        addr = 6; wr_data = 8'hBB; wr_en = 1; size = 2'b00; 
        #10; wr_en = 0;

        // Read back byte at addr 6
        addr = 6; size = 2'b00; 
        #10; $display("Read byte at addr 6: %h (expected BB)", rd_data[7:0]);

        $display("\n--- HALFWORD WRITE/READ (SH/LH) ---");
        // Halfword write to lower half of word at addr 4
        addr = 4; wr_data = 16'h1234; wr_en = 1; size = 2'b01;
        #10; wr_en = 0;

        // Read back halfword at addr 4
        addr = 4; size = 2'b01;
        #10; $display("Read halfword at addr 4: %h (expected 1234)", rd_data[15:0]);

        // Halfword write to upper half of word at addr 6
        addr = 6; wr_data = 16'h5678; wr_en = 1; size = 2'b01;
        #10; wr_en = 0;

        // Read back halfword at addr 6
        addr = 6; size = 2'b01;
        #10; $display("Read halfword at addr 6: %h (expected 5678)", rd_data[15:0]);

        $display("\n--- WORD WRITE/READ (SW/LW) ---");
        // Word write to aligned address 8
        addr = 8; wr_data = 32'hDEADBEEF; wr_en = 1; size = 2'b10;
        #10; wr_en = 0;

        // Read back word at addr 8
        addr = 8; size = 2'b10;
        #10; $display("Read word at addr 8: %h (expected DEADBEEF)", rd_data);

        // Word write to aligned address 12
        addr = 12; wr_data = 32'hCAFEBABE; wr_en = 1; size = 2'b10;
        #10; wr_en = 0;

        // Read back word at addr 12
        addr = 12; size = 2'b10;
        #10; $display("Read word at addr 12: %h (expected CAFEBABE)", rd_data);

        $display("\n================ FULL WORD TEST =================");

        // -------- Write full 32-bit word at unaligned address 5 --------
        addr = 4; 
        wr_data = 32'hA1B2C3D4;
        wr_en = 1; size = 2'b10;
        #10; wr_en = 0;

        // -------- Read back FULL word --------
        addr = 4; size = 2'b10;
        #10;
        $display("\nFull word read @ addr 4: %b (expected %b)", rd_data, 32'hA1B2C3D4);

        // -------- Read individual bytes --------
        // Byte 0
        addr = 4; size = 2'b00;
        #10;
        $display("Byte[0] (addr 4): %b (hex: %h)", rd_data[7:0], rd_data[7:0]);

        // Byte 1
        addr = 5; size = 2'b00;
        #10;
        $display("Byte[1] (addr 5): %b (hex: %h)", rd_data[7:0], rd_data[7:0]);

        // Byte 2
        addr = 6; size = 2'b00;
        #10;
        $display("Byte[2] (addr 6): %b (hex: %h)", rd_data[7:0], rd_data[7:0]);

        // Byte 3
        addr = 7; size = 2'b00;
        #10;
        $display("Byte[3] (addr 7): %b (hex: %h)", rd_data[7:0], rd_data[7:0]);


        $display("\n================ HALF WORD + BYTE TEST =================");

        // Write 16-bit value at unaligned address 9
        addr = 9;
        wr_data = 16'h7777;
        wr_en = 1; size = 2'b01;
        #10; wr_en = 0;
        
        // Read full word to see effect
        addr = 8; size = 2'b10;
        #10;
        $display("\nFull word after halfwrite @ addr 9: %b", rd_data);

        // Read only one byte inside that halfword
        addr = 10; size = 2'b00;
        #10;
        $display("Byte from halfword write (addr 10): %b (hex %h)", rd_data[7:0], rd_data[7:0]);

        $display("\n--- TEST COMPLETE ---");
        $stop;
    end

endmodule
