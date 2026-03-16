//----------------------------------------------------------
// Title      : rv_cpu_checker
// Project    : RISC-V Reference Model Checker
//----------------------------------------------------------
// Description:
// Compares RTL CPU outputs against reference model.
// Delays reference model transactions to match pipeline timing:
//   - RF writes:   Reference cycle N -> RTL cycle N+4 (Q104H)
//   - DMEM writes: Reference cycle N -> RTL cycle N+3 (Q103H)
// 
// Includes warm-up period to allow delay queues to fill.
//----------------------------------------------------------

`include "dff_macros.svh"

module rv_cpu_checker
    import rv32i_ref_pkg::*;
#(
    parameter RF_DELAY_CYCLES   = 4,  // Pipeline delay for RF writes
    parameter DMEM_DELAY_CYCLES = 3   // Pipeline delay for DMEM writes
)
(
    input logic clk,
    input logic rst,
    input logic run,

    // Reference model transactions (immediate)
    input t_rf_write_txn   ref_rf_write,
    input t_dmem_write_txn ref_dmem_write,

    // RTL signals - Register File Write (Q104H)
    input logic        rtl_rf_wr_en,
    input logic [4:0]  rtl_rf_rd,
    input logic [31:0] rtl_rf_wr_data,
    // Best-effort RTL PC context (not perfectly aligned to WB, but useful for debug)
    input logic [31:0] rtl_pc_Q102H,

    // RTL signals - DMEM Write (Q103H)
    input logic        rtl_dmem_wr_en,
    input logic [31:0] rtl_dmem_addr,
    input logic [31:0] rtl_dmem_wr_data,
    input logic [3:0]  rtl_dmem_byte_en,

    // Status outputs
    output logic       check_error,
    output int         rf_write_count,
    output int         rf_error_count,
    output int         dmem_write_count,
    output int         dmem_error_count
);

    //=======================================================
    // Warm-up Counters
    //=======================================================
    int warmup_counter;
    logic rf_warmup_done;
    logic dmem_warmup_done;

    // Extra warmup avoids false mismatches during pipeline fill (REF txn delay chain not yet populated)
    localparam int WARMUP_CYCLES = ((RF_DELAY_CYCLES > DMEM_DELAY_CYCLES) ? RF_DELAY_CYCLES : DMEM_DELAY_CYCLES) + 2;
    assign rf_warmup_done   = (warmup_counter >= WARMUP_CYCLES);
    assign dmem_warmup_done = (warmup_counter >= WARMUP_CYCLES);

    always_ff @(posedge clk) begin
        if (rst) begin
            warmup_counter <= 0;
        end else if (run && warmup_counter < WARMUP_CYCLES) begin
            warmup_counter <= warmup_counter + 1;
        end
    end

    //=======================================================
    // Pipeline Delay Shift Registers
    //=======================================================
    // RF writes: delay by 4 cycles (Q100H -> Q104H)
    t_rf_write_txn rf_delay [0:RF_DELAY_CYCLES-1];
    
    // DMEM writes: delay by 3 cycles (Q100H -> Q103H)  
    t_dmem_write_txn dmem_delay [0:DMEM_DELAY_CYCLES-1];

    // Delayed transactions for comparison
    t_rf_write_txn   delayed_rf_write;
    t_dmem_write_txn delayed_dmem_write;

    //=======================================================
    // Delay Shift Registers
    //=======================================================
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < RF_DELAY_CYCLES; i++) rf_delay[i] <= '0;
            for (int i = 0; i < DMEM_DELAY_CYCLES; i++) dmem_delay[i] <= '0;
        end else if (run) begin
            // RF delay chain (4 cycles)
            rf_delay[0] <= ref_rf_write;
            for (int i = 1; i < RF_DELAY_CYCLES; i++) begin
                rf_delay[i] <= rf_delay[i-1];
            end

            // DMEM delay chain (3 cycles)
            dmem_delay[0] <= ref_dmem_write;
            for (int i = 1; i < DMEM_DELAY_CYCLES; i++) begin
                dmem_delay[i] <= dmem_delay[i-1];
            end
        end
    end

    assign delayed_rf_write   = rf_delay[RF_DELAY_CYCLES-1];
    assign delayed_dmem_write = dmem_delay[DMEM_DELAY_CYCLES-1];

    //=======================================================
    // Comparison Logic
    //=======================================================
    logic rf_mismatch;
    logic dmem_mismatch;

    // RF write comparison (only after warm-up)
    always_comb begin
        rf_mismatch = 1'b0;
        
        if (rf_warmup_done && run && !rst) begin
            if ((delayed_rf_write.valid === 1'b1) && (rtl_rf_wr_en === 1'b1)) begin
                // Both should write - compare data
                if (delayed_rf_write.rd !== rtl_rf_rd) begin
                    rf_mismatch = 1'b1;
                end else if (delayed_rf_write.data !== rtl_rf_wr_data) begin
                    rf_mismatch = 1'b1;
                end
            end else if ((delayed_rf_write.valid === 1'b1) && (rtl_rf_wr_en === 1'b0)) begin
                // Reference writes but RTL doesn't - mismatch
                // Ignore x0 writes
                if (delayed_rf_write.rd != 5'd0) begin
                    rf_mismatch = 1'b1;
                end
            end else if ((delayed_rf_write.valid === 1'b0) && (rtl_rf_wr_en === 1'b1)) begin
                // RTL writes but reference doesn't - mismatch
                // Ignore x0 writes
                if (rtl_rf_rd != 5'd0) begin
                    rf_mismatch = 1'b1;
                end
            end
        end
    end

    // DMEM write comparison (only after warm-up)
    always_comb begin
        dmem_mismatch = 1'b0;
        
        if (dmem_warmup_done && run && !rst) begin
            if (delayed_dmem_write.valid && rtl_dmem_wr_en) begin
                // Both should write - compare
                if (delayed_dmem_write.addr != rtl_dmem_addr) begin
                    dmem_mismatch = 1'b1;
                end else if (delayed_dmem_write.byte_en != rtl_dmem_byte_en) begin
                    dmem_mismatch = 1'b1;
                end else begin
                    // Compare only enabled bytes
                    for (int i = 0; i < 4; i++) begin
                        if (delayed_dmem_write.byte_en[i]) begin
                            if (delayed_dmem_write.data[i*8 +: 8] != rtl_dmem_wr_data[i*8 +: 8]) begin
                                dmem_mismatch = 1'b1;
                            end
                        end
                    end
                end
            end else if (delayed_dmem_write.valid != rtl_dmem_wr_en) begin
                dmem_mismatch = 1'b1;
            end
        end
    end

    //=======================================================
    // Error Reporting
    //=======================================================
    int cycle_count;
    always_ff @(posedge clk) begin
        if (rst) begin
            rf_write_count   <= 0;
            rf_error_count   <= 0;
            dmem_write_count <= 0;
            dmem_error_count <= 0;
            check_error      <= 1'b0;
            cycle_count      <= 0;
        end else if (run) begin
            cycle_count <= cycle_count + 1;
            // RF write tracking (only after warm-up)
            if (rf_warmup_done && rtl_rf_wr_en && rtl_rf_rd != 5'd0) begin
                rf_write_count <= rf_write_count + 1;
            end
            
            if (rf_mismatch) begin
                rf_error_count <= rf_error_count + 1;
                check_error    <= 1'b1;
                $display("ERROR [RF] @%0t (C=%0d):", $time, cycle_count);
                $display("  REF: valid=%b pc=0x%08h instr=%s rd=x%0d data=0x%08h (%0d)",
                    delayed_rf_write.valid, delayed_rf_write.pc, delayed_rf_write.instr_type.name(),
                    delayed_rf_write.rd, delayed_rf_write.data, $signed(delayed_rf_write.data));
                $display("  RTL: valid=%b pc_Q102H=0x%08h rd=x%0d data=0x%08h (%0d)",
                    rtl_rf_wr_en, rtl_pc_Q102H, rtl_rf_rd, rtl_rf_wr_data, $signed(rtl_rf_wr_data));
            end

            // DMEM write tracking (only after warm-up)
            if (dmem_warmup_done && rtl_dmem_wr_en) begin
                dmem_write_count <= dmem_write_count + 1;
            end

            if (dmem_mismatch) begin
                dmem_error_count <= dmem_error_count + 1;
                check_error      <= 1'b1;
                $display("ERROR [DMEM] @%0t: PC=0x%08h Instr=%s",
                    $time, delayed_dmem_write.pc, delayed_dmem_write.instr_type.name());
                $display("  REF: addr=0x%08h data=0x%08h byte_en=%b",
                    delayed_dmem_write.addr, delayed_dmem_write.data, delayed_dmem_write.byte_en);
                $display("  RTL: addr=0x%08h data=0x%08h byte_en=%b (wr_en=%b)",
                    rtl_dmem_addr, rtl_dmem_wr_data, rtl_dmem_byte_en, rtl_dmem_wr_en);
            end
        end
    end

endmodule
