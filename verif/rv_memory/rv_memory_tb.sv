`timescale 1ns/1ps

module rv_memory_tb;

  // ============================
  // Parameters
  // ============================
  localparam IMEM_SIZE_WORDS = 256;
  localparam DMEM_SIZE_BYTES = 1024;

  // ============================
  // Clock / Reset
  // ============================
  logic clk;
  logic rst;

  initial clk = 0;
  always #5 clk = ~clk;

  // ============================
  // DUT signals
  // ============================
  logic [31:0] pc_Q100H;
  logic        ready_Q101H;
  logic [31:0] instruction_Q101H;

  logic [31:0] alu_out_Q103H;
  logic [31:0] dmem_wr_data_Q103H;
  logic        dmem_wr_en_Q103H;
  logic [3:0]  dmem_byte_en_Q103H;
  logic        dmem_is_signed_Q103H;
  logic [31:0] dmem_rd_data_Q104H;

  // ============================
  // DUT instantiation
  // ============================
  rv_memory #(
    .IMEM_SIZE_WORDS(IMEM_SIZE_WORDS),
    .DMEM_SIZE_BYTES(DMEM_SIZE_BYTES)
  ) dut (
    .clk(clk),
    .rst(rst),

    .pc_Q100H(pc_Q100H),
    .ready_Q101H(ready_Q101H),
    .instruction_Q101H(instruction_Q101H),

    .alu_out_Q103H(alu_out_Q103H),
    .dmem_wr_data_Q103H(dmem_wr_data_Q103H),
    .dmem_wr_en_Q103H(dmem_wr_en_Q103H),
    .dmem_byte_en_Q103H(dmem_byte_en_Q103H),
    .dmem_is_signed_Q103H(dmem_is_signed_Q103H),
    .dmem_rd_data_Q104H(dmem_rd_data_Q104H)
  );

  // ==========================================================
  // FIXED: Hierarchy Check
  // ==========================================================
  initial begin
    rst = 1;
    ready_Q101H = 0;
    pc_Q100H = 0;
    alu_out_Q103H = 0;
    dmem_wr_data_Q103H = 0;
    dmem_wr_en_Q103H = 0;
    dmem_byte_en_Q103H = 4'b1111;
    dmem_is_signed_Q103H = 0;

    // Load instruction memory via hierarchy: 
    // memory (dut) -> mem (i_mem) -> array (mem)
    $display("TB: Loading instruction memory into i_mem.mem array");
    $readmemh("verif/rv_memory/inst_mem.hex", dut.i_mem.mem);

    #20;
    rst = 0;
    ready_Q101H = 1;

    // ============================
    // Fetch few instructions
    // ============================
    repeat (5) begin
      @(posedge clk);
      $display("T=%0t | PC=0x%08h -> INSTR=0x%08h", 
               $time, pc_Q100H, instruction_Q101H);
      pc_Q100H += 4;
    end

    // ============================
    // Data memory write (D_MEM)
    // Hierarchy: memory (dut) -> wrap_mem (d_mem) -> mem (mem_array) -> array (mem)
    // ============================
    $display("TB: Writing to D_MEM at address 0x10");
    @(posedge clk);
    alu_out_Q103H = 32'h00000010;
    dmem_wr_data_Q103H = 32'hDEADBEEF;
    dmem_wr_en_Q103H = 1;

    @(posedge clk);
    dmem_wr_en_Q103H = 0;

    // ============================
    // Data memory read
    // ============================
    @(posedge clk);
    alu_out_Q103H = 32'h00000010;

    // Wait one more cycle because memory/wrapper has a register
    @(posedge clk); 
    $display("T=%0t | D_MEM READ DATA = 0x%08h", $time, dmem_rd_data_Q104H);

    if (dmem_rd_data_Q104H === 32'hDEADBEEF)
        $display("TB: SUCCESS - Data matched!");
    else
        $display("TB: ERROR - Data mismatch!");

    #20;
    $finish;
  end

endmodule