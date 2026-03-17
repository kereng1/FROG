//-----------------------------------------------------------------------------
// Title            : rv_cpu_tb
// Project          : RISC-V 5-Stage Pipeline
//-----------------------------------------------------------------------------
// Description:
// Testbench with Reference Model integration.
// Based on FPGA-MAFIA rv32i_ref testbench style.
// (1) Generate clock & reset
// (2) Load memories via XMR (force/release)
// (3) Compare RTL vs Reference Model
// (4) End test on ebreak/ecall or timeout
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

module rv_cpu_tb;
    import rv_pkg::*;
    import rv32i_ref_pkg::*;

    //----------------------------------------------------------
    // Parameters
    //----------------------------------------------------------
    parameter CLK_PERIOD = 20;
    parameter IMEM_SIZE_WORDS = 256;
    parameter IMEM_SIZE_BYTES = IMEM_SIZE_WORDS * 4;
    parameter DMEM_SIZE_BYTES = 1024;
    parameter DMEM_SIZE_WORDS = DMEM_SIZE_BYTES / 4;
    parameter TIMEOUT_CYCLES = 10000;

    //----------------------------------------------------------
    // Signals
    //----------------------------------------------------------
    logic clk;
    logic rst;
    logic run;

    // Tracker file handles
    int log_if;
    int log_id;
    int log_exe;
    int log_mem;
    int log_wb;
    int log_ref_commit;
    int log_rtl_commit;
    int cycle_count;

    // Commit trackers: ebreak gate + RTL pipeline (pc/instr to Q104H)
    logic ebreak_seen;
    logic [31:0] rtl_pc_Q103H_tb, rtl_pc_Q104H_tb;
    logic [31:0] rtl_instr_Q102H_tb, rtl_instr_Q103H_tb, rtl_instr_Q104H_tb;

    // Memory arrays for backdoor loading (match target memory indexing)
    // RTL uses [N-1:0], REF uses [0:N-1]
    logic [7:0]  RTL_IMem  [IMEM_SIZE_BYTES-1:0];
    logic [7:0]  RTL_DMem  [DMEM_SIZE_BYTES-1:0];
    logic [31:0] REF_IMem  [0:IMEM_SIZE_WORDS-1];
    logic [31:0] REF_DMem  [0:DMEM_SIZE_WORDS-1];

    // Reference model signals
    t_rf_write_txn   ref_rf_write;
    t_dmem_write_txn ref_dmem_write;
    t_dmem_read_txn  ref_dmem_read;
    logic [31:0]     ref_pc;
    logic [31:0]     ref_instruction;
    t_instr_type     ref_instr_type;

    // Checker signals
    logic check_error;
    int   rf_write_count;
    int   rf_error_count;
    int   dmem_write_count;
    int   dmem_error_count;
    logic do_final_compare;
    int   final_ref_count;
    int   final_rtl_count;
    int   final_rf_error_count;

    //----------------------------------------------------------
    // Instruction Decoder Function (for trackers)
    //----------------------------------------------------------
    function reg [7*8-1:0] decode_instr(input logic [31:0] instr);
        logic [6:0] opcode;
        logic [2:0] funct3;
        logic [6:0] funct7;
        
        opcode = instr[6:0];
        funct3 = instr[14:12];
        funct7 = instr[31:25];
        
        case (opcode)
            7'b0110011: begin // R-type
                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: return "ADD";
                    {7'b0100000, 3'b000}: return "SUB";
                    {7'b0000000, 3'b001}: return "SLL";
                    {7'b0000000, 3'b010}: return "SLT";
                    {7'b0000000, 3'b011}: return "SLTU";
                    {7'b0000000, 3'b100}: return "XOR";
                    {7'b0000000, 3'b101}: return "SRL";
                    {7'b0100000, 3'b101}: return "SRA";
                    {7'b0000000, 3'b110}: return "OR";
                    {7'b0000000, 3'b111}: return "AND";
                    default:              return "R-???";
                endcase
            end
            7'b0010011: begin // I-type ALU
                case (funct3)
                    3'b000: return "ADDI";
                    3'b010: return "SLTI";
                    3'b011: return "SLTIU";
                    3'b100: return "XORI";
                    3'b110: return "ORI";
                    3'b111: return "ANDI";
                    3'b001: return "SLLI";
                    3'b101: return (funct7 == 7'b0100000) ? "SRAI" : "SRLI";
                    default: return "I-???";
                endcase
            end
            7'b0000011: begin // Load
                case (funct3)
                    3'b000: return "LB";
                    3'b001: return "LH";
                    3'b010: return "LW";
                    3'b100: return "LBU";
                    3'b101: return "LHU";
                    default: return "L-???";
                endcase
            end
            7'b0100011: begin // Store
                case (funct3)
                    3'b000: return "SB";
                    3'b001: return "SH";
                    3'b010: return "SW";
                    default: return "S-???";
                endcase
            end
            7'b1100011: begin // Branch
                case (funct3)
                    3'b000: return "BEQ";
                    3'b001: return "BNE";
                    3'b100: return "BLT";
                    3'b101: return "BGE";
                    3'b110: return "BLTU";
                    3'b111: return "BGEU";
                    default: return "B-???";
                endcase
            end
            7'b1101111: return "JAL";
            7'b1100111: return "JALR";
            7'b0110111: return "LUI";
            7'b0010111: return "AUIPC";
            7'b1110011: return "SYSTEM";
            7'b0001111: return "FENCE";
            default:    return (instr == 32'h00000013) ? "NOP" : "???";
        endcase
    endfunction

    //----------------------------------------------------------
    // Clock Generation
    //----------------------------------------------------------
    initial begin: clock_gen
        clk = 1'b0;
        forever begin
            #(CLK_PERIOD/2) clk = 1'b0;
            #(CLK_PERIOD/2) clk = 1'b1;
        end
    end

    //----------------------------------------------------------
    // Reset Generation
    //----------------------------------------------------------
    initial begin: reset_gen
        rst = 1'b1;
        #100;
        rst = 1'b0;
    end

    // REF runs with backpressure from RTL retirement.
    assign run = !rst && dut.u_rv_ctrl.ctrl_Q104H.valid;

    // Latch ebreak so commit trackers stop logging
    always @(posedge clk) begin
        if (rst) ebreak_seen <= 1'b0;
        else     ebreak_seen <= ebreak_seen | u_ref.ebreak_called;
    end

    //----------------------------------------------------------
    // DUT - RTL CPU
    //----------------------------------------------------------
    rv_cpu dut (
        .clk (clk),
        .rst (rst)
    );

    //----------------------------------------------------------
    // Reference Model
    //----------------------------------------------------------
    rv32i_ref #(
        .IMEM_SIZE_WORDS(IMEM_SIZE_WORDS),
        .DMEM_SIZE_BYTES(DMEM_SIZE_BYTES)
    ) u_ref (
        .clk             (clk),
        .rst             (rst),
        .run             (run),
        .rf_write_txn    (ref_rf_write),
        .dmem_write_txn  (ref_dmem_write),
        .dmem_read_txn   (ref_dmem_read),
        .ref_pc          (ref_pc),
        .ref_instruction (ref_instruction),
        .ref_instr_type  (ref_instr_type)
    );

    //----------------------------------------------------------
    // Checker - Compare RTL vs Reference
    //----------------------------------------------------------
    initial do_final_compare = 1'b0;

    rv_cpu_checker u_checker (
        .clk                (clk),
        .rst                (rst),
        .run                (run),
        .do_final_compare   (do_final_compare),
        .ebreak_detected    (u_ref.ebreak_called),
        .ref_rf_write       (ref_rf_write),
        .ref_dmem_write     (ref_dmem_write),
        .rtl_rf_wr_en       (dut.wb_ctrl.reg_write_en_Q104H),
        .rtl_rf_rd          (dut.wb_ctrl.reg_dst_Q104H),
        .rtl_rf_wr_data     (dut.wb_data_Q104H),
        .rtl_pc_Q104H       (dut.pc_Q102H), // TEMP: use execute-stage PC until ctrl-based retire PC is added
        .rtl_dmem_wr_en     (dut.core2dmem_req_Q103H.wr_en),
        .rtl_dmem_addr      (dut.alu_out_Q103H),
        .rtl_dmem_wr_data   (dut.dmem_wr_data_Q103H),
        .rtl_dmem_byte_en   (dut.core2dmem_req_Q103H.byte_en),
        .check_error        (check_error),
        .rf_write_count     (rf_write_count),
        .rf_error_count     (rf_error_count),
        .dmem_write_count   (dmem_write_count),
        .dmem_error_count   (dmem_error_count),
        .final_ref_count   (final_ref_count),
        .final_rtl_count   (final_rtl_count),
        .final_rf_error_count (final_rf_error_count)
    );

    //----------------------------------------------------------
    // Test Sequence - Load memories via XMR (force/release)
    //----------------------------------------------------------
    initial begin: test_seq
        //======================================
        // Load program to TB arrays
        //======================================
        // RTL uses byte-organized memory
        $readmemh("output_tools/inst_mem.sv", RTL_IMem);
        $readmemh("output_tools/data_mem.sv", RTL_DMem);
        
        // REF uses word-organized memory
        $readmemh("output_tools/inst_mem_word.sv", REF_IMem);
        $readmemh("output_tools/data_mem_word.sv", REF_DMem);
        
        //======================================
        // Backdoor load via XMR (force/release)
        //======================================
        $display("TB: Loading memories via XMR...");
        
        // Force RTL instruction memory (byte-organized)
        force dut.u_rv_mem_wrap.i_mem.mem = RTL_IMem;
        
        // Force REF instruction memory (word-organized)
        force u_ref.imem = REF_IMem;
        force u_ref.dmem = REF_DMem;
        
        #10;
        
        // Release after loading
        release dut.u_rv_mem_wrap.i_mem.mem;
        release u_ref.imem;
        release u_ref.dmem;
        
        $display("TB: Memory loading complete");
        
        //======================================
        // Timeout watchdog
        //======================================
        #(CLK_PERIOD * TIMEOUT_CYCLES);
        $error("ERROR: TIMEOUT after %0d cycles", TIMEOUT_CYCLES);
        eot("TIMEOUT");
    end

    //----------------------------------------------------------
    // EOT (End of Test) Detection
    //----------------------------------------------------------
    initial begin: check_eot
        forever begin
            @(posedge clk);
            if (!rst && run) begin
                if (u_ref.ebreak_called) eot("ebreak");
                if (u_ref.ecall_called)  eot("ecall");
            end
        end
    end

    //----------------------------------------------------------
    // EOT Task - Print summary and finish
    //----------------------------------------------------------
    task eot(input string reason);
        // Close tracker files
        if (log_if != 0)        $fclose(log_if);
        if (log_id != 0)        $fclose(log_id);
        if (log_exe != 0)       $fclose(log_exe);
        if (log_mem != 0)       $fclose(log_mem);
        if (log_wb != 0)        $fclose(log_wb);
        if (log_ref_commit != 0) $fclose(log_ref_commit);
        if (log_rtl_commit != 0)  $fclose(log_rtl_commit);
        
        // Trigger final array compare (REF vs RTL RF writes)
        do_final_compare = 1'b1;
        #(CLK_PERIOD * 2);
        
        // Print summary (array comparison at end of test)
        $display("\n");
        $display("========================================");
        $display("        END OF TEST: %s", reason);
        $display("========================================");
        $display("  Total Cycles:      %0d", cycle_count);
        $display("  REF RF writes:     %0d", final_ref_count);
        $display("  RTL RF writes:     %0d", final_rtl_count);
        $display("  RF mismatches:     %0d", final_rf_error_count);
        $display("----------------------------------------");
        
        if (final_rf_error_count == 0) begin
            $display("  STATUS: PASS");
        end else begin
            $display("  STATUS: FAIL");
        end
        $display("========================================\n");
        
        $finish;
    endtask

    //----------------------------------------------------------
    // Trackers (keep existing)
    //----------------------------------------------------------
    `include "verif/rv_cpu/trks/trk_if.vh"
    `include "verif/rv_cpu/trks/trk_decode.vh"
    `include "verif/rv_cpu/trks/trk_exe.vh"
    
    // Pipeline for Instruction Names to keep trackers synced
    reg [7*8-1:0] name_Q101H, name_Q102H, name_Q103H, name_Q104H;

    always @(posedge clk) begin
        if (rst) begin
            name_Q101H <= "NOP";
            name_Q102H <= "NOP";
            name_Q103H <= "NOP";
            name_Q104H <= "NOP";
        end else begin
            name_Q101H <= inst_name;
            name_Q102H <= name_Q101H;
            name_Q103H <= name_Q102H;
            name_Q104H <= name_Q103H;
        end
    end
    
    `include "verif/rv_cpu/trks/trk_mem.vh"
    `include "verif/rv_cpu/trks/trk_wb.vh"

    // Commit trackers: same format for diff (ref_commit.log vs rtl_commit.log)
    `include "verif/rv_cpu/trks/trk_ref_commit.vh"
    `include "verif/rv_cpu/trks/trk_rtl_commit.vh"

endmodule
