//------------------------------------------------------------------------------
// Title      : trk_exe
// Description: Monitors the ALU operations, MUX selections, and Forwarding logic.
//------------------------------------------------------------------------------

/*
-------------------------------------------------------------------------------------------
       EXE STAGE TRACKER COLUMN EXPLANATIONS
-------------------------------------------------------------------------------------------
1. Cycle      : Clock cycle count.
qa2. PC (EXE)   : Program Counter of the instruction currently in EXE stage (Q102H).
3. Instruction: Human-readable name of the instruction being executed (e.g., ADD, SUB).
4. ALU Op     : The specific operation performed by the ALU hardware.
5. ALU In 1/2 : The FINAL values entering the ALU operands (after MUXes and Forwarding).
6. ALU Result : The calculated output of the ALU operation.
7. Fwd (1|2)  : Forwarding Status for rs1 and rs2:
                - REG: Data from Register File.
                - 103: Data forwarded from MEM stage (Q103H).
                - 104: Data forwarded from WB stage (Q104H).
8. Src (1|2)  : ALU Input MUX Selection:
                - In 1: [REG] data vs [PC] address.
                - In 2: [REG] data vs [IMM] immediate value.
9. BrMet      : Branch Condition Met (1 = Branch taken, 0 = Not taken).
-------------------------------------------------------------------------------------------
*/

string alu_op_str;
string fwd1_str, fwd2_str;
string src1_str, src2_str;
string inst_name_exe;  // Instruction name decoded from EXE stage control signals

initial begin
    log_exe = $fopen("target/rv_cpu/logs/trk/trk_exe.log", "w");
    if (log_exe == 0) $display("ERROR: Could not open trk_exe.log");

    $fdisplay(log_exe, "==========================================================================================================================================================================");
    $fdisplay(log_exe, " Cycle |  PC (EXE)  |  Instruction |  ALU Op  |   ALU In 1   |   ALU In 2   |  ALU Result  | Fwd (1|2) | Src (1|2) | BrMet");
    $fdisplay(log_exe, "==========================================================================================================================================================================");
end

always @(posedge clk) begin
    if (!rst && log_exe != 0) begin
        // 1. Decode instruction type from EXE stage control signals (not from DECODE stage)
        // This ensures we show the instruction actually being executed, not the one being decoded
        if (dut.u_rv_exe.ctrl.branch_cond_op == BRANCH_COND_ALWAYS) begin
            // JAL or JALR (unconditional jump)
            if (dut.u_rv_exe.ctrl.sel_alu_in1_Q102H == SEL_PC) begin
                inst_name_exe = "JAL";
            end else begin
                inst_name_exe = "JALR";
            end
        end else if (dut.u_rv_exe.ctrl.branch_cond_op != BRANCH_COND_NONE) begin
            // Conditional branch (BEQ, BNE, BLT, BGE, BLTU, BGEU)
            inst_name_exe = "BRANCH";
        end else if (dut.u_rv_exe.ctrl.sel_alu_in2_Q102H == SEL_IMM && 
                     dut.u_rv_exe.ctrl.sel_alu_in1_Q102H == SEL_REG_DATA1) begin
            // I-type instruction (ADDI, SLTI, XORI, ORI, ANDI, SLLI, SRLI, SRAI)
            inst_name_exe = "I-TYPE";
        end else if (dut.u_rv_exe.ctrl.sel_alu_in2_Q102H == SEL_REG_DATA2 && 
                     dut.u_rv_exe.ctrl.sel_alu_in1_Q102H == SEL_REG_DATA1) begin
            // R-type instruction (ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND)
            inst_name_exe = "R-TYPE";
        end else if (dut.u_rv_exe.ctrl.sel_alu_in1_Q102H == SEL_PC && 
                     dut.u_rv_exe.ctrl.sel_alu_in2_Q102H == SEL_IMM) begin
            // AUIPC (PC + immediate)
            inst_name_exe = "AUIPC";
        end else if (dut.u_rv_exe.ctrl.sel_alu_in2_Q102H == SEL_IMM && 
                     dut.u_rv_exe.ctrl.alu_op == ALU_PASS_B) begin
            // LUI (load upper immediate)
            inst_name_exe = "LUI";
        end else begin
            // Default or unknown
            inst_name_exe = "UNKNOWN";
        end

        // 2. Map ALU Op to String
        case (dut.u_rv_exe.ctrl.alu_op)
            ALU_ADD:  alu_op_str = "ADD ";
            ALU_SUB:  alu_op_str = "SUB ";
            ALU_AND:  alu_op_str = "AND ";
            ALU_OR:   alu_op_str = "OR  ";
            ALU_XOR:  alu_op_str = "XOR ";
            ALU_SLT:  alu_op_str = "SLT ";
            ALU_SLTU: alu_op_str = "SLTU";
            ALU_SLL:  alu_op_str = "SLL ";
            ALU_SRL:  alu_op_str = "SRL ";
            ALU_SRA:  alu_op_str = "SRA ";
            default:  alu_op_str = "UNKN";
        endcase

        // 3. Map Forwarding MUX Status
        fwd1_str = (dut.u_rv_exe.hazard_reg1_Q102H_Q103H) ? "103" : 
                   (dut.u_rv_exe.hazard_reg1_Q102H_Q104H) ? "104" : "REG";
        fwd2_str = (dut.u_rv_exe.hazard_reg2_Q102H_Q103H) ? "103" : 
                   (dut.u_rv_exe.hazard_reg2_Q102H_Q104H) ? "104" : "REG";

        // 4. Map Input Source MUX Status
        src1_str = (dut.u_rv_exe.ctrl.sel_alu_in1_Q102H == SEL_PC)       ? "PC " : "REG";
        src2_str = (dut.u_rv_exe.ctrl.sel_alu_in2_Q102H == SEL_IMM)      ? "IMM" : "REG";

        // Print aligned data using inst_name_exe (decoded from EXE stage, not DECODE stage)
        $fdisplay(log_exe, " %5d |  %8h  | %-12s |   %s   |   %h   |   %h   |   %h   |  %s|%s  |  %s|%s  |  %b",
            cycle_count,
            dut.pc_Q102H,  // PC of instruction in EXE stage (Q102H)
            inst_name_exe,  // Instruction name decoded from EXE stage control signals (correct timing)
            alu_op_str,
            dut.u_rv_exe.alu_in1_Q102H,
            dut.u_rv_exe.alu_in2_Q102H,
            dut.u_rv_exe.alu_out_Q102H,
            fwd1_str, fwd2_str,
            src1_str, src2_str,
            dut.u_rv_exe.branch_cond_met_Q102H
        );
    end
end