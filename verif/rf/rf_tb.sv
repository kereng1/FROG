`timescale 1ns / 1ps

module rf_tb;

    logic         clk = 0;
    logic [4:0]   rs1, rs2, rd;
    logic         write_e;
    logic [31:0]  write_d;
    logic [31:0]  reg_data1, reg_data2;

    rf dut (
        .clk       (clk),
        .rs        (rs1),
        .rt        (rs2),
        .rd        (rd),
        .write_e   (write_e),
        .write_d   (write_d),
        .reg_data1 (reg_data1),
        .reg_data2 (reg_data2)
    );

    always #5 clk = ~clk;

    initial begin
        {rs1, rs2, rd} = '0;
        write_e = 0;
        write_d = 0;

        /* Test 1 */
        @(posedge clk);
        rd      = 5'd4;
        write_d = 32'd42;
        write_e = 1;
        $display("[%0t] WRITE  x4  = %0d", $time, write_d);

        @(posedge clk);
        write_e = 0;
        rs1 = 5'd4;
        rs2 = 5'd0;
        $display("[%0t] READ   rs1=x4  rs2=x0", $time);
        #1;

        if (reg_data1 === 42 && reg_data2 === 0)
            $display("PASS-T1  x4=%0d  x0=%0d", reg_data1, reg_data2);
        else
            $display("FAIL-T1  x4=%0d  x0=%0d", reg_data1, reg_data2);

        /* Test 2 */
        @(posedge clk);
        rd      = 5'd2;
        write_d = 32'd99;
        write_e = 1;
        $display("[%0t] WRITE  x2  = %0d", $time, write_d);

        @(posedge clk);
        write_e = 0;
        rs1 = 5'd2;
        rs2 = 5'd4;
        $display("[%0t] READ   rs1=x2  rs2=x4", $time);
        #1;

        if (reg_data1 === 99 && reg_data2 === 42)
            $display("PASS-T2  x2=%0d  x4=%0d", reg_data1, reg_data2);
        else
            $display("FAIL-T2  x2=%0d  x4=%0d", reg_data1, reg_data2);

        @(posedge clk);
        $display("Simulation completed");
        $finish;
    end

endmodule
