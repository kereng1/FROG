`timescale 1ns/1ps

module wrap_mem_tb;

    logic clk;
    
    // Q103H inputs
    logic [31:0] addr_Q103H;
    logic [31:0] wr_data_Q103H;
    logic        wr_en_Q103H;
    logic [3:0]  byte_en_Q103H;
    logic        is_signed_Q103H;
    
    // Q104H output
    logic [31:0] rd_data_Q104H;

    // Instantiate rv_dmem_wrap (renamed from wrap_mem)
    rv_dmem_wrap #(.MEM_SIZE_BYTES(64)) uut (
        .clk            (clk),
        .addr_Q103H     (addr_Q103H),
        .wr_data_Q103H  (wr_data_Q103H),
        .wr_en_Q103H    (wr_en_Q103H),
        .byte_en_Q103H  (byte_en_Q103H),
        .is_signed_Q103H(is_signed_Q103H),
        .rd_data_Q104H  (rd_data_Q104H)
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Task to write memory and display wr_data
    task write_mem(input [31:0] a, input [31:0] d, input [3:0] be);
        begin
            @(negedge clk);
            addr_Q103H = a;
            wr_data_Q103H = d;
            byte_en_Q103H = be;
            wr_en_Q103H = 1;
            @(negedge clk);
            wr_en_Q103H = 0;
            $display("WRITE | addr=%b | byte_en=%b | wr_data=%b", addr_Q103H, byte_en_Q103H, wr_data_Q103H);
        end
    endtask

    // Task to read memory (note: rd_data comes out in Q104H, one cycle later)
    task read_mem(input [31:0] a, input [3:0] be, input signed_flag);
        begin
            @(negedge clk);
            addr_Q103H = a;
            byte_en_Q103H = be;
            is_signed_Q103H = signed_flag;
            wr_en_Q103H = 0;
            @(negedge clk); // Wait for Q103H -> Q104H
            @(negedge clk); // Data available in Q104H
            $display("READ  | addr=%b | byte_en=%b | signed=%b | rd_data=%b", a, be, signed_flag, rd_data_Q104H);
        end
    endtask

    initial begin
        $display("Starting rv_dmem_wrap test...");
        
        // Initialize
        addr_Q103H = 0;
        wr_data_Q103H = 0;
        wr_en_Q103H = 0;
        byte_en_Q103H = 4'b1111;
        is_signed_Q103H = 0;
        
        #20; // Wait for initial settling

        // Example 1: Write a full word to addr=0
        write_mem(0, 32'b11110000111100001111000011110000, 4'b1111);
        read_mem(0, 4'b1111, 0);

        // Example 2: Write halfword to addr=2 (offset 2 within word 0)
        write_mem(2, 32'b1010101010101010, 4'b0011);
        read_mem(2, 4'b0011, 0);

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

        $display("rv_dmem_wrap test finished.");
        $stop;
    end

endmodule
