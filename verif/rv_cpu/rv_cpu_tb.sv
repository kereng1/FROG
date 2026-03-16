//----------------------------------------------------------
// Title      : rv_cpu_tb
// Project    : RISC-V 5-Stage Pipeline
//----------------------------------------------------------
// Testbench with Reference Model integration.
// Compares RTL vs Reference Model on RF writes and DMEM writes.
//----------------------------------------------------------

`timescale 1ns/1ps

module rv_cpu_tb;
    import rv_pkg::*;
    import rv32i_ref_pkg::*;

    //----------------------------------------------------------
    // Parameters
    //----------------------------------------------------------
    parameter CLK_PERIOD = 20;
    parameter IMEM_SIZE_WORDS = 256;
    parameter DMEM_SIZE_BYTES = 1024;
    parameter MAX_CYCLES = 500;

    //----------------------------------------------------------
    // Signals
    //----------------------------------------------------------
    logic clk;
    logic rst;

    int log_if;
    int log_id;
    int log_exe;
    int log_mem;
    int log_wb;
    int cycle_count;

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

    //----------------------------------------------------------
    // Instruction Decoder Function
    //----------------------------------------------------------
    function string decode_instr(input logic [31:0] instr);
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
    rv_cpu_checker u_checker (
        .clk              (clk),
        .rst              (rst),
        .run              (run),
        
        // Reference model transactions
        .ref_rf_write     (ref_rf_write),
        .ref_dmem_write   (ref_dmem_write),
        
        // RTL RF write signals (Q104H)
        .rtl_rf_wr_en     (dut.wb_ctrl.reg_write_en_Q104H),
        .rtl_rf_rd        (dut.wb_ctrl.reg_dst_Q104H),
        .rtl_rf_wr_data   (dut.wb_data_Q104H),
        
        // RTL DMEM write signals (Q103H)
        .rtl_dmem_wr_en   (dut.core2dmem_req_Q103H.wr_en),
        .rtl_dmem_addr    (dut.alu_out_Q103H),
        .rtl_dmem_wr_data (dut.dmem_wr_data_Q103H),
        .rtl_dmem_byte_en (dut.core2dmem_req_Q103H.byte_en),
        
        // Status outputs
        .check_error      (check_error),
        .rf_write_count   (rf_write_count),
        .rf_error_count   (rf_error_count),
        .dmem_write_count (dmem_write_count),
        .dmem_error_count (dmem_error_count)
    );

    //----------------------------------------------------------
    // Clock Generation
    //----------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //----------------------------------------------------------
    // Reset and Run Control
    //----------------------------------------------------------
    initial begin
        rst = 1'b1;
        run = 1'b0;
        #100;
        rst = 1'b0;
        run = 1'b1;
    end

    //----------------------------------------------------------
    // Load Program into RTL and Reference Model IMEM
    //----------------------------------------------------------
    initial begin
        // Clear RTL instruction memory with NOPs
        for (int i = 0; i < IMEM_SIZE_WORDS; i++) begin
            dut.u_rv_mem_wrap.i_mem.mem[i] = 32'h00000013; // NOP
        end

        // Clear Reference model instruction memory with NOPs
        for (int i = 0; i < IMEM_SIZE_WORDS; i++) begin
            u_ref.imem[i] = 32'h00000013; // NOP
        end

        // Load program into RTL
        $display("TB: Loading program into RTL IMEM");
        $readmemh("output_tools/load_mem.sv", dut.u_rv_mem_wrap.i_mem.mem);

        // Load same program into Reference Model
        $display("TB: Loading program into Reference Model IMEM");
        $readmemh("output_tools/load_mem.sv", u_ref.imem);
    end

    //----------------------------------------------------------
    // Trackers
    //----------------------------------------------------------
    `include "verif/rv_cpu/trks/trk_if.vh"
    `include "verif/rv_cpu/trks/trk_decode.vh"
    `include "verif/rv_cpu/trks/trk_exe.vh"
    // Pipeline for Instruction Names to keep trackers synced
    string name_Q101H, name_Q102H, name_Q103H, name_Q104H;

    always @(posedge clk) begin
        if (rst) begin
            name_Q101H <= "NOP";
            name_Q102H <= "NOP";
            name_Q103H <= "NOP";
            name_Q104H <= "NOP";
        end else begin
            name_Q101H <= inst_name; // inst_name is the current decode result
            name_Q102H <= name_Q101H;
            name_Q103H <= name_Q102H;
            name_Q104H <= name_Q103H;
        end
    end
    `include "verif/rv_cpu/trks/trk_mem.vh"
    `include "verif/rv_cpu/trks/trk_wb.vh"
    //----------------------------------------------------------
    // End Simulation
    //----------------------------------------------------------
    initial begin
        #2000;
        if (log_if != 0) $fclose(log_if);
        if (log_id != 0) $fclose(log_id);
        if (log_exe != 0) $fclose(log_exe);
        if (log_mem != 0) $fclose(log_mem);
        if (log_wb != 0) $fclose(log_wb);
        $finish;
    end

endmodule
