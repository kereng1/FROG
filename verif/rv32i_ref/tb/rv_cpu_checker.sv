//----------------------------------------------------------
// rv_cpu_checker - Compare RTL vs Reference Model
//----------------------------------------------------------
// Records all RF writes (pc, rd, data) from REF and RTL in arrays.
// Stops recording when ebreak_detected; anything after ebreak is ignored.
// At end of test (do_final_compare=1) compares the two arrays (pc + rd + data).
// No live alignment: if RTL is correct, arrays match.
//----------------------------------------------------------

`include "dff_macros.svh"

module rv_cpu_checker
    import rv32i_ref_pkg::*;
#(
    parameter int MAX_RF_WRITES = 16384,
    parameter int MAX_DUMP_MISMATCHES = 25
)(
    input logic clk,
    input logic rst,
    input logic run,
    input logic do_final_compare,
    input logic ebreak_detected,   // stop recording once ebreak is seen (REF or EOT)

    input t_rf_write_txn   ref_rf_write,
    input t_dmem_write_txn ref_dmem_write,

    input logic        rtl_rf_wr_en,
    input logic [4:0]  rtl_rf_rd,
    input logic [31:0] rtl_rf_wr_data,
    input logic [31:0] rtl_pc_Q104H,

    input logic        rtl_dmem_wr_en,
    input logic [31:0] rtl_dmem_addr,
    input logic [31:0] rtl_dmem_wr_data,
    input logic [3:0]  rtl_dmem_byte_en,

    output logic       check_error,
    output int         rf_write_count,
    output int         rf_error_count,
    output int         dmem_write_count,
    output int         dmem_error_count,

    output int         final_ref_count,
    output int         final_rtl_count,
    output int         final_rf_error_count
);

    //----------------------------------------------------------
    // Capture arrays (pc, rd, data for each RF write)
    //----------------------------------------------------------
    logic [31:0] ref_pc   [0:MAX_RF_WRITES-1];
    logic [4:0]  ref_rd   [0:MAX_RF_WRITES-1];
    logic [31:0] ref_data [0:MAX_RF_WRITES-1];
    logic [31:0] rtl_pc   [0:MAX_RF_WRITES-1];
    logic [4:0]  rtl_rd   [0:MAX_RF_WRITES-1];
    logic [31:0] rtl_data [0:MAX_RF_WRITES-1];

    int ref_count;
    int rtl_count;

    // Stop recording once ebreak is detected (latch so we never capture after)
    logic ebreak_seen;
    logic next_ebreak_seen;
    assign next_ebreak_seen = ebreak_seen || ebreak_detected;
    `DFF_RST(ebreak_seen, next_ebreak_seen, clk, rst)

    // Next state for counts (combinational)
    int next_ref_count;
    int next_rtl_count;
    logic ref_capture_en;
    logic rtl_capture_en;
    logic stop_capture;  // high from the cycle ebreak is detected (no further captures)
    assign stop_capture = ebreak_seen || ebreak_detected;
    assign ref_capture_en = !rst && !stop_capture && ref_rf_write.valid;   // stop at ebreak
    assign rtl_capture_en = !rst && !stop_capture && rtl_rf_wr_en;         // stop at ebreak
    assign next_ref_count = ref_count + (ref_capture_en ? 1 : 0);
    assign next_rtl_count = rtl_count + (rtl_capture_en ? 1 : 0);

    `DFF_RST_VAL(ref_count, next_ref_count, clk, rst, 0)
    `DFF_RST_VAL(rtl_count, next_rtl_count, clk, rst, 0)

    // Next-state for capture arrays (combinational)
    logic [31:0] next_ref_pc   [0:MAX_RF_WRITES-1];
    logic [4:0]  next_ref_rd   [0:MAX_RF_WRITES-1];
    logic [31:0] next_ref_data [0:MAX_RF_WRITES-1];
    logic [31:0] next_rtl_pc   [0:MAX_RF_WRITES-1];
    logic [4:0]  next_rtl_rd   [0:MAX_RF_WRITES-1];
    logic [31:0] next_rtl_data [0:MAX_RF_WRITES-1];

    always_comb begin
        for (int i = 0; i < MAX_RF_WRITES; i++) begin
            next_ref_pc[i]   = (ref_capture_en && i == ref_count)   ? ref_rf_write.pc     : ref_pc[i];
            next_ref_rd[i]   = (ref_capture_en && i == ref_count)   ? ref_rf_write.rd     : ref_rd[i];
            next_ref_data[i] = (ref_capture_en && i == ref_count)   ? ref_rf_write.data   : ref_data[i];
            next_rtl_pc[i]   = (rtl_capture_en && i == rtl_count)   ? rtl_pc_Q104H        : rtl_pc[i];
            next_rtl_rd[i]   = (rtl_capture_en && i == rtl_count)   ? rtl_rf_rd           : rtl_rd[i];
            next_rtl_data[i] = (rtl_capture_en && i == rtl_count)   ? rtl_rf_wr_data     : rtl_data[i];
        end
    end

    `DFF_MEM(ref_pc,   next_ref_pc,   clk, 1'b1)
    `DFF_MEM(ref_rd,   next_ref_rd,   clk, 1'b1)
    `DFF_MEM(ref_data, next_ref_data, clk, 1'b1)
    `DFF_MEM(rtl_pc,   next_rtl_pc,   clk, 1'b1)
    `DFF_MEM(rtl_rd,   next_rtl_rd,   clk, 1'b1)
    `DFF_MEM(rtl_data, next_rtl_data, clk, 1'b1)

    //----------------------------------------------------------
    // Final comparison when do_final_compare is asserted
    //----------------------------------------------------------
    int compare_errors;
    always_comb begin
        compare_errors = 0;
        if (do_final_compare) begin
            for (int i = 0; i < ref_count && i < rtl_count; i++)
                if (ref_pc[i] !== rtl_pc[i] || ref_rd[i] !== rtl_rd[i] || ref_data[i] !== rtl_data[i])
                    compare_errors++;
            if (ref_count != rtl_count)
                compare_errors += (ref_count > rtl_count) ? (ref_count - rtl_count) : (rtl_count - ref_count);
        end
    end

    assign final_ref_count    = ref_count;
    assign final_rtl_count    = rtl_count;
    assign final_rf_error_count = compare_errors;

    // One-shot dump of first N mismatches at EOT (verification only)
    logic dumped;
    always_ff @(posedge clk) begin
        if (rst)
            dumped <= 1'b0;
        else if (do_final_compare && !dumped) begin
            dumped <= 1'b1;
            begin
                automatic int dc = 0;
                automatic int max_i = (ref_count > rtl_count) ? ref_count : rtl_count;
                $display("  --- First 3 entries (REF vs RTL) ---");
                for (int i = 0; i < 3 && i < ref_count && i < rtl_count; i++)
                    $display("  [%0d] REF pc=0x%08h x%0d=0x%08h   RTL pc=0x%08h x%0d=0x%08h  %s",
                        i, ref_pc[i], ref_rd[i], ref_data[i], rtl_pc[i], rtl_rd[i], rtl_data[i],
                        (ref_pc[i]==rtl_pc[i]&&ref_rd[i]==rtl_rd[i]&&ref_data[i]==rtl_data[i]) ? "OK" : "MISMATCH");
                $display("  --- RF write mismatch dump (first %0d) ---", MAX_DUMP_MISMATCHES);
                dc = 0;
                for (int i = 0; i < max_i && dc < MAX_DUMP_MISMATCHES; i++)
                    if (i >= ref_count || i >= rtl_count || ref_pc[i] !== rtl_pc[i] || ref_rd[i] !== rtl_rd[i] || ref_data[i] !== rtl_data[i]) begin
                        if (i >= ref_count)
                            $display("  [%0d] REF (none)                    RTL pc=0x%08h x%0d=0x%08h  (RTL extra)", i, rtl_pc[i], rtl_rd[i], rtl_data[i]);
                        else if (i >= rtl_count)
                            $display("  [%0d] REF pc=0x%08h x%0d=0x%08h  RTL (none)  (REF extra)", i, ref_pc[i], ref_rd[i], ref_data[i]);
                        else
                            $display("  [%0d] REF pc=0x%08h x%0d=0x%08h   RTL pc=0x%08h x%0d=0x%08h", i, ref_pc[i], ref_rd[i], ref_data[i], rtl_pc[i], rtl_rd[i], rtl_data[i]);
                        dc++;
                    end
                if (ref_count != rtl_count)
                    $display("  (length mismatch: REF=%0d  RTL=%0d; %0d extra from %s)",
                        ref_count, rtl_count,
                        (ref_count > rtl_count) ? ref_count - rtl_count : rtl_count - ref_count,
                        (ref_count > rtl_count) ? "REF" : "RTL");
                $display("  --- end mismatch dump ---");
            end
        end
    end

    // Legacy outputs for TB summary (use final counts at eot)
    assign rf_write_count   = rtl_count;
    assign rf_error_count   = final_rf_error_count;
    assign dmem_write_count = 0;
    assign dmem_error_count = 0;
    assign check_error      = do_final_compare && (final_rf_error_count != 0);

endmodule
