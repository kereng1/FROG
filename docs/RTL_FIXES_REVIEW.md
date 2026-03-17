# RTL Fixes for Correct Behaviour (RF Write Match vs Reference)

## Summary

The RTL commits **5 extra** register-file writes vs the reference (57 vs 52): **1 duplicate** of the first instruction’s write and **4** commits that should have been flushed (post-branch/jump or end-of-program). Two root causes were found; fixes are below.

---

## Fix 1: Gate WB register write by `valid` (safety net)

**File:** `source/cpu/rv_ctrl.sv`  
**Location:** WB control outputs (~lines 377–382)

**Issue:** Bubbles (flushed instructions) and any invalid control still drive `reg_write_en_Q104H` and `reg_dst_Q104H`. If a bubble ever carries stale control, or `valid` is wrong, the RTL can do an RF write when it should not.

**Change:** Gate the WB register-write by `ctrl_Q104H.valid`:

```systemverilog
// Before:
assign wb_ctrl.reg_write_en_Q104H  = ctrl_Q104H.reg_write_en;
assign wb_ctrl.reg_dst_Q104H       = ctrl_Q104H.rd;

// After:
assign wb_ctrl.reg_write_en_Q104H  = ctrl_Q104H.reg_write_en && ctrl_Q104H.valid;
assign wb_ctrl.reg_dst_Q104H       = ctrl_Q104H.rd;  // unchanged (don't write when !valid anyway)
```

So any slot that is not a valid retirement (e.g. bubble) never writes the RF. This fixes the **four extra commits** if they come from bubbles that still had `reg_write_en` set, and prevents future bugs from invalid control reaching WB.

**Status:** This change is **already applied** in `source/cpu/rv_ctrl.sv`.

---

## Fix 2: Remove duplicate first instruction (instruction memory read latency)

**File:** `source/common/rv_mem.sv` and/or `source/cpu/rv_mem_wrap.sv`

**Issue:** In `rv_mem`, the read data is **registered**:

```systemverilog
`DFF(rd_data, pre_rd_data, clk)
```

So there is **one cycle of read latency**. The CPU uses `instruction_Q101H = i_mem.rd_data` (the registered output). As a result:

- Cycle 0 (first after reset): `pc_Q100H = 0`, memory is addressed 0; `rd_data` still holds the value from the previous cycle (instr at 0 from reset).
- Cycle 1: PC advances to 4, but `rd_data` still shows the instruction at 0 until the next posedge.

So the **same instruction (at 0)** is decoded for **two consecutive cycles** and two copies enter the pipeline → the first instruction retires twice → **duplicate first RF write**.

**Options (pick one):**

### Option A – Combinatorial instruction read (recommended for IMEM)

Use combinatorial read for the **instruction** port only, so the instruction is valid in the same cycle as the address:

- Add a **second read port** to `rv_mem` that is purely combinatorial (e.g. `rd_data_comb` from `pre_rd_data`), or
- In `rv_mem_wrap`, instantiate a small IMEM that uses only combinatorial read (e.g. `assign instruction_Q101H = pre_rd_data` and do not register it), or
- Add a parameter to `rv_mem` to choose registered vs combinatorial read and use combinatorial for the instruction-memory instance.

Then drive `instruction_Q101H` from that combinatorial path so decode sees the instruction for the **current** `pc_Q100H` in the same cycle. That removes the duplicate first instruction.

### Option B – Align pipeline with 1-cycle IMEM latency

Keep the registered read and treat IMEM as 1-cycle latency:

- Do **not** advance PC until the corresponding instruction has been received (e.g. hold PC for one cycle after reset so the first request is 0 and the first **used** instruction is the one returned for 0).
- Feed decode with a **registered** instruction that updates only when the pipeline is allowed to advance (e.g. when `ready_Q101H`), so each instruction is used exactly once.

Option B requires careful handling of the first cycle(s) and possible extra bubbles; Option A is simpler for a single-cycle pipeline that expects “instruction in same cycle as PC”.

---

## Fix 3 (optional): Ensure `valid` is driven for SYSTEM/EBREAK

**File:** `source/cpu/rv_ctrl.sv`  
**Location:** SYSTEM opcode case (~277–281)

**Issue:** ECALL/EBREAK are implemented as NOPs; `ctrl_Q101H` keeps defaults (`valid = 1'b1`, `reg_write_en = 1'b0`). So they retire as “valid” but don’t write. If the reference or environment expects ebreak to stop before extra retirements, consider setting `ctrl_Q101H.valid = 1'b0` for SYSTEM so they don’t count as valid retirements, or keep as-is if the reference and testbench already agree.

---

## Order of application

1. **Fix 1** (gate WB by `valid`) – do first; low risk and prevents invalid commits.
2. **Fix 2** (IMEM read latency / duplicate first instruction) – required to remove the duplicate first RF write and align with the reference.
3. **Fix 3** – only if you need to match a specific ebreak/ecall retirement policy.

After Fix 1 and Fix 2, the RTL should match the reference (same count and same rd/data sequence) for the current test program.

---

## Verification: x0 writes count as retirements

**Files:** `verif/rv32i_ref/tb/rv32i_ref.sv`, `verif/rv32i_ref/tb/rv_cpu_checker.sv`

Instructions that write to **x0** are real instructions: they retire and are committed; they simply do not change the RF (x0 is hardwired zero). Both REF and RTL now **count** them in the write stream so retirement counts align.

- **REF:** `rf_write_txn.valid = reg_wr_en && run && !rst` (no `rd != 0` filter). REF still does not update `regfile[0]`; it only reports (rd, data) for the checker.
- **Checker:** Captures every `ref_rf_write.valid` and every `rtl_rf_wr_en` (including rd=0). End-of-test comparison is still (rd, data); x0 entries are (0, data) and must match on both sides.

So “RF write” in the summary means “retirement that has a register write”, including writes to x0.
