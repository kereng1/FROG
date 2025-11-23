// Data Memory Unit (d_mem)
// Size: 1024-Byte array, supporting read/write operations in different sizes (Word, Halfword, Byte).
// Configuration: Single Port access (one address, separate rden/wren signals).
// Designed for a simple CPU Pipeline
// accesses do not conflict on the same memory module within the same clock cycle.

`include "dff_macros.svh"

// Generic parameters allowing easy scaling of the CPU's word width and memory depth.
module d_mem #(
    parameter WORD_WIDTH = 32,      // Width of a data word (Default: 32 bits)
    parameter ADRS_WIDTH = 32,      // Width of the address bus
    parameter MEM_DEPTH  = 1024     // Memory size in Bytes (1024 = 1KB)
)(
    input  logic        clk,        // Clock signal (Clock)
    input  logic [ADRS_WIDTH-1:0] adrs,       // Unified address for Read and Write operations
    output logic [WORD_WIDTH-1:0] rd_data,    // Read Data Output
    input  logic        rden,       // Read Enable (1: Perform Read)
    input  logic        wren,       // Write Enable (1: Perform Write)
    // Byte enable width equals the number of bytes in a word (32/8 = 4)
    input  logic [WORD_WIDTH/8-1:0]  byt_en,     // Byte Enables (controls which bytes to write)
    input  logic        sign_ext,   // Sign Extension Enable Flag
    input  logic [WORD_WIDTH-1:0] wr_data     // Write Data Input
);

// Memory array definition
// The memory is an array of MEM_DEPTH 8-bit registers (Bytes).
logic [7:0] mem [MEM_DEPTH-1:0];           // Physical Memory Array (Byte-addressable)
logic [7:0] next_mem [MEM_DEPTH-1:0];      // Next State Copy for combinational calculation

// Local constant for clarity
localparam BYTE_EN_SIZE = WORD_WIDTH / 8; // Number of bytes per word (e.g., 4)


// -----------------------
// Read Logic (Combinational)
// -----------------------
// The output rd_data is updated immediately based on the inputs (adrs, rden, sign_ext).
always_comb begin
    // If rden is inactive, the output is zeroed to prevent driving garbage values onto the bus.
    if (rden) begin 
        
        // 1. Read Byte 0 (Least Significant Byte) - Always read from the base address
        rd_data[7:0]   = mem[adrs]; 

        // ----------------------------------------------------
        // 2. Handle subsequent Bytes and Sign Extension
        // ----------------------------------------------------
        
        // Byte 1: adrs + 1. Bits: [15:8]
        if (BYTE_EN_SIZE > 1) begin
            if (byt_en[1] || byt_en[2] || byt_en[3]) begin
                // If Byte 1 or higher bytes are requested (Halfword/Word read), read Byte 1.
                rd_data[15:8]  = mem[adrs + 1];
            end else if (sign_ext) begin
                // If reading a Signed Byte (LB), perform sign extension using bit 7 (LSB sign bit).
                rd_data[15:8]  = {8{rd_data[7]}}; 
            end else begin
                // Otherwise (e.g., unsigned byte read), zero-extend.
                rd_data[15:8] = 8'b0;
            end
        end
        
        // Byte 2: adrs + 2. Bits: [23:16]
        if (BYTE_EN_SIZE > 2) begin
            if (byt_en[2] || byt_en[3]) begin
                // If reading Word, read Byte 2.
                rd_data[23:16] = mem[adrs + 2];
            end else if (sign_ext) begin
                // If sign_ext is active, extend sign using bit 15 (Halfword sign bit).
                rd_data[23:16] = {8{rd_data[15]}}; 
            end else begin
                rd_data[23:16] = 8'b0;
            end
        end

        // Byte 3: adrs + 3. Bits: [31:24]
        if (BYTE_EN_SIZE > 3) begin
            if (byt_en[3]) begin
                // If reading the most significant byte, read it.
                rd_data[31:24] = mem[adrs + 3];
            end else if (sign_ext) begin
                // Extend sign using bit 23 (Word sign bit).
                rd_data[31:24] = {8{rd_data[23]}}; 
            end else begin
                rd_data[31:24] = 8'b0;
            end
        end
    end else begin
        // If rden is off, zero the output.
        rd_data = {WORD_WIDTH{1'b0}};
    end
end


// -----------------------
// Write Logic (Combinational - Calculates Next State)
// -----------------------
// This block calculates the content of next_mem based on current mem and write inputs.
always_comb begin
    // 1. Default Copy: Preserve current values
    for (int i = 0; i < MEM_DEPTH; i++) begin
        next_mem[i] = mem[i]; 
    end
    
    // 2. Conditional Overwrite: If wren is active, calculate the write
    if (wren) begin
        // Loop through all bytes in the word (e.g., i=0 to 3 for 32-bit word)
        for (int i = 0; i < BYTE_EN_SIZE; i++) begin
            if (byt_en[i]) begin
                // If the byte enable flag for byte 'i' is active,
                // write the corresponding 8 bits from wr_data to the memory location: adrs + i
                next_mem[adrs + i] = wr_data[i*8 + 7 : i*8]; 
            end
        end
    end
end

// -----------------------
// Memory Clocked Update (Sequential)
// -----------------------
// The physical memory array 'mem' is updated from 'next_mem' only on the positive clock edge
// (posedge clk) AND only when the write enable (wren) is active.
// This is done via a predefined macro.
`DFF_MEM(mem, next_mem, clk, wren)

endmodule