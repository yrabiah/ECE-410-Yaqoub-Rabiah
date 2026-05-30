# CF09 Task 9 — Roofline Analysis
**Yaqoub Rabiah — ECE 410/510 Spring 2026**

---

## Roofline Model Analysis

The roofline plot (`roofline_plot.png`) compares the Python Q1.15 SW baseline against the
projected sky130 HW accelerator using two roofline ceilings.

The **CPU roofline** (200 GFLOPS peak / 20 GB/s memory bandwidth) places its ridge at
10 FLOP/byte. The SW measured operating point (AI = 3.33 FLOP/byte, 131.6 MFLOPS) lies
clearly in the **memory-bound region**, meaning the Python interpreter and Python integer
arithmetic — not compute throughput — are the true bottleneck. There is roughly
1,500× gap between the SW operating point and the CPU compute ceiling, entirely due to
Python's interpreter overhead.

The **HW roofline** (1.0 GFLOPS peak / 1.6 GB/s on-chip SRAM bandwidth) places its
ridge at 0.625 FLOP/byte. The HW operating range spans AI = 0.5 FLOP/byte (no twiddle
reuse, memory-bound) to AI = 4.0 FLOP/byte (full twiddle ROM reuse, compute-bound). In
the reuse scenario the HW is **compute-bound at 1.0 GFLOPS** — the PE is fully utilized.
Even in the no-reuse case the HW operates at 0.8 GFLOPS, only 20% below peak, because
the ridge point is low. The HW delivers a **7.6× throughput speedup** over SW at 7.6×
lower energy per window, with no change in algorithm or numerical precision.

The primary M4 action item from this plot is to confirm that twiddle factor ROM reuse is
implemented in the sequencer so the design operates in the compute-bound region.
