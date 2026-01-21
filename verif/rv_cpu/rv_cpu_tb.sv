//----------------------------------------------------------
// Title      : rv_cpu_tb
// Project    : RISC-V 5-Stage Pipeline
//----------------------------------------------------------
// Simple testbench with XMR IMEM loading and signal tracking
// Note: rv_cpu now has internal memory (rv_mem_wrap)
//----------------------------------------------------------

`timescale 1ns/1ps

module rv_cpu_tb;
    import rv_pkg::*;

    //----------------------------------------------------------
    // Parameters
    //----------------------------------------------------------
    parameter CLK_PERIOD = 20;
    parameter IMEM_SIZE_WORDS = 256;  // Size of instruction memory
    parameter DMEM_SIZE_BYTES = 1024; // Size of data memory

    //----------------------------------------------------------
    // Signals
    //----------------------------------------------------------
    logic clk;
    logic rst;

    int log_fd;
    int cycle_count;

    //----------------------------------------------------------
    // DUT - rv_cpu now has internal memory
    //----------------------------------------------------------
    rv_cpu dut (
        .clk (clk),
        .rst (rst)
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
        #100; // 100ns delay
        rst = 1'b0;
    end

    //----------------------------------------------------------
    // Load the program into instruction memory via XMR
    // Path: dut -> u_rv_mem_wrap -> i_mem -> mem
    //----------------------------------------------------------
    initial begin
        // 1. First, clear memory or fill with NOPs (optional but recommended)
        for (int i = 0; i < IMEM_SIZE_WORDS; i++) begin
            dut.u_rv_mem_wrap.i_mem.mem[i] = 32'h00000013; // NOP
        end

        // 2. Load the program from the HEX file using XMR
        $display("TB: Loading program from verif/rv_cpu/inst_mem.hex into IMEM");
        $readmemh("verif/rv_cpu/inst_mem.hex", dut.u_rv_mem_wrap.i_mem.mem);
    end

    //----------------------------------------------------------
    // Trackers (console + log file)
    //----------------------------------------------------------
    initial begin
        log_fd = $fopen("target/rv_cpu/logs/rv_cpu_trace.log", "w");
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
                dut.core2dmem_req_Q103H.address, dut.core2dmem_req_Q103H.wr_en, dut.core2dmem_req_Q103H.rd_en, dut.core2dmem_req_Q103H.wr_data,
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
