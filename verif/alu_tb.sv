module tb_alu;

    logic [7:0] A, B;
    logic [2:0] alu_op;
    logic [7:0] Y;
    logic zero_flag;

    alu uut (.A(A), .B(B), .alu_op(alu_op), .Y(Y), .zero_flag(zero_flag));

    initial begin
        A = 8'd10; B = 8'd3;
        for (int i = 0; i < 8; i++) begin
            alu_op = i[2:0];
            #10;
            $display("op=%0b | A=%0d B=%0d -> Y=%0d | zero=%0b",
                     alu_op, A, B, Y, zero_flag);
        end
        $finish;
    end

endmodule