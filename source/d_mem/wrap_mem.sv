// ========================================================================
// WRAP_MEM
// ========================================================================
// Top-level memory wrapper module
// Provides byte/halfword/word read and write support
// Handles byte alignment and sign/zero extension for LOAD operations
// Wraps the lower-level d_mem module
//
// Parameters:
//   MEM_SIZE_BYTES : Total memory size in bytes (adjustable)
//   MEM_SIZE_WORDS : Number of 32-bit words (computed automatically)
//


module wrap_mem #(
    parameter MEM_SIZE_BYTES = 1024,                       // <<< CHANGED: define memory in bytes
    parameter MEM_SIZE_WORDS = MEM_SIZE_BYTES / 4          // <<< CHANGED: compute number of words automatically

)(
    input  logic         clk,
    input  logic [31:0]  addr,      // Byte-level address from CPU
    input  logic [31:0]  wr_data,   // Data to write from CPU
    input  logic         wr_en,     // Write enable from CPU
    input  logic         is_signed, // For LOAD: 1=sign-extend, 0=zero-extend
    input  logic [3:0]   byte_en,   // 0001=byte, 0011=halfword, 1111=word
    output logic [31:0]  rd_data    // Data to CPU
);

    //----------------------------------------
    // Internal signals
    //----------------------------------------
    logic [31:0] mem_rd_data;     // Data output from d_mem
    logic [31:0] mem_wr_data;     // Shifted write data
    logic [31:0] word_addr;       // Word-aligned address
    logic [3:0]  shifted_byte_en; // Byte enable shifted according to address offset
    logic [31:0] aligned_data;    // Read data after masking and alignment
    logic [31:0] read_mask;       // Mask for valid bytes during read

    logic [1:0] byte_offset;
    assign byte_offset = addr[1:0]; // Byte offset within 32-bit word
    assign word_addr = addr[31:2];

    //----------------------------------------
    // SHIFT BYTE_EN FOR WRITE ACCORDING TO OFFSET
    //----------------------------------------
    always_comb begin
        case (byte_offset)
            2'b00: shifted_byte_en = byte_en;
            2'b01: shifted_byte_en = byte_en << 1;
            2'b10: shifted_byte_en = byte_en << 2;
            2'b11: shifted_byte_en = byte_en << 3;
            default: shifted_byte_en = 4'b0000;
        endcase
    end


    always_comb begin
        mem_wr_data = 32'b0;

        // Iterate over each byte lane
        for (int i=0; i<4; i++) begin
            if (shifted_byte_en[i]) begin
                // Select proper bits from wr_data depending on byte_en size
                if (byte_en == 4'b0001)
                    mem_wr_data[i*8 +: 8] = wr_data[7:0];
                else if (byte_en == 4'b0011)
                    mem_wr_data[i*8 +: 8] = wr_data[(i-byte_offset)*8 +: 8];
                else // word
                    mem_wr_data[i*8 +: 8] = wr_data[i*8 +: 8];
            end
        end
    end
    //----------------------------------------
    // INSTANTIATE d_mem
    //----------------------------------------
    d_mem #(
        .MEM_SIZE_WORDS(MEM_SIZE_WORDS)
    ) memory (
        .clk     (clk),
        .addr    (word_addr),        // word index
        .wr_en   (wr_en),
        .wr_data (mem_wr_data),
        .byte_en (shifted_byte_en),
        .rd_data (mem_rd_data)
    );

    //----------------------------------------
    // READ PATH: CREATE MASK AND ALIGN DATA
    //----------------------------------------
    always_comb begin
        //------------------------------------
        // STEP 1: SHIFT BYTE_EN FOR READ ACCORDING TO OFFSET
        //------------------------------------
        case (byte_offset)
            2'b00: read_mask = byte_en;
            2'b01: read_mask = byte_en << 1;
            2'b10: read_mask = byte_en << 2;
            2'b11: read_mask = byte_en << 3;
            default: read_mask = 4'b0000;
        endcase

        //------------------------------------
        // STEP 2: MASK MEM DATA
        //------------------------------------
        aligned_data = 0;
        if (read_mask[0]) aligned_data[7:0]   = mem_rd_data[7:0];
        if (read_mask[1]) aligned_data[15:8]  = mem_rd_data[15:8];
        if (read_mask[2]) aligned_data[23:16] = mem_rd_data[23:16];
        if (read_mask[3]) aligned_data[31:24] = mem_rd_data[31:24];

        //------------------------------------
        // STEP 3: SHIFT TO LSB
        //------------------------------------
        aligned_data = aligned_data >> (8*byte_offset);

        //------------------------------------
        // STEP 4: SIGN OR ZERO EXTEND
        //------------------------------------
        case (byte_en)
            4'b0001: begin // BYTE
                if (is_signed)
                    rd_data = {{24{aligned_data[7]}}, aligned_data[7:0]};
                else
                    rd_data = {24'b0, aligned_data[7:0]};
            end

            4'b0011: begin // HALFWORD
                if (is_signed)
                    rd_data = {{16{aligned_data[15]}}, aligned_data[15:0]};
                else
                    rd_data = {16'b0, aligned_data[15:0]};
            end

            4'b1111: begin // WORD
                rd_data = aligned_data;
            end

            default: rd_data = aligned_data;
        endcase
    end

endmodule
