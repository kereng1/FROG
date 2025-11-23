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
// The memory is now 256 words deep, and each entry is 32 bits wide.
logic [WORD_WIDTH-1:0] mem [MEM_DEPTH_WORDS-1:0];
logic [WORD_WIDTH-1:0] next_mem [MEM_DEPTH_WORDS-1:0];

// The output of the memory read operation (before shifting)
logic [WORD_WIDTH-1:0] mem_out;


// -----------------------
// 2. Write Alignment Logic (Shift Left)
// -----------------------
// Shifts the incoming data and byte enables left based on the offset.
// This ensures the data lands in the correct byte lane of the 32-bit memory word.

logic [WORD_WIDTH-1:0] shifted_wr_data;
logic [BYTE_EN_SIZE-1:0] shifted_byte_en;

always_comb begin
    // Shift Data Left
    case (offset)
        2'b00: shifted_wr_data = wr_data;                                  // Offset 0: No shift
        2'b01: shifted_wr_data = {wr_data[WORD_WIDTH-9:0], 8'b0};          // Offset 1: Shift left by 8 bits
        2'b10: shifted_wr_data = {wr_data[WORD_WIDTH-17:0], 16'b0};        // Offset 2: Shift left by 16 bits
        2'b11: shifted_wr_data = {wr_data[WORD_WIDTH-25:0], 24'b0};        // Offset 3: Shift left by 24 bits
        default: shifted_wr_data = wr_data; // Should not happen
    endcase

    // Shift Byte Enables Left
    case (offset)
        2'b00: shifted_byte_en = byt_en;                                  // Offset 0: No shift
        2'b01: shifted_byte_en = {byt_en[BYTE_EN_SIZE-2:0], 1'b0};        // Offset 1: Shift left by 1
        2'b10: shifted_byte_en = {byt_en[BYTE_EN_SIZE-3:0], 2'b0};        // Offset 2: Shift left by 2
        2'b11: shifted_byte_en = {byt_en[BYTE_EN_SIZE-4:0], 3'b0};        // Offset 3: Shift left by 3
        default: shifted_byte_en = byt_en; // Should not happen
    endcase
end


// -----------------------
// 3. Memory Write Logic (Next State Calculation)
// -----------------------
// Writes the SHIFTED data and uses the SHIFTED byte enables.
always_comb begin
    // Default: Keep old values
    for (int i = 0; i < MEM_DEPTH_WORDS; i++) begin
        next_mem[i] = mem[i]; 
    end
    
    // If wren is active, write the word
    if (wren) begin
        // The memory word being written
        logic [WORD_WIDTH-1:0] current_word = mem[word_adrs];
        logic [WORD_WIDTH-1:0] new_word     = current_word;

        // Loop through all 4 bytes of the word
        for (int i = 0; i < BYTE_EN_SIZE; i++) begin
            if (shifted_byte_en[i]) begin
                // Update only the specific byte lane defined by the shifted byte enable
                new_word[i*8 + 7 : i*8] = shifted_wr_data[i*8 + 7 : i*8]; 
            end
        end
        // Write the new (partially updated) word into the next state memory
        next_mem[word_adrs] = new_word;
    end
end


// -----------------------
// 4. Memory Read Operation (Always active on the Word Address)
// -----------------------
// The memory always outputs the full 32-bit word from the aligned address.
always_comb begin
    // Read the full word from the aligned address
    mem_out = mem[word_adrs];
end


// -----------------------
// 5. Read Alignment Logic (Shift Right)
// -----------------------
// Shifts the 32-bit word from memory right based on the offset.
// This moves the requested byte/halfword to the LSB (bits 7:0 or 15:0).

always_comb begin
    if (rden) begin
        // Shift Right: Move the requested byte/halfword to the LSB position (rd_data[7:0])
        case (offset)
            2'b00: rd_data = mem_out;                                // Offset 0: No shift
            2'b01: rd_data = {8'b0, mem_out[WORD_WIDTH-1:8]};        // Offset 1: Shift right by 8 bits
            2'b10: rd_data = {16'b0, mem_out[WORD_WIDTH-1:16]};      // Offset 2: Shift right by 16 bits
            2'b11: rd_data = {24'b0, mem_out[WORD_WIDTH-1:24]};      // Offset 3: Shift right by 24 bits
            default: rd_data = {WORD_WIDTH{1'b0}};
        endcase
        
        // Note: The final output (rd_data) now contains the requested byte/halfword 
        // ALIGNED to its LSB, ready for Sign/Zero Extension in the next pipeline stage.
    end else begin
        // If rden is off, zero the output.
        rd_data = {WORD_WIDTH{1'b0}};
    end
end


// -----------------------
// 6. Memory Clocked Update (Sequential)
// -----------------------
// Update 'mem' from 'next_mem' only on posedge clk and when wren is active.
`DFF_MEM(mem, next_mem, clk, wren)

endmodule