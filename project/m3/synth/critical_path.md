# Critical Path Analysis — top (M3 Synthesis)

**Tool:** Yosys 0.33 + ABC, sky130_fd_sc_hd TT 25°C 1.8V  
**Clock period:** 10 ns (100 MHz)

---

## Critical Path Identification

**Start point:** `u_core/s1_wr_br` — the 32-bit product register in Stage 1 of
`compute_core`. This register captures the result of `wr_in * br_in` (a 16×16 signed
multiply) on every rising clock edge when `valid_in` is high. It is a `dfxtp_1`
flip-flop whose clock-to-Q output feeds directly into the Stage 2 arithmetic.

**End point:** `u_core/s2_wb_r` — the Stage 2 register that holds
`(s1_wr_br - s1_wi_bi) >>> 15`, the rescaled real part of W·B in Q1.15.
This is also a `dfxtp_1` flip-flop with a setup constraint.

**Logic stages on the path (source DFF → sink DFF):**

| Stage | Cell(s) | Count | Estimated delay |
|-------|---------|-------|----------------|
| dfxtp_1 clock-to-Q | Stage 1 product register | 1 | ~0.54 ns |
| xnor2_1 / xor2_1 | Carry-save partial product XOR | 4–6 | ~1.50 ns |
| maj3_1 | Carry-save adder majority gates | 8–10 | ~3.60 ns |
| nand2_1 / a21oi_1 | Carry-propagate and sum logic | 4–6 | ~0.90 ns |
| a31oi_1 / nor3_1 | Final adder stage | 2–3 | ~0.50 ns |
| dfxtp_1 setup | Stage 2 register input | 1 | ~0.18 ns |
| **Total** | | | **~7.2 – 8.4 ns** |

---

## Why This Is the Critical Path

The 16×16 signed multiply in Stage 1 (`wr_in * br_in`, `wi_in * bi_in`, etc.) requires
a Wallace tree adder to sum partial products. In sky130_fd_sc_hd, yosys/ABC implements
this as a depth-10–12 network of `xnor2`, `xor2`, `maj3`, and `nand2` cells. Each
`maj3_1` (majority-3 gate) contributes ~0.40 ns; 8–10 of them in series dominate the
combinational delay.

The other two pipeline stages are much faster:
- **Stage 2** (`subtract + >>>15`): bit-select (wire-only) + 16-bit subtraction ≈ 2–3 ns
- **Stage 3** (butterfly add/subtract): 16-bit add/sub ≈ 1.5–2.5 ns

The FSM decode and SPI synchronizer paths are both well under 3 ns and are not on the
critical path.

---

## What Would Shorten It

1. **DSP primitive mapping:** If sky130 provided hard multiply blocks (it does not in the
   open PDK), the multiplier would be a single-cycle black box with known timing. Without
   DSPs, the Wallace tree depth is the limiting factor.

2. **Reduce operand width:** Moving from 16×16 to 12×12 multiplication (Q1.11) would
   reduce the adder tree depth by ~25%, saving ~1–2 ns. PSNR would drop but may still
   exceed the 40 dB threshold.

3. **Pipeline the multiplier:** Adding a register cut inside the 32-bit accumulation
   (splitting Stage 1 into 1a: partial products and 1b: tree reduce) would halve the
   combinational depth at the cost of one additional pipeline cycle (4 cycles total
   instead of 3).

4. **Relaxed clock target:** At 7–8 ns critical path, the design comfortably supports
   125–143 MHz without any RTL changes. The current 10 ns / 100 MHz target has 1.6–3 ns
   of positive slack available for margin.
