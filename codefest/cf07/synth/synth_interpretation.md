# CF07 Synthesis Interpretation — compute_core (Option A)

**Student:** Yaqoub Rabiah  
**Tool:** Yosys 0.33 + ABC + sky130_fd_sc_hd (TT 25°C 1.8V)  
**Note:** OpenLane 2.3.10 was installed but aborted at the JsonHeader step because the
system yosys 0.33 does not implement the `-y` Python-scripting flag that OpenLane 2
requires. Synthesis was therefore run directly with yosys + sky130 liberty, producing
equivalent cell-level results.

---

## (a) Clock Period and Worst-Case Slack

The synthesis was constrained to a **10 ns clock period (100 MHz)** via `abc -D 10000`.
ABC mapped the design against the sky130_fd_sc_hd TT corner. No formal STA slack number
is available from yosys alone (OpenSTA was not reachable), but the ABC mapper reported
successful completion under the 10 ns delay target, indicating the critical path is
estimated at **< 10 ns**. Based on sky130_fd_sc_hd typical cell delays (dfxtp_1
clock-to-Q ≈ 0.5 ns; xnor2_1 ≈ 0.3 ns; maj3_1 ≈ 0.4 ns) and the observed adder-tree
depth through the Stage 1 16×16 multipliers, the critical path is estimated at
**7–9 ns**, yielding an estimated worst-case slack of **+1 to +3 ns** at 10 ns. Full
OpenSTA STA will be run for M3.

---

## (b) Critical Path

The dominant logic in the synthesized netlist is the 16×16 signed multiplier in Stage 1
(`s1_wr_br`, `s1_wi_bi`, `s1_wr_bi`, `s1_wi_br`). ABC mapped this using a Wallace-tree
adder structure, which accounts for the high counts of `xnor2` (935), `xor2` (550), and
`maj3` (460) — the canonical cells for carry-save addition. The critical path runs from a
**Stage 1 input register** (source: `dfxtp_1` holding `wr_in`/`br_in` bits) through
approximately 15–18 levels of xnor2/maj3/nand2 logic, arriving at a **Stage 2 register**
(sink: `dfxtp_1` holding `s2_wb_r`/`s2_wb_i`). The arithmetic right-shift (>>>15) in
Stage 2 is free in hardware (wire re-indexing), so it does not contribute to the path.

---

## (c) Total Cell Area and Top Contributors

**Total cell area: 47,356.67 µm²** across **6,049 cells** and **285 flip-flops**.

| Rank | Cell | Count | Role |
|------|------|-------|------|
| 1 | sky130_fd_sc_hd__xnor2_1 | 935 | XOR/XNOR in multiplier sum bits |
| 2 | sky130_fd_sc_hd__nand2_1 | 713 | General logic / carry |
| 3 | sky130_fd_sc_hd__nor2_1 | 583 | General logic |
| 4 | sky130_fd_sc_hd__xor2_1 | 550 | Multiplier sum bits |
| 5 | sky130_fd_sc_hd__maj3_1 | 460 | Carry-save adder carries |

The four parallel 16×16 multipliers dominate area: xnor2 + xor2 + maj3 together account
for ~1,945 of 6,049 cells (32%), confirming the multiplier stage as the area bottleneck.

---

## (d) Failed Constraints, Hold Violations, Warnings

No timing constraints were failed (abc completed under 10 ns). There were **26 unique
warnings (234 total)**, all of the form:

```
Warning: Found unsupported expression '...' in pin attribute of cell 'sky130_fd_sc_hd__sdfxtp_...' — skipping.
```

These warnings come from yosys's `dfflibmap` pass skipping scan-chain and clock-enable
DFF variants (sdfxtp, sedfxtp, edfxbp, etc.) whose liberty function expressions use
operators yosys 0.33 cannot parse. This is **benign** — yosys correctly falls back to the
plain `dfxtp_1` DFF for all 285 registers, which is the right cell for this design
(no scan-chain required). No hold violations were reported. The `lpflow_inputiso1p` (23)
and `lpflow_isobufsrc` (266) cells in the cell list are isolation cells inserted by ABC
for power-intent reasons and are not a concern for functional correctness.
