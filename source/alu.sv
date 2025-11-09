
//modif 

module alu (
    input  logic [7:0] A,       // Operand A
    input  logic [7:0] B,       // Operand B
    input  logic [2:0] alu_op,  // Operation selector
    output logic [7:0] Y,       // Result
    output logic zero_flag      // 1 if Y == 0
);

    always_comb begin
        case (alu_op)
            3'b000: Y = A + B;               // ADD
            3'b001: Y = A - B;               // SUB
            3'b010: Y = A & B;               // AND
            3'b011: Y = A | B;               // OR
            3'b100: Y = A ^ B;               // XOR
            3'b101: Y = ~A;                  // NOT
            3'b110: Y = A << 1;              // Shift left
            3'b111: Y = (A < B) ? 8'd1 : 8'd0; // Compare
            default: Y = 8'd0;
        endcase
    end

    assign zero_flag = (Y == 8'd0);

endmodule