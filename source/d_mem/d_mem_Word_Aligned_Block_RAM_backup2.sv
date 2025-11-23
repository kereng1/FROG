// Data Memory Unit (DMEM) with Byte/Halfword Alignment Logic
// This module implements the "Shift Before and After" mechanism
// to interface with a physical 32-bit Word-Aligned Memory (Block RAM).
// The memory array itself is 32 bits wide, accessed only by the word address.

`include "dff_macros.svh"

// Parameters definition
module mem #(
    parameter WORD_WIDTH    = 32,
    parameter ADRS_WIDTH    = 32,
    // The memory is now defined by the number of words (1024 bytes / 4 = 256 words)
    parameter MEM_DEPTH_WORDS = 256 
)(
    input  logic        clk,        // Clock
    input  logic [ADRS_WIDTH-1:0] adrs,       // Full 32-bit Byte Address
    output logic [WORD_WIDTH-1:0] rd_data,    // Read Data Output (Shifted and Aligned to LSB)
    input  logic        rden,       // Read Enable
    input  logic        wren,       // Write Enable
    input  logic [WORD_WIDTH/8-1:0]  byt_en,     // Byte Enables (for user's requested data)
    input  logic        sign_ext,   // Sign Extension (ignored in this module, done outside)
    input  logic [WORD_WIDTH-1:0] wr_data     // Write Data Input
);

// Internal Constants and Signals
localparam WORD_ADRS_WIDTH = ADRS_WIDTH - 2; // Address width for 32-bit words
localparam BYTE_EN_SIZE    = WORD_WIDTH / 8; // 4

// 1. Address Breakdown
logic [WORD_ADRS_WIDTH-1:0] word_adrs; // The address used to access the 32-bit memory array
logic [1:0] offset;                    // The two LSBs of the address (adrs[1:0]), defining the start byte

assign word_adrs = adrs[ADRS_WIDTH-1:2];
assign offset    = adrs[1:0];

// -----------------------
// Memory Array Definition (Word Aligned)
// -----------------------
logic [WORD_WIDTH-1:0] mem [MEM_DEPTH_WORDS-1:0];
logic [WORD_WIDTH-1:0] next_mem [MEM_DEPTH_WORDS-1:0];

// The output of the memory read operation (before shifting)
logic [WORD_WIDTH-1:0] mem_out;

// -----------------------
// 2. Write Alignment Logic (Shift Left)
// -----------------------
logic [WORD_WIDTH-1:0] shifted_wr_data;
logic [BYTE_EN_SIZE-1:0] shifted_byte_en;

always_comb begin
    // Shift Data Left
    case (offset)
        2'b00: shifted_wr_data = wr_data;
        2'b01: shifted_wr_data = {wr_data[WORD_WIDTH-9:0], 8'b0};
        2'b10: shifted_wr_data = {wr_data[WORD_WIDTH-17:0], 16'b0};
        2'b11: shifted_wr_data = {wr_data[WORD_WIDTH-25:0], 24'b0};
        default: shifted_wr_data = wr_data;
    endcase

    // Shift Byte Enables Left
    case (offset)
        2'b00: shifted_byte_en = byt_en;
        2'b01: shifted_byte_en = {byt_en[BYTE_EN_SIZE-2:0], 1'b0};
        2'b10: shifted_byte_en = {byt_en[BYTE_EN_SIZE-3:0], 2'b0};
        2'b11: shifted_byte_en = {byt_en[BYTE_EN_SIZE-4:0], 3'b0};
        default: shifted_byte_en = byt_en;
    endcase
end

// -----------------------
// 3. Memory Write Logic (Next State Calculation)
// -----------------------
always_comb begin
    // Default: Keep old values
    for (int i = 0; i < MEM_DEPTH_WORDS; i++) begin
        next_mem[i] = mem[i]; 
    end
    
    // If wren is active, write the word
    if (wren) begin
        // Get current word from memory
        logic [WORD_WIDTH-1:0] current_word;
        logic [WORD_WIDTH-1:0] new_word;

        current_word = mem[word_adrs];
        new_word     = current_word;

        // Update only the bytes enabled
        for (int i = 0; i < BYTE_EN_SIZE; i++) begin
            if (shifted_byte_en[i]) begin
                // Assign the byte using [base +: width] syntax
                new_word[8*i +: 8] = shifted_wr_data[8*i +: 8];
            end
        end

        // Write the new word into the next state memory
        next_mem[word_adrs] = new_word;
    end
end


// -----------------------
// 4. Memory Read Operation
// -----------------------
always_comb begin
    mem_out = mem[word_adrs];
end

// -----------------------
// 5. Read Alignment Logic (Shift Right)
// -----------------------
always_comb begin
    if (rden) begin
        case (offset)
            2'b00: rd_data = mem_out;
            2'b01: rd_data = {8'b0, mem_out[WORD_WIDTH-1:8]};
            2'b10: rd_data = {16'b0, mem_out[WORD_WIDTH-1:16]};
            2'b11: rd_data = {24'b0, mem_out[WORD_WIDTH-1:24]};
            default: rd_data = {WORD_WIDTH{1'b0}};
        endcase
    end else begin
        rd_data = {WORD_WIDTH{1'b0}};
    end
end

// -----------------------
// 6. Memory Clocked Update (Sequential)
// -----------------------
`DFF_MEM(mem, next_mem, clk, wren)

endmodule
