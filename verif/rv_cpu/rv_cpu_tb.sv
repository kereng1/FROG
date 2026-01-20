//----------------------------------------------------------
// Title      : rv_cpu_tb
// Project    : RISC-V 5-Stage Pipeline
//----------------------------------------------------------
// Simple testbench with XMR IMEM loading and signal tracking
//----------------------------------------------------------

`timescale 1ns/1ps

module rv_cpu_tb;
    import pkg::*;

    //----------------------------------------------------------
    // Parameters
    //----------------------------------------------------------
    parameter CLK_PERIOD = 20;
    parameter IMEM_SIZE_WORDS = 256;  // Size of instruction memory
    parameter DMEM_SIZE_BYTES = 1024; // Size of data memory (64 words * 4 bytes)

    //----------------------------------------------------------
    // Signals
    //----------------------------------------------------------
    logic clk;
    logic rst;

    logic [31:0] imem_addr;
    logic [31:0] imem_rd_data;
    t_core2mem_req core2dmem_req;
    logic [31:0] dmem_rd_data;

    int log_fd;
    int cycle_count;

    //----------------------------------------------------------
    // DUT
    //----------------------------------------------------------
    rv_cpu dut (
        .clk            (clk),
        .rst            (rst),
        .imem_addr      (imem_addr),
        .imem_rd_data   (imem_rd_data),
        .core2dmem_req  (core2dmem_req),
        .dmem_rd_data   (dmem_rd_data)
    );
    
    //----------------------------------------------------------
    // FIXED: Using YOUR Unified Memory Module 
    // This replaces 'simple_imem' and the standalone 'wrap_mem'
    //----------------------------------------------------------
    memory #(
        .IMEM_SIZE_WORDS(IMEM_SIZE_WORDS),
        .DMEM_SIZE_BYTES(DMEM_SIZE_BYTES)
    ) u_unified_mem (
        .clk                 (clk),
        .rst                 (rst),
        
        // Instruction Interface (PC -> Instr)
        .pc_Q100H            (imem_addr),
        .ready_Q101H         (1'b1), // Keeps pipeline moving
        .instruction_Q101H   (imem_rd_data),

        // Data Interface (ALU out -> Read Data)
        .alu_out_Q103H       (core2dmem_req.address),
        .dmem_wr_data_Q103H  (core2dmem_req.wr_data),
        .dmem_wr_en_Q103H    (core2dmem_req.wr_en),
        .dmem_byte_en_Q103H  (core2dmem_req.byte_en),
        .dmem_is_signed_Q103H(1'b1), // Default signed, can be linked to req if exists
        .dmem_rd_data_Q104H  (dmem_rd_data)
    );

    //----------------------------------------------------------
    // Clock + Reset
    //----------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        #100;
        rst = 1'b0;
    end

    //----------------------------------------------------------
    // FIXED XMR: Load your memory module using readmemh
    // Pointing directly to the memory array inside your module
    //----------------------------------------------------------
    initial begin
        // 1. First, clear memory or fill with NOPs (optional but recommended)
        for (int i = 0; i < IMEM_SIZE_WORDS; i++) begin
            u_unified_mem.i_mem.mem[i] = 32'h00000013; // NOP
        end

        // 2. Load the program from the HEX file using XMR
        $display("TB: Loading program from verif/memory/inst_mem.hex into IMEM");
        $readmemh("verif/rv_cpu_tb/inst_mem.hex", u_unified_mem.i_mem.mem);
    end

    //----------------------------------------------------------
    // Trackers (console + log file)
    //----------------------------------------------------------
    initial begin
        log_fd = $fopen("verif/rv_cpu/rv_cpu_trace.log", "w");
        cycle_count = 0;
    end

    always @(posedge clk) begin
        if (!rst) begin
            $fdisplay(log_fd,
                "T=%0t C=%0d | PC=0x%08h NextPC=0x%08h | Instr=0x%08h Opcode=0x%02h | rs1=x%0d rs2=x%0d rd=x%0d | Reg1=%0d Reg2=%0d | ALU_in1=%0d ALU_in2=%0d ALU_out=%0d | DMEM_addr=0x%08h wr_en=%b rd_en=%b wr_data=%0d | wb_data=%0d wb_rd=x%0d wb_we=%b | ready_if=%b ready_id=%b ready_ex=%b ready_ma=%b ready_wb=%b",
                $time, cycle_count,
                dut.pc_Q100H, dut.u_rv_if.next_pc_Q100H,
                dut.instruction_Q101H, dut.instruction_Q101H[6:0],
                dut.decode_ctrl.reg_src1_Q101H, dut.decode_ctrl.reg_src2_Q101H, dut.decode_ctrl.rd_Q101H,
                dut.u_rv_decode.reg_rd_data1_Q101H, dut.u_rv_decode.reg_rd_data2_Q101H,
                dut.u_rv_exe.alu_in1_Q102H, dut.u_rv_exe.alu_in2_Q102H, dut.alu_out_Q102H,
                core2dmem_req.address, core2dmem_req.wr_en, core2dmem_req.rd_en, core2dmem_req.wr_data,
                dut.wb_data_Q104H, dut.wb_ctrl.reg_dst_Q104H, dut.wb_ctrl.reg_write_en_Q104H,
                dut.if_ctrl.ready_Q100H, dut.decode_ctrl.ready_Q102H, dut.exe_ctrl.ready_Q102H,
                dut.ma_ctrl.ready_Q103H, dut.wb_ctrl.ready_Q104H
            );

            $display(
                "C=%0d PC=0x%08h Instr=0x%08h ALU_out=%0d wb_rd=x%0d wb_we=%b",
                cycle_count, dut.pc_Q100H, dut.instruction_Q101H, dut.alu_out_Q102H,
                dut.wb_ctrl.reg_dst_Q104H, dut.wb_ctrl.reg_write_en_Q104H
            );

            cycle_count++;
        end
    end

    //----------------------------------------------------------
    // End simulation
    //----------------------------------------------------------
    initial begin
        #2000;
        $fclose(log_fd);
        $finish;
    end

endmodule

// -------------------------------------------------------------------
// Simple IMEM (combinational read)
// -------------------------------------------------------------------
module simple_imem #(parameter DEPTH = 64)(
    input  logic [31:0] addr,
    output logic [31:0] rdata
);
    logic [31:0] mem [0:DEPTH-1];
    assign rdata = mem[addr[31:2]];
endmodule
