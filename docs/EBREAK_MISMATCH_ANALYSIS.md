# Ebreak Mismatch Analysis: RTL vs Reference

## Summary

**Verdict: RTL bug.** The RTL is producing **duplicate register-file retirements** (the same instruction’s write is effectively retired more than once). The reference model’s control flow and RF write stream match the assembly; the RTL stream is the same at the start but then shifts and ends with 4 extra writes.

---

## Test Program (from `verif/rv_cpu/input.asm`)

- **0x00–0x24**: I-type ALU (addi, slti, xori, ori, andi, …).
- **0x38–0x8C**: Branches not taken (beq, bne), then Test 7 setup (addi x1=5, x2=10).
- **0x98**: `beq x1, x1, beq_target` (taken).
- **0x9C**: `addi x3, x0, 99` — **skipped** (branch taken).
- **0xA0**: `addi x3, x0, 3` — branch target; **writes x3 = 3**.
- **0xA4**: `bne x1, x2, bne_target` (taken).
- **0xA8**: `addi x4, x0, 99` — **skipped**.
- **0xAC**: `addi x4, x0, 4` — branch target; **writes x4 = 4**.
- Then blt/bge/bltu/bgeu taken branches, JAL, JALR, NOPs, loop (x20 0→5), ebreak.

So by the time we pass the first few taken branches:

- Correct sequence of **writes** includes exactly one for **0xA0** (x3=3) and one for **0xAC** (x4=4).

---

## What the Mismatch Dump Shows

- **Index 34**
  - **REF:** pc=**0xAC**, x4=4  → addi x4, x0, 4 (correct).
  - **RTL:**  pc=**0xA0**, x3=3  → addi x3, x0, 3 (correct for 0xA0, but wrong *position*).

So at the **35th** write:

- REF’s 35th write is from **0xAC** (x4=4).
- RTL’s 35th write is from **0xA0** (x3=3).

So RTL’s 35th write is the instruction that REF already retired as its **34th** write. That implies the RTL has **one extra write** somewhere in the first 34 retirements.

- **Index 35–36:** REF has 0xB8 then 0xC4; RTL has **0xAC** then **0xAC** again → RTL retires **0xAC** twice.
- **Index 37–38:** RTL shows **0xB8** twice → duplicate retirement for 0xB8.
- Similar duplicate-PC pattern continues; at the end we get **4 “RTL extra”** entries: (0x10C, x0), (0x110, x20, 0), (0x114, x21, 5), (0x118, x20, 1) — i.e. NOP + loop init + first loop iteration.

So:

1. **First 34 writes:** RTL has one extra retirement (so its stream is already shifted).
2. **Middle section:** RTL repeatedly retires the same PC twice (0xAC, 0xB8, …).
3. **End:** RTL has 4 more retirements than REF (59 vs 55); those 4 match a second pass through 0x10C–0x118.

Conclusion: the RTL is **duplicating retirements** (same instruction’s RF write counted/retired more than once), not the REF.

---

## Who Is Correct?

- **Reference:** One instruction per cycle; branches/JAL/JALR set `next_pc`; no speculation; RF write only when an instruction that writes a register is executed. Matches the assembly and RV32I semantics.
- **RTL:** Same program and same memory; the **values** written (e.g. x3=3, x4=4) are correct when the **PC** is correct, but the **order and count** of retirements are wrong: duplicates and 4 extra writes.

So the **reference is correct**; the **RTL is wrong**: it is committing/writing the same instruction more than once in several places.

---

## Likely RTL Causes (to fix)

1. **Flush / bubble propagation**
   - When `branch_taken_Q102H` (or jump) is high, `flush_Q101H` bubbles decode (Q101H). The instruction that was in Q101H (e.g. the “skipped” instruction after the branch) must **not** later write the RF. If a bubble is not applied consistently (e.g. only to decode but not to later stages), or if valid/control is not cleared all the way to WB, that instruction can still retire and cause a duplicate write.

2. **Load-use hazard and Q103H**
   - When `load_use_hazard` is true, `ctrl_Q102H_eff = 0` is sent into Q103H, so the **current** Q102H instruction is not advanced to Q103H; instead a bubble is. But Q103H is **overwritten** with that bubble, so the instruction that was **already in Q103H** is lost. That would cause **missing** retirements, not extra. So this is a separate bug; the **extra** retirements are more likely from flush/valid handling.

3. **JALR target LSB**
   - The REF clears LSB: `next_pc = (data_rd1 + imm_i) & 32'hFFFFFFFE`. The RTL comment in `rv_ctrl.sv` says “Need to mask LSB of target” for JALR, but `rv_if` uses `alu_out_Q102H` directly for next PC. If JALR target LSB is not masked, the RTL could jump to the wrong address once and re-execute a block (e.g. 0x10C–0x118), which would add exactly the kind of “4 extra” block we see. So JALR LSB masking in RTL is worth checking.

**Recommended next steps:**

- Trace **valid** and **reg_write_en** from decode through to WB on branch/jump cycles; ensure flushed instructions never reach WB with valid=1.
- Add JALR LSB masking for the branch target (e.g. in EXE: `(rs1 + imm) & 32'hFFFFFFFE` for JALR) and use that for `next_pc` when JALR is taken.
- Optionally fix load-use hazard so that on stall we **hold** Q103H instead of overwriting it with a bubble, to avoid losing the load’s write-back.
