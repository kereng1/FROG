// ============================================================================
// MEMORY STAGE (Q103H)
// Contains both Instruction Memory and Data Memory
// ============================================================================

`include "source/common/dff_macros.svh"

module rv_mem_wrap #(
    parameter IMEM_SIZE_WORDS = 256,
    parameter DMEM_SIZE_BYTES = 1024
)(
    input  logic        clk,
    input  logic        rst,

    // ============================
    // Instruction Memory (IF → ID)
    // ============================
    input  logic [31:0] pc_Q100H,
    input  logic        ready_Q101H,
    output logic [31:0] instruction_Q101H,

    // ============================
    // Data Memory (EXE → MEM → WB)
    // ============================
    input  logic [31:0] alu_out_Q103H,        // byte address to do -remane to dmem_addr_Q103H
    input  logic [31:0] dmem_wr_data_Q103H,
    input  logic        dmem_wr_en_Q103H,
    input  logic [3:0]  dmem_byte_en_Q103H,
    input  logic        dmem_is_signed_Q103H,

    output logic [31:0] dmem_rd_data_Q104H
);

    // =========================================================================
    // Instruction Memory
    // =========================================================================
    logic [31:0] imem_rd_data_Q100H;

    // Instruction memory uses word-based depth parameter
    rv_mem #(
        .MEM_SIZE_WORDS(IMEM_SIZE_WORDS)
    ) i_mem (
        .clk     (clk),
        .addr    ({2'b00, pc_Q100H[31:2]}),   // word address
        .wr_en   (1'b0),             // instruction memory is read-only
        .wr_data (32'b0),
        .byte_en (4'b1111),
        .rd_data (instruction_Q101H)
    );


    // =========================================================================
    // Data Memory (MEM stage)
    // =========================================================================

    // rv_dmem_wrap wraps rv_mem internally
    // Input signals are Q103H, output rd_data is Q104H (synchronous read)
    rv_dmem_wrap #(
        .MEM_SIZE_BYTES(DMEM_SIZE_BYTES)
    ) u_dmem_wrap (
        .clk            (clk),
        .addr_Q103H     (alu_out_Q103H),
        .wr_data_Q103H  (dmem_wr_data_Q103H),
        .wr_en_Q103H    (dmem_wr_en_Q103H),
        .is_signed_Q103H(dmem_is_signed_Q103H),
        .byte_en_Q103H  (dmem_byte_en_Q103H),
        .rd_data_Q104H  (dmem_rd_data_Q104H)
    );

endmodule
