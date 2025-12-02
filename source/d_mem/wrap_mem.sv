module wrap_mem #(
    parameter MEM_SIZE_WORDS = 256
)(
    input  logic         clk,
    input  logic [31:0]  addr,       // Byte address from CPU
    input  logic [31:0]  wr_data,    // CPU write value
    input  logic         wr_en,      // CPU write enable
    input  logic [1:0]   size,       // 00=byte, 01=halfword, 10=word
    output logic [31:0]  rd_data     // Value returned to CPU
);

    // --------------------------------------
    // Internal signals to d_mem
    // --------------------------------------
    logic [31:0] mem_rd_data; // A word that came out of the d_mem
    logic [31:0] mem_wr_data; // A word that we want to write to d_mem
    logic [31:0] word_addr; // Address in d_mem
    logic [3:0]  byte_en; // Future use

    // Offset inside the word
    logic [1:0] byte_offset;

    assign word_addr   = addr[31:2];
    assign byte_offset = addr[1:0];


    // --------------------------------------
    // Write data packing and byte enable
    // --------------------------------------
    always_comb begin
        byte_en     = 4'b0000;
        mem_wr_data = 32'b0;

        case (size)

            2'b00: begin  // BYTE
                byte_en[byte_offset] = 1'b1;
                mem_wr_data = wr_data << (8 * byte_offset);
            end

            2'b01: begin  // HALFWORD
                if (byte_offset == 2'b00) begin
                    byte_en     = 4'b0011;
                    mem_wr_data = {16'b0, wr_data[15:0]};
                end else begin
                    byte_en     = 4'b1100;
                    mem_wr_data = {wr_data[15:0], 16'b0};
                end
            end

            2'b10: begin  // WORD
                byte_en     = 4'b1111;
                mem_wr_data = wr_data;
            end

            default: begin
                byte_en     = 4'b0000;
                mem_wr_data = 32'b0;
            end
        endcase
    end


    // --------------------------------------
    // d_mem instance
    // --------------------------------------
    d_mem #(.MEM_SIZE_WORDS(MEM_SIZE_WORDS)) dmem_inst (
        .clk(clk),
        .addr(word_addr),
        .wr_en(wr_en),
        .wr_data(mem_wr_data),
        .byte_en(byte_en),
        .rd_data(mem_rd_data)
    );


    // --------------------------------------
    // Read data extraction
    // --------------------------------------
    always_comb begin
        case (size)

            2'b00: begin // BYTE
                case(byte_offset)
                    2'b00: rd_data = {24'd0, mem_rd_data[7:0]};
                    2'b01: rd_data = {24'd0, mem_rd_data[15:8]};
                    2'b02: rd_data = {24'd0, mem_rd_data[23:16]};
                    2'b03: rd_data = {24'd0, mem_rd_data[31:24]};
                endcase
            end

            2'b01: begin // HALFWORD
                if (byte_offset == 2'b00)
                    rd_data = {16'd0, mem_rd_data[15:0]};
                else
                    rd_data = {16'd0, mem_rd_data[31:16]};
            end

            2'b10: begin // WORD
                rd_data = mem_rd_data;
            end

            default:
                rd_data = 32'b0;
        endcase
    end

endmodule
