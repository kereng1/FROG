// ========================================================================
// D_MEM
// ========================================================================
// Low-level 32-bit memory array
// Handles byte-enable writes and reads
// Implements a synchronous memory with D flip-flops macro
//
// Parameters:
//   MEM_SIZE_WORDS : Number of 32-bit words


`include "source/common/dff_macros.svh"

module mem #(
    parameter MEM_SIZE_WORDS = 256 
)(
    input  logic         clk,
    input  logic [31:0]  addr,      
    input  logic         wr_en,     
    input  logic [31:0]  wr_data,    
    input  logic [3:0]   byte_en,     
    output logic [31:0]  rd_data   
);

    //----------------------------------------
    // Internal memory arrays
    //----------------------------------------

    logic [31:0] mem      [0:MEM_SIZE_WORDS-1];
    logic [31:0] next_mem [0:MEM_SIZE_WORDS-1];

    logic [31:0] old_word;
    logic [31:0] new_word;

    // -----------------------
    // Write Logic
    // -----------------------
    // Copy current memory and update only enabled bytes

    always_comb begin
        for (int i = 0; i < MEM_SIZE_WORDS; i++)
            next_mem[i] = mem[i];

        if (wr_en) begin
            old_word = mem[addr];
            new_word = old_word;
            
            // Update only the bytes that are enabled
            if (byte_en[0]) new_word[7:0]   = wr_data[7:0];
            if (byte_en[1]) new_word[15:8]  = wr_data[15:8];
            if (byte_en[2]) new_word[23:16] = wr_data[23:16];
            if (byte_en[3]) new_word[31:24] = wr_data[31:24];

            next_mem[addr] = new_word;
        end
    end
    
    //----------------------------------------
    // MEMORY REGISTER UPDATE
    //----------------------------------------
    `DFF_MEM(mem, next_mem, clk, 1'b1)

    // -----------------------
    // Read Logic (with byte enable)
    // -----------------------
    always_comb begin
        rd_data = 32'b0; // default: all zeros
        if (byte_en[0]) rd_data[7:0]   = mem[addr][7:0];
        if (byte_en[1]) rd_data[15:8]  = mem[addr][15:8];
        if (byte_en[2]) rd_data[23:16] = mem[addr][23:16];
        if (byte_en[3]) rd_data[31:24] = mem[addr][31:24];
    end

endmodule
