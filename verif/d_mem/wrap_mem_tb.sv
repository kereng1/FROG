`timescale 1ns/1ps

module wrap_mem_tb;

    logic clk;
    logic [31:0] addr;
    logic [31:0] wr_data;
    logic wr_en;
    logic [3:0] byte_en;
    logic is_signed;
    logic [31:0] rd_data;

    // Instantiate wrap_mem
    wrap_mem #(.MEM_SIZE_WORDS(16)) uut (
        .clk(clk),
        .addr(addr),
        .wr_data(wr_data),
        .wr_en(wr_en),
        .byte_en(byte_en),
        .is_signed(is_signed),
        .rd_data(rd_data)
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Task to write memory and display wr_data
    task write_mem(input [31:0] a, input [31:0] d, input [3:0] be);
        begin
            @(negedge clk);
            addr = a;
            wr_data = d;
            byte_en = be;
            wr_en = 1;
            @(negedge clk);
            wr_en = 0;
            $display("WRITE | addr=%b | byte_en=%b | wr_data=%b", addr, byte_en, wr_data);
        end
    endtask

    // Task to read memory
    task read_mem(input [31:0] a, input [3:0] be, input signed_flag);
        begin
            @(negedge clk);
            addr = a;
            byte_en = be;
            is_signed = signed_flag;
            wr_en = 0;
            @(negedge clk);
            $display("READ  | addr=%b | byte_en=%b | signed=%b | rd_data=%b", addr, byte_en, is_signed, rd_data);
        end
    endtask

    initial begin
        $display("Starting wrap_mem test...");

        // Example 1: Write a full word to addr=0
        write_mem(0, 32'b11110000111100001111000011110000, 4'b1111);
        read_mem(0, 4'b1111, 0);

        // Example 2: Write halfword to addr=1 (offset 1)
        write_mem(1, 32'b1010101010101010, 4'b0011);
        read_mem(1, 4'b0011, 0);

        // Example 3: Write byte to addr=5
        write_mem(5, 32'b11001100, 4'b0001);
        read_mem(5, 4'b0001, 0);

        // Example 4: Write halfword to addr=6 (offset 2)
        write_mem(6, 32'b1111111100000000, 4'b0011);
        read_mem(6, 4'b0011, 0);

        // Example 5: Write word to addr=8
        write_mem(8, 32'b10101010101010101010101010101010, 4'b1111);
        read_mem(8, 4'b1111, 0);

        // Example 6: Another byte write to addr=11
        write_mem(11, 32'b00110011, 4'b0001);
        read_mem(11, 4'b0001, 0);
        read_mem(8, 4'b1111, 0);

        // Example 7: Halfword write to addr=2 (offset 2)
        write_mem(2, 32'b1111000011110000, 4'b0011);
        read_mem(2, 4'b0011, 1); // signed example

        $display("wrap_mem test finished.");
        $stop;
    end

endmodule
