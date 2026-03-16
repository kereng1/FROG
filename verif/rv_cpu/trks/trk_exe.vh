//------------------------------------------------------------------------------
// Title      : trk_exe
// Description: Monitors the ALU operations, MUX selections, and Forwarding logic.
//------------------------------------------------------------------------------

/*
-------------------------------------------------------------------------------------------
       EXE STAGE TRACKER COLUMN EXPLANATIONS
-------------------------------------------------------------------------------------------
1. Cycle      : Clock cycle count.
2. Instruction: Human-readable name of the instruction being executed (e.g., ADD, SUB).
3. ALU Op     : The specific operation performed by the ALU hardware.
4. ALU In 1/2 : The FINAL values entering the ALU operands (after MUXes and Forwarding).
5. ALU Result : The calculated output of the ALU operation.
6. Fwd (1|2)  : Forwarding Status for rs1 and rs2:
                - REG: Data from Register File.
                - 103: Data forwarded from MEM stage (Q103H).
                - 104: Data forwarded from WB stage (Q104H).
7. Src (1|2)  : ALU Input MUX Selection:
                - In 1: [REG] data vs [PC] address.
                - In 2: [REG] data vs [IMM] immediate value.
8. BrMet      : Branch Condition Met (1 = Branch taken, 0 = Not taken).
-------------------------------------------------------------------------------------------
*/

string alu_op_str;
string fwd1_str, fwd2_str;
string src1_str, src2_str;

initial begin
    log_exe = $fopen("target/rv_cpu/logs/trk/trk_exe.log", "w");
    if (log_exe == 0) $display("ERROR: Could not open trk_exe.log");

    $fdisplay(log_exe, "================================================================================================================================================");
    $fdisplay(log_exe, " Cycle |  Instruction |  ALU Op  |   ALU In 1   |   ALU In 2   |  ALU Result  | Fwd (1|2) | Src (1|2) | BrMet");
    $fdisplay(log_exe, "================================================================================================================================================");
end

always @(posedge clk) begin
    if (!rst && log_exe != 0) begin
        // 1. Map ALU Op to String
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

        // 2. Map Forwarding MUX Status
        fwd1_str = (dut.u_rv_exe.hazard_reg1_Q102H_Q103H) ? "103" : 
                   (dut.u_rv_exe.hazard_reg1_Q102H_Q104H) ? "104" : "REG";
        fwd2_str = (dut.u_rv_exe.hazard_reg2_Q102H_Q103H) ? "103" : 
                   (dut.u_rv_exe.hazard_reg2_Q102H_Q104H) ? "104" : "REG";

        // 3. Map Input Source MUX Status
        src1_str = (dut.u_rv_exe.ctrl.sel_alu_in1_Q102H == SEL_PC)       ? "PC " : "REG";
        src2_str = (dut.u_rv_exe.ctrl.sel_alu_in2_Q102H == SEL_IMM)      ? "IMM" : "REG";

        // Print aligned data using inst_name instead of PC
        $fdisplay(log_exe, " %5d | %-12s |   %s   |   %h   |   %h   |   %h   |  %s|%s  |  %s|%s  |  %b",
            cycle_count,
            inst_name,      // Human readable instruction name (decoded in trk_if)
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