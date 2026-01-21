// ========================================================================
// RV_DMEM_WRAP
// ========================================================================
// Data memory wrapper module with synchronous read support
// Provides byte/halfword/word read and write support
// Handles byte alignment and sign/zero extension for LOAD operations
// Wraps the lower-level rv_mem module
//
// Pipeline timing:
//   Q103H: Request arrives (addr, wr_data, wr_en, byte_en, is_signed)
//   Q104H: Read data returns (rd_data)
//
// Parameters:
//   MEM_SIZE_BYTES : Total memory size in bytes (adjustable)
//   MEM_SIZE_WORDS : Number of 32-bit words (computed automatically)
//

`include "source/common/dff_macros.svh"

module rv_dmem_wrap #(
    parameter MEM_SIZE_BYTES = 1024,
    parameter MEM_SIZE_WORDS = MEM_SIZE_BYTES / 4
)(
    input  logic         clk,
    
    // Q103H inputs (Memory Access stage)
    input  logic [31:0]  addr_Q103H,       // Byte-level address from CPU
    input  logic [31:0]  wr_data_Q103H,    // Data to write from CPU
    input  logic         wr_en_Q103H,      // Write enable from CPU
    input  logic         is_signed_Q103H,  // For LOAD: 1=sign-extend, 0=zero-extend
    input  logic [3:0]   byte_en_Q103H,    // 0001=byte, 0011=halfword, 1111=word
    
    // Q104H output (Write Back stage)
    output logic [31:0]  rd_data_Q104H     // Data to CPU
);

    //----------------------------------------
    // Q103H Internal signals (write path)
    //----------------------------------------
    logic [31:0] mem_wr_data_Q103H;     // Shifted write data
    logic [31:0] word_addr_Q103H;       // Word-aligned address
    logic [3:0]  shifted_byte_en_Q103H; // Byte enable shifted according to address offset
    logic [1:0]  byte_offset_Q103H;     // Byte offset within 32-bit word

    assign byte_offset_Q103H = addr_Q103H[1:0];
    assign word_addr_Q103H = addr_Q103H[31:2];

    //----------------------------------------
    // Q104H Internal signals (read path - pipelined)
    //----------------------------------------
    logic [3:0]  byte_en_Q104H;         // Pipelined byte enable
    logic [1:0]  byte_offset_Q104H;     // Pipelined byte offset
    logic        is_signed_Q104H;       // Pipelined sign extend flag
    logic [31:0] mem_rd_data_Q104H;     // Data output from rv_mem (already registered)
    logic [31:0] read_mask_Q104H;       // Mask for valid bytes during read
    logic [31:0] aligned_data_Q104H;    // Read data after masking and alignment

    //----------------------------------------
    // Pipeline registers: Q103H -> Q104H
    //----------------------------------------
    `DFF(byte_en_Q104H, byte_en_Q103H, clk)
    `DFF(byte_offset_Q104H, byte_offset_Q103H, clk)
    `DFF(is_signed_Q104H, is_signed_Q103H, clk)

    //----------------------------------------
    // SHIFT BYTE_EN FOR WRITE ACCORDING TO OFFSET (Q103H)
    //----------------------------------------
    always_comb begin
        case (byte_offset_Q103H)
            2'b00: shifted_byte_en_Q103H = byte_en_Q103H;
            2'b01: shifted_byte_en_Q103H = byte_en_Q103H << 1;
            2'b10: shifted_byte_en_Q103H = byte_en_Q103H << 2;
            2'b11: shifted_byte_en_Q103H = byte_en_Q103H << 3;
            default: shifted_byte_en_Q103H = 4'b0000;
        endcase
    end

    //----------------------------------------
    // WRITE DATA ALIGNMENT (Q103H)
    //----------------------------------------
    always_comb begin
        mem_wr_data_Q103H = 32'b0;

        // Iterate over each byte lane
        for (int i=0; i<4; i++) begin
            if (shifted_byte_en_Q103H[i]) begin
                // Select proper bits from wr_data depending on byte_en size
                if (byte_en_Q103H == 4'b0001)
                    mem_wr_data_Q103H[i*8 +: 8] = wr_data_Q103H[7:0];
                else if (byte_en_Q103H == 4'b0011)
                    mem_wr_data_Q103H[i*8 +: 8] = wr_data_Q103H[(i-byte_offset_Q103H)*8 +: 8];
                else // word
                    mem_wr_data_Q103H[i*8 +: 8] = wr_data_Q103H[i*8 +: 8];
            end
        end
    end
    
    //----------------------------------------
    // INSTANTIATE rv_mem
    // Note: rv_mem has synchronous read - rd_data is registered internally
    //----------------------------------------
    rv_mem #(
        .MEM_SIZE_WORDS(MEM_SIZE_WORDS)
    ) u_dmem (
        .clk     (clk),
        .addr    (word_addr_Q103H),          // word index (Q103H)
        .wr_en   (wr_en_Q103H),
        .wr_data (mem_wr_data_Q103H),
        .byte_en (shifted_byte_en_Q103H),
        .rd_data (mem_rd_data_Q104H)         // registered output (Q104H)
    );


    //----------------------------------------
    // READ PATH: CREATE MASK AND ALIGN DATA (Q104H)
    // Uses pipelined control signals to match read data timing
    //----------------------------------------
    always_comb begin
        //------------------------------------
        // STEP 1: SHIFT BYTE_EN FOR READ ACCORDING TO OFFSET (Q104H)
        //------------------------------------
        case (byte_offset_Q104H)
            2'b00: read_mask_Q104H = byte_en_Q104H;
            2'b01: read_mask_Q104H = byte_en_Q104H << 1;
            2'b10: read_mask_Q104H = byte_en_Q104H << 2;
            2'b11: read_mask_Q104H = byte_en_Q104H << 3;
            default: read_mask_Q104H = 4'b0000;
        endcase

        //------------------------------------
        // STEP 2: MASK MEM DATA (Q104H)
        //------------------------------------
        aligned_data_Q104H = 0;
        if (read_mask_Q104H[0]) aligned_data_Q104H[7:0]   = mem_rd_data_Q104H[7:0];
        if (read_mask_Q104H[1]) aligned_data_Q104H[15:8]  = mem_rd_data_Q104H[15:8];
        if (read_mask_Q104H[2]) aligned_data_Q104H[23:16] = mem_rd_data_Q104H[23:16];
        if (read_mask_Q104H[3]) aligned_data_Q104H[31:24] = mem_rd_data_Q104H[31:24];

        //------------------------------------
        // STEP 3: SHIFT TO LSB (Q104H)
        //------------------------------------
        aligned_data_Q104H = aligned_data_Q104H >> (8*byte_offset_Q104H);

        //------------------------------------
        // STEP 4: SIGN OR ZERO EXTEND (Q104H)
        //------------------------------------
        case (byte_en_Q104H)
            4'b0001: begin // BYTE
                if (is_signed_Q104H)
                    rd_data_Q104H = {{24{aligned_data_Q104H[7]}}, aligned_data_Q104H[7:0]};
                else
                    rd_data_Q104H = {24'b0, aligned_data_Q104H[7:0]};
            end

            4'b0011: begin // HALFWORD
                if (is_signed_Q104H)
                    rd_data_Q104H = {{16{aligned_data_Q104H[15]}}, aligned_data_Q104H[15:0]};
                else
                    rd_data_Q104H = {16'b0, aligned_data_Q104H[15:0]};
            end

            4'b1111: begin // WORD
                rd_data_Q104H = aligned_data_Q104H;
            end

            default: rd_data_Q104H = aligned_data_Q104H;
        endcase
    end

endmodule // rv_dmem_wrap
