# Project Scope Assessment
**Student:** Yaqoub Rabiah  
**Course:** ECE 410/510 HW4AI, Spring 2026  
**Updated:** 2026-05-13 (CF07)

---

## Project Description

256-point FFT Vibration Anomaly Detection Accelerator:
MCU → SPI → chiplet (FFT engine + SRAM) → alarm flag.

---

## Scope: Confirmed with Adjustments

The project scope is **confirmed** at the single-butterfly-PE level for M3, with a
realistic path to a full 8-stage pipelined datapath for M4.

### What the Synthesis Confirmed

Running synthesis on `compute_core.sv` (the radix-2 DIF butterfly PE) with yosys 0.33 +
sky130_fd_sc_hd produced:

| Metric | Value |
|--------|-------|
| Total cells | 6,049 |
| Flip-flops | 285 |
| Chip area (1 PE) | 47,356.67 µm² |
| Clock target | 10 ns (100 MHz) |
| Timing | Closed under 10 ns per ABC |

The single PE is feasible in sky130. The 16×16 multipliers dominate area (32% of cells),
which is expected for Q1.15 fixed-point arithmetic.

### Scope Adjustment: M3 Focus

**M3 (due May 24):** Synthesize the full datapath using a single compute_core PE with a
sequential controller that re-uses it for all 128 butterfly stages across 8 FFT passes.
This avoids instantiating 128 PEs (which would be ~6M cells) and keeps die area
tractable. The SPI slave (`interface.sv`) and the butterfly PE will be co-simulated.

**M4 (due Jun 7):** Add the SRAM controller, benchmark against the 33,977 windows/sec SW
baseline, and produce the full roofline showing actual vs. 200 GFLOPS target.

### Risk

OpenLane 2's full RTL-to-GDS flow requires a newer yosys build. This will be resolved
before M3 by building yosys ≥0.36 from source in WSL. If that fails, the yosys + abc
synthesis used in CF07 is sufficient to produce timing and area numbers for the M3 report.

---

## Key Numbers (unchanged from M1/M2)

| Metric | Value |
|--------|-------|
| SW baseline | 33,977 windows/sec, 29.43 µs/window |
| HW target | 200 GFLOPS, >100× speedup |
| Arithmetic intensity | 3.33 FLOP/byte (compute-bound) |
| Precision | INT16 Q1.15, PSNR = 52.7 dB |
| Interface | SPI 10 Mbit/s, 62.4× headroom |
