`timescale 1ns/1ps

module d_mem_tb;

    // -----------------------
    // Signals
    // -----------------------
    logic clk;
    logic [31:0] addr;
    logic wr_en;
    logic [31:0] wr_data;
    logic [3:0] byte_en;
    logic [31:0] rd_data;

    // Instantiate DUT
    d_mem #(.MEM_SIZE_WORDS(16)) dut (
        .clk(clk),
        .addr(addr),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .byte_en(byte_en),
        .rd_data(rd_data)
    );

    // -----------------------
    // Clock
    // -----------------------
    initial clk = 0;
    always #5 clk = ~clk; // 10ns period

    // -----------------------
    // Write helper
    // -----------------------
    task write(input int a, input [31:0] data, input [3:0] be);
        begin
            @(posedge clk);
            addr = a;
            wr_data = data;
            byte_en = be;
            wr_en = 1;
            @(posedge clk);
            wr_en = 0;
            $display("[WRITE] addr=%0d byte_en=%b data=0x%b", a, be, data);
        end
    endtask

    // -----------------------
    // Read helper
    // -----------------------
    task read(input int a, input [3:0] be);
        begin
            @(posedge clk);
            addr = a;
            byte_en = be;   // send same mask as write
            @(posedge clk);
            $display("[READ ] addr=%0d byte_en=%b --> rd_data=0x%b", a, be, rd_data);
        end
    endtask

    // -----------------------
    // Test sequence
    // -----------------------
    initial begin
        wr_en = 0; addr = 0; wr_data = 0; byte_en = 4'b0000;

        $display("\n========== START FULL d_mem TB ==========");

        // -----------------------
        // 1) Full word write at aligned address 0
        // -----------------------
        write(0, 32'hDEADBEEF, 4'b1111);
        read (0, 4'b1111);

        // -----------------------
        // 2) Halfword writes
        // -----------------------
        // Lower half at aligned addr 4
        write(4, 32'h00001234, 4'b0011);
        read(4, 4'b1111);

        // Upper half at aligned addr 4
        write(4, 32'h56780000, 4'b1100);
        read(4, 4'b1111);

        // -----------------------
        // 3) Byte writes
        // -----------------------
        write(8, 32'h000000AA, 4'b0001);
        read (8, 4'b1111);

        write(8, 32'h00BB0000, 4'b0100);
        read (8, 4'b1111);

        // -----------------------
        // 4) Single byte writes to all bytes sequentially
        // -----------------------
        write(12, 32'h11223344, 4'b0001); read(12, 4'b1111);  // byte0
        write(12, 32'h55667788, 4'b0010); read(12, 4'b1111);  // byte1
        write(12, 32'h99AABBCC, 4'b0100); read(12, 4'b1111);  // byte2
        write(12, 32'hDDEEFF00, 4'b1000); read(12, 4'b1111);  // byte3

        // -----------------------
        // 5) Attempt unaligned writes (should trigger error)
        // -----------------------
        write(2, 32'hCAFEBABE, 4'b1111);  // word write unaligned
        write(3, 32'h12345678, 4'b0011);  // halfword unaligned

        // -----------------------
        // 6) Mix of writes on same word
        // -----------------------
        write(1, 32'hAA000000, 4'b1000); read(1, 4'b1111);
        write(1, 32'h0000BB00, 4'b0100); read(1, 4'b1111);
        write(1, 32'h000000CC, 4'b0001); read(1, 4'b1111);

        $display("========== END FULL TB ==========\n");
        $stop;
    end

endmodule
