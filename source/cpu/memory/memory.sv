// ============================================================================
// MEMORY STAGE (Q103H)
// Contains both Instruction Memory and Data Memory
// ============================================================================
`include "source/common/dff_macros.svh"

module memory #(
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
    input  logic [31:0] alu_out_Q103H,        // address
    input  logic [31:0] dmem_wr_data_Q103H,   // write data
    input  logic        dmem_wr_en_Q103H,
    input  logic [3:0]  dmem_byte_en_Q103H,
    input  logic        dmem_is_signed_Q103H,

    output logic [31:0] dmem_rd_data_Q104H
);

    // =========================================================================
    // Instruction Memory
    // =========================================================================
    logic [31:0] imem_rd_data_Q100H;

    d_mem #(
        .MEM_SIZE_WORDS(IMEM_SIZE_WORDS)
    ) i_mem (
        .clk     (clk),
        .addr    ({2'b00, pc_Q100H[31:2]}),
        .wr_en   (1'b0),
        .wr_data (32'b0),
        .byte_en (4'b1111),
        .rd_data (imem_rd_data_Q100H)
    );

    `DFF_RST_EN(
        instruction_Q101H,
        imem_rd_data_Q100H,
        clk,
        ready_Q101H,
        rst,
        32'h00000013   // NOP
    )

    // =========================================================================
    // Data Memory (MEM stage)
    // =========================================================================
    logic [31:0] dmem_rd_data_Q103H;

    wrap_mem #(
        .MEM_SIZE_BYTES(DMEM_SIZE_BYTES)
    ) d_mem (
        .clk       (clk),
        .addr      (alu_out_Q103H),
        .wr_data   (dmem_wr_data_Q103H),
        .wr_en     (dmem_wr_en_Q103H),
        .is_signed (dmem_is_signed_Q103H),
        .byte_en   (dmem_byte_en_Q103H),
        .rd_data   (dmem_rd_data_Q103H)
    );

    // Pipeline register MEM → WB
    `DFF_EN(
        dmem_rd_data_Q104H,
        dmem_rd_data_Q103H,
        clk,
        1'b1
    )

endmodule
