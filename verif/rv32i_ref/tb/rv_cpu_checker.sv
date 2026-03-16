//----------------------------------------------------------
// rv_cpu_checker - Compare RTL vs Reference Model
//----------------------------------------------------------
// Free-running DFF samples REF output every cycle (alignment).
// Combinational compare with RTL Q104H.
// Linear code: fully verified. Branch alignment: WIP.
//----------------------------------------------------------

`include "dff_macros.svh"

module rv_cpu_checker
    import rv32i_ref_pkg::*;
(
    input logic clk,
    input logic rst,
    input logic run,

    input t_rf_write_txn   ref_rf_write,
    input t_dmem_write_txn ref_dmem_write,

    input logic        rtl_rf_wr_en,
    input logic [4:0]  rtl_rf_rd,
    input logic [31:0] rtl_rf_wr_data,
    input logic [31:0] rtl_pc_Q102H,

    input logic        rtl_dmem_wr_en,
    input logic [31:0] rtl_dmem_addr,
    input logic [31:0] rtl_dmem_wr_data,
    input logic [3:0]  rtl_dmem_byte_en,

    output logic       check_error,
    output int         rf_write_count,
    output int         rf_error_count,
    output int         dmem_write_count,
    output int         dmem_error_count
);

    // Free-running alignment DFF
    t_rf_write_txn ref_rf_q;
    logic          run_q;
    `DFF(ref_rf_q, ref_rf_write, clk)
    `DFF_RST(run_q, run, clk, rst)

    // Combinational mismatch detect
    logic rf_mismatch;
    always_comb begin
        rf_mismatch = 1'b0;
        if (run_q && run && !rst) begin
            if      (ref_rf_q.valid && rtl_rf_wr_en)  rf_mismatch = (ref_rf_q.rd !== rtl_rf_rd) || (ref_rf_q.data !== rtl_rf_wr_data);
            else if (ref_rf_q.valid && !rtl_rf_wr_en) rf_mismatch = (ref_rf_q.rd != 5'd0);
            else if (!ref_rf_q.valid && rtl_rf_wr_en)  rf_mismatch = (rtl_rf_rd != 5'd0);
        end
    end

    // Error counting and reporting
    int cycle_count;
    always_ff @(posedge clk) begin
        if (rst) begin
            rf_write_count   <= 0;
            rf_error_count   <= 0;
            dmem_write_count <= 0;
            dmem_error_count <= 0;
            check_error      <= 1'b0;
            cycle_count      <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (run_q && run) begin
                if (rtl_rf_wr_en && rtl_rf_rd != 5'd0)
                    rf_write_count <= rf_write_count + 1;
                if (rf_mismatch) begin
                    rf_error_count <= rf_error_count + 1;
                    check_error    <= 1'b1;
                    $display("ERROR [RF] @%0t (C=%0d) pc=0x%08h %s: REF x%0d=0x%08h  RTL x%0d=0x%08h",
                        $time, cycle_count, ref_rf_q.pc, ref_rf_q.instr_type.name(),
                        ref_rf_q.rd, ref_rf_q.data, rtl_rf_rd, rtl_rf_wr_data);
                end
            end
        end
    end

endmodule
