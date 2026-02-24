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
    // Instruction Decoder Function - returns mnemonic string
    //----------------------------------------------------------
    function string decode_instr(input logic [31:0] instr);
        logic [6:0] opcode;
        logic [2:0] funct3;
        logic [6:0] funct7;
        logic [4:0] rd, rs1, rs2;
        
        opcode = instr[6:0];
        rd     = instr[11:7];
        funct3 = instr[14:12];
        rs1    = instr[19:15];
        rs2    = instr[24:20];
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
                "C=%3d | PC=0x%03h | %-6s | ALU_in1=%-11d ALU_in2=%-11d ALU_out=%-11d | wb_rd=x%-2d wb_we=%b",
                cycle_count, dut.pc_Q100H[11:0], decode_instr(dut.instruction_Q101H),
                $signed(dut.u_rv_exe.alu_in1_Q102H), $signed(dut.u_rv_exe.alu_in2_Q102H), $signed(dut.alu_out_Q102H),
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
