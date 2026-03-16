// ========================================================================
// D_MEM
// ========================================================================
// Low-level byte-addressable memory array
// Handles byte-enable writes and reads
// Implements a synchronous memory with D flip-flops macro
//
// Parameters:
//   MEM_SIZE_WORDS : Number of 32-bit words (total bytes = MEM_SIZE_WORDS * 4)


`include "source/common/dff_macros.svh"

module rv_mem #(
    parameter MEM_SIZE_WORDS = 256 
)(
    input  logic         clk,
    input  logic [31:0]  addr,      
    input  logic         wr_en,     
    input  logic [31:0]  wr_data,    
    input  logic [3:0]   byte_en,     
    output logic [31:0]  rd_data   
);

    localparam MEM_SIZE_BYTES = MEM_SIZE_WORDS * 4;

    //----------------------------------------
    // Internal memory arrays (byte-organized)
    //----------------------------------------

    logic [7:0] mem      [MEM_SIZE_BYTES-1:0];
    logic [7:0] next_mem [MEM_SIZE_BYTES-1:0];

    logic [31:0] base_addr;
    assign base_addr = {addr[29:0], 2'b00};

    // -----------------------
    // Write Logic
    // -----------------------

    always_comb begin
        for (int i = 0; i < MEM_SIZE_BYTES; i++)
            next_mem[i] = mem[i];

        if (wr_en) begin
            if (byte_en[0]) next_mem[base_addr]     = wr_data[7:0];
            if (byte_en[1]) next_mem[base_addr + 1]  = wr_data[15:8];
            if (byte_en[2]) next_mem[base_addr + 2]  = wr_data[23:16];
            if (byte_en[3]) next_mem[base_addr + 3]  = wr_data[31:24];
        end
    end
    
    //----------------------------------------
    // MEMORY REGISTER UPDATE
    //----------------------------------------
    `DFF_MEM(mem, next_mem, clk, 1'b1)

    // -----------------------
    // Read Logic (with byte enable)
    // -----------------------
    logic [31:0] pre_rd_data;

    always_comb begin
        pre_rd_data = 32'b0;
        if (byte_en[0]) pre_rd_data[7:0]   = mem[base_addr];
        if (byte_en[1]) pre_rd_data[15:8]  = mem[base_addr + 1];
        if (byte_en[2]) pre_rd_data[23:16] = mem[base_addr + 2];
        if (byte_en[3]) pre_rd_data[31:24] = mem[base_addr + 3];
    end

    `DFF(rd_data, pre_rd_data, clk)

endmodule
