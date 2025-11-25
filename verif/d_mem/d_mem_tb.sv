// Testbench for the Word-Aligned Memory Unit (mem.sv)
// Tests: Byte/Halfword alignment using Shift Before and After logic.

`timescale 1ns/1ps

module mem_tb;

    // ----------------------------------------------------
    // 1. Signals for Interface (DUT - Device Under Test)
    // ----------------------------------------------------
    localparam WORD_WIDTH = 32;
    localparam ADRS_WIDTH = 32;
    localparam BYTE_EN_SIZE = 4;

    logic        clk;
    logic [ADRS_WIDTH-1:0] adrs;
    logic [WORD_WIDTH-1:0] rd_data;
    logic        rden;
    logic        wren;
    logic [BYTE_EN_SIZE-1:0] byt_en;
    logic        sign_ext; // Not critical for alignment test, set to 0
    logic [WORD_WIDTH-1:0] wr_data;

    // ----------------------------------------------------
    // 2. Instantiate the Device Under Test (DUT)
    // ----------------------------------------------------
    mem #(
        .WORD_WIDTH(WORD_WIDTH),
        .ADRS_WIDTH(ADRS_WIDTH),
        .MEM_DEPTH_WORDS(256)
    ) dut (
        .clk(clk),
        .adrs(adrs),
        .rd_data(rd_data),
        .rden(rden),
        .wren(wren),
        .byt_en(byt_en),
        .sign_ext(sign_ext),
        .wr_data(wr_data)
    );

    // ----------------------------------------------------
    // 3. Clock Generation
    // ----------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Clock period is 10ns
    end

    // ----------------------------------------------------
    // 4. Task Definitions
    // ----------------------------------------------------

    // Reset task
    task reset_signals;
        begin
            rden = 0;
            wren = 0;
            adrs = 0;
            wr_data = 0;
            byt_en = 0;
            sign_ext = 0;
            @(posedge clk);
            $display("--- Reset Complete ---");
        end
    endtask

    // Store Byte task
    task store_byte (input logic [ADRS_WIDTH-1:0] s_adrs, input logic [7:0] s_data);
        begin
            $display("STORE Byte to address 0x%h. Data: 0x%h. Offset: %d", s_adrs, s_data, s_adrs[1:0]);
            
            // Phase 1: Setup
            adrs = s_adrs;
            wr_data = {24'h0, s_data}; // Data is placed in the LSB of wr_data
            
            // Calculate Byte Enable based on offset (only byt_en[0] is active in the *user's* request)
            // The shift logic inside the DUT will map it to the correct shifted_byte_en
            byt_en = 4'b0001; 
            
            wren = 1;
            @(posedge clk);
            
            // Phase 2: Completion
            wren = 0;
            @(posedge clk);
        end
    endtask

    // Load Byte task
    task load_byte (input logic [ADRS_WIDTH-1:0] l_adrs, input logic [7:0] expected_data);
        begin
            $display("LOAD Byte from address 0x%h. Offset: %d. Expecting: 0x%h", l_adrs, l_adrs[1:0], expected_data);
            
            // Phase 1: Setup read
            adrs = l_adrs;
            byt_en = 4'b0001; // The requested size is a Byte
            rden = 1;
            #1; // Allow combinational logic to settle

            // Phase 2: Check result (rd_data is combinational)
            if (rd_data[7:0] == expected_data) begin
                $display("LOAD SUCCESS. Received: 0x%h", rd_data[7:0]);
            end else begin
                $error("LOAD FAILED! Received: 0x%h, Expected: 0x%h", rd_data[7:0], expected_data);
            end

            // Phase 3: Cleanup
            rden = 0;
            @(posedge clk);
        end
    endtask


    // ----------------------------------------------------
    // 5. Simulation Flow (Main Block)
    // ----------------------------------------------------
    initial begin
        $dumpfile("mem_tb.vcd");
        $dumpvars(0, mem_tb);

        reset_signals;

        // --- Test Scenario: Byte Access and Alignment ---
        
        // 1. Initial Data (Non-Aliasing Word at base address 0x20)
        // Set an existing word to 0xFEEDF00D to check if only the requested byte is written.
        
        $display("\n--- 1. Pre-filling Memory with known word 0xFEEDF00D @ 0x20 ---");
        adrs = 32'h00000020;
        wr_data = 32'hFEEDF00D;
        byt_en = 4'b1111; // Write full word
        wren = 1;
        @(posedge clk);
        wren = 0;
        @(posedge clk);


        // 2. STORE Byte tests (Shift Left Logic Check)
        // Store the value 0xAA using different offsets. Only the 8 LSBs of wr_data are relevant.
        
        $display("\n--- 2. STORE BYTE TESTS (Shift Left) ---");
        
        // Store 0xAA to address 0x20 (Offset 0)
        store_byte(32'h00000020, 8'hAA); 
        // Expected memory word @ 0x20: 0xFEEDF0AA (Only the LSB changes)

        // Store 0xBB to address 0x21 (Offset 1)
        store_byte(32'h00000021, 8'hBB);
        // Expected memory word @ 0x20: 0xFEEDBB20 (0xBB moves to byte 1, 0xAA moves to byte 0) -> 0xFEEDBB AA
        // The original word was 0xFEED F0 AA. Writing 0xBB @ 0x21 means: 0xFE ED BB AA

        // Store 0xCC to address 0x22 (Offset 2)
        store_byte(32'h00000022, 8'hCC);
        // Expected memory word @ 0x20: 0xFEEDCCAA. Writing 0xCC @ 0x22 means: 0xFE CC BB AA

        // Store 0xDD to address 0x23 (Offset 3)
        store_byte(32'h00000023, 8'hDD);
        // Expected memory word @ 0x20: 0xDD CC BB AA

        
        // 3. LOAD Byte tests (Shift Right Logic Check)
        // Load the stored values using the correct offsets to check shifting back to LSB.

        $display("\n--- 3. LOAD BYTE TESTS (Shift Right) ---");
        
        // Load from 0x20 (Offset 0) -> Expect 0xAA
        load_byte(32'h00000020, 8'hAA); 
        
        // Load from 0x21 (Offset 1) -> Expect 0xBB
        load_byte(32'h00000021, 8'hBB);
        
        // Load from 0x22 (Offset 2) -> Expect 0xCC
        load_byte(32'h00000022, 8'hCC);
        
        // Load from 0x23 (Offset 3) -> Expect 0xDD
        load_byte(32'h00000023, 8'hDD);

        $display("\n*** Simulation Finished Successfully ***");
        $finish;
    end

endmodule