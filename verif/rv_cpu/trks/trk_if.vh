//------------------------------------------------------------------------------
// Title      : trk_if
// Description: IF stage tracker
//------------------------------------------------------------------------------
/*
-------------------------------------------------------------------------------------------
       PIPELINE TRACKER COLUMN EXPLANATIONS
-------------------------------------------------------------------------------------------
1. Time       : Simulation time. Correlates log with Waveform.
2. Cycle      : Clock cycle count.
3. PC (IF)    : Program Counter of instruction currently being FETCHED.
4. Opcode     : Opcode of instruction in DECODE stage.
5. Instr (ID) : Raw 32-bit instruction bits in Hex (Decode stage).
6. Instr Name : Human-readable name of instruction in DECODE stage.
7. Result (WB): Data value being written back to Register File (from 4 cycles ago).
8. Status     : Indicates if a Register Write (RegWrite) occurs this cycle.
-------------------------------------------------------------------------------------------
*/

string inst_name;
logic [6:0] opcode;

initial begin
    log_if = $fopen("target/rv_cpu/logs/trk/trk_if.log", "w");
    
    // Header - Adjusted spacing for 7-bit binary Opcode
    $fdisplay(log_if, "==========================================================================================================");
    $fdisplay(log_if, "  Time  | Cycle | PC (IF)  | Opcode (bin) | Instr (ID) |   Instr Name   | Result (WB) | Status    ");
    $fdisplay(log_if, "==========================================================================================================");
end

always @(posedge clk) begin
    if (!rst) begin
        // Extract Opcode from Decode stage
        opcode = dut.instruction_Q101H[6:0];

        // Decode instruction name
        case (opcode)
            7'h33:   inst_name = "R-TYPE";
            7'h13:   inst_name = "I-TYPE";
            7'h03:   inst_name = "LOAD";
            7'h23:   inst_name = "STORE";
            7'h63:   inst_name = "BRANCH";
            7'h6f:   inst_name = "JAL";
            7'h67:   inst_name = "JALR";
            7'h37:   inst_name = "LUI";
            7'h17:   inst_name = "AUIPC";
            7'h73:   inst_name = "SYSTEM";
            default: inst_name = (dut.instruction_Q101H == 32'h00000013) ? "NOP" : "UNKNOWN";
        endcase

        // Structured fdisplay:
        // %7b   : Displays the 7-bit opcode in binary
        $fdisplay(log_if, "%-7t | %5d | %8h |    %7b   | %10h | %-14s |  %8h   | %s",
            $time,
            cycle_count,
            dut.pc_Q100H,
            opcode,             // Displayed as Binary (%7b)
            dut.instruction_Q101H,
            inst_name,
            dut.wb_data_Q104H,
            (dut.wb_ctrl.reg_write_en_Q104H ? "RegWrite" : "        ")
        );

        cycle_count <= cycle_count + 1;
    end
end