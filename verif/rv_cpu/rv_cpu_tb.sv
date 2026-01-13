//----------------------------------------------------------
// Title      : rv_cpu_tb
// Project    : RISC-V 5-Stage Pipeline
//----------------------------------------------------------
// Testbench with detailed signal tracing through pipeline
//----------------------------------------------------------

`timescale 1ns/1ps

module rv_cpu_tb;
    import pkg::*;

    //----------------------------------------------------------
    // Parameters
    //----------------------------------------------------------
    parameter CLK_PERIOD = 10;
    parameter IMEM_SIZE  = 32;
    parameter DMEM_SIZE  = 32;

    //----------------------------------------------------------
    // Signals
    //----------------------------------------------------------
    logic        clk;
    logic        rst;
    
    // Instruction Memory Interface
    logic [31:0] imem_addr;
    logic [31:0] imem_rd_data;
    
    // Data Memory Interface
    t_core2mem_req core2dmem_req;
    logic [31:0]   dmem_rd_data;

    // Cycle counter
    int cycle_count;

    //----------------------------------------------------------
    // Clock Generation
    //----------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    //----------------------------------------------------------
    // DUT Instantiation
    //----------------------------------------------------------
    rv_cpu u_dut (
        .clk            (clk),
        .rst            (rst),
        .imem_addr      (imem_addr),
        .imem_rd_data   (imem_rd_data),
        .core2dmem_req  (core2dmem_req),
        .dmem_rd_data   (dmem_rd_data)
    );

    //----------------------------------------------------------
    // Instruction Memory (Simple hardcoded ROM)
    //----------------------------------------------------------
    logic [31:0] imem [0:IMEM_SIZE-1];
    logic [31:0] imem_word_addr;
    
    assign imem_word_addr = imem_addr[31:2];
    assign imem_rd_data = imem[imem_word_addr];

    //----------------------------------------------------------
    // Data Memory (Simple RAM)
    //----------------------------------------------------------
    logic [31:0] dmem [0:DMEM_SIZE-1];
    logic [31:0] dmem_word_addr;
    
    assign dmem_word_addr = core2dmem_req.address[31:2];
    assign dmem_rd_data = dmem[dmem_word_addr];
    
    // Simple word-only write
    always_ff @(posedge clk) begin
        if (core2dmem_req.wr_en) begin
            dmem[dmem_word_addr] <= core2dmem_req.wr_data;
        end
    end

    //----------------------------------------------------------
    // Load Test Program
    //----------------------------------------------------------
    initial begin
        // Clear memories
        for (int i = 0; i < IMEM_SIZE; i++) imem[i] = 32'h00000013; // NOP
        for (int i = 0; i < DMEM_SIZE; i++) dmem[i] = 32'h00000000;
        
        // Test Program:
        // 0x00: ADDI x1, x0, 10      # x1 = 10
        // 0x04: ADDI x2, x0, 20      # x2 = 20  
        // 0x08: ADD  x3, x1, x2      # x3 = 30
        // 0x0C: SUB  x4, x2, x1      # x4 = 10
        // 0x10: SW   x3, 0(x0)       # mem[0] = 30
        // 0x14: LW   x5, 0(x0)       # x5 = 30
        // 0x18: NOP                  # (bubble for load-use)
        // 0x1C: ADDI x6, x5, 5       # x6 = 35
        
        imem[0] = 32'h00A00093;  // ADDI x1, x0, 10
        imem[1] = 32'h01400113;  // ADDI x2, x0, 20
        imem[2] = 32'h002081B3;  // ADD  x3, x1, x2
        imem[3] = 32'h40110233;  // SUB  x4, x2, x1
        imem[4] = 32'h00302023;  // SW   x3, 0(x0)
        imem[5] = 32'h00002283;  // LW   x5, 0(x0)
        imem[6] = 32'h00000013;  // NOP
        imem[7] = 32'h00528313;  // ADDI x6, x5, 5
    end

    //----------------------------------------------------------
    // Helper function to decode opcode to string
    //----------------------------------------------------------
    function string decode_opcode(logic [6:0] opcode);
        case (opcode)
            7'b0110011: return "R-type";
            7'b0010011: return "I-type";
            7'b0000011: return "LOAD  ";
            7'b0100011: return "STORE ";
            7'b1100011: return "BRANCH";
            7'b1101111: return "JAL   ";
            7'b1100111: return "JALR  ";
            7'b0110111: return "LUI   ";
            7'b0010111: return "AUIPC ";
            default:    return "??????";
        endcase
    endfunction

    //----------------------------------------------------------
    // Signal Monitor - Display pipeline state each cycle
    //----------------------------------------------------------
    always @(posedge clk) begin
        if (!rst) begin
            $display("================================================================================");
            $display("CYCLE %0d", cycle_count);
            $display("================================================================================");
            
            // ----- IF Stage (Q100H) -----
            $display("[IF  - Q100H] PC = 0x%08h | NextPC = 0x%08h", 
                u_dut.pc_Q100H,
                u_dut.u_rv_if.next_pc_Q100H);
            
            // ----- ID Stage (Q101H) -----
            $display("[ID  - Q101H] PC = 0x%08h | Instr = 0x%08h | Opcode = %s",
                u_dut.pc_Q101H,
                u_dut.instruction_Q101H,
                decode_opcode(u_dut.instruction_Q101H[6:0]));
            $display("             rs1 = x%0d | rs2 = x%0d | rd = x%0d",
                u_dut.decode_ctrl.reg_src1_Q101H,
                u_dut.decode_ctrl.reg_src2_Q101H,
                u_dut.decode_ctrl.rd_Q101H);
            $display("             RegData1 = %0d | RegData2 = %0d | Imm = %0d",
                u_dut.u_rv_decode.reg_rd_data1_Q101H,
                u_dut.u_rv_decode.reg_rd_data2_Q101H,
                $signed(u_dut.u_rv_decode.imm_Q101H));
            
            // ----- EXE Stage (Q102H) -----
            $display("[EXE - Q102H] PC = 0x%08h | ALU_out = %0d",
                u_dut.pc_Q102H,
                $signed(u_dut.alu_out_Q102H));
            $display("             ALU_in1 = %0d | ALU_in2 = %0d | ALU_op = %0d",
                u_dut.u_rv_exe.alu_in1_Q102H,
                u_dut.u_rv_exe.alu_in2_Q102H,
                u_dut.exe_ctrl.alu_op);
            $display("             reg_data1 = %0d | reg_data2 = %0d | imm = %0d",
                u_dut.reg_data1_Q102H,
                u_dut.reg_data2_Q102H,
                $signed(u_dut.imm_Q102H));
            
            // ----- MA Stage (Q103H) -----
            $display("[MA  - Q103H] ALU_out = %0d | DMEM_addr = 0x%08h",
                u_dut.alu_out_Q103H,
                core2dmem_req.address);
            $display("             dmem_wr_en = %b | dmem_rd_en = %b | wr_data = %0d",
                core2dmem_req.wr_en,
                core2dmem_req.rd_en,
                core2dmem_req.wr_data);
            
            // ----- WB Stage (Q104H) -----
            $display("[WB  - Q104H] wb_data = %0d | rd = x%0d | reg_wr_en = %b",
                u_dut.wb_data_Q104H,
                u_dut.wb_ctrl.reg_dst_Q104H,
                u_dut.wb_ctrl.reg_write_en_Q104H);
            
            $display("");
        end
    end

    //----------------------------------------------------------
    // Test Sequence
    //----------------------------------------------------------
    initial begin
        $display("");
        $display("################################################################################");
        $display("#                     RISC-V CPU Pipeline Testbench                            #");
        $display("################################################################################");
        $display("");
        
        // Initialize
        rst = 1;
        cycle_count = 0;
        
        // Hold reset for 2 cycles
        repeat(2) @(posedge clk);
        rst = 0;
        $display(">>> RESET RELEASED <<<");
        $display("");
        
        // Run for enough cycles to complete all instructions
        repeat(20) begin
            @(posedge clk);
            cycle_count++;
        end
        
        // Final Register File state
        $display("");
        $display("################################################################################");
        $display("#                          FINAL REGISTER FILE STATE                           #");
        $display("################################################################################");
        $display("  x0  = %0d (hardwired zero)", 0);
        $display("  x1  = %0d (expected: 10)", u_dut.u_rv_decode.rf[1]);
        $display("  x2  = %0d (expected: 20)", u_dut.u_rv_decode.rf[2]);
        $display("  x3  = %0d (expected: 30)", u_dut.u_rv_decode.rf[3]);
        $display("  x4  = %0d (expected: 10)", u_dut.u_rv_decode.rf[4]);
        $display("  x5  = %0d (expected: 30)", u_dut.u_rv_decode.rf[5]);
        $display("  x6  = %0d (expected: 35)", u_dut.u_rv_decode.rf[6]);
        
        $display("");
        $display("################################################################################");
        $display("#                          FINAL DATA MEMORY STATE                             #");
        $display("################################################################################");
        $display("  mem[0] = %0d (expected: 30)", dmem[0]);
        
        // Pass/Fail check
        $display("");
        if (u_dut.u_rv_decode.rf[1] == 10 &&
            u_dut.u_rv_decode.rf[2] == 20 &&
            u_dut.u_rv_decode.rf[3] == 30 &&
            u_dut.u_rv_decode.rf[4] == 10 &&
            u_dut.u_rv_decode.rf[5] == 30 &&
            u_dut.u_rv_decode.rf[6] == 35 &&
            dmem[0] == 30) begin
            $display("################################################################################");
            $display("#                             TEST PASSED                                      #");
            $display("################################################################################");
        end else begin
            $display("################################################################################");
            $display("#                             TEST FAILED                                      #");
            $display("################################################################################");
        end
        
        $display("");
        $finish;
    end

endmodule
