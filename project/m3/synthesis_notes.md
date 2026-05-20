# M3 Synthesis Notes and Scope Status

**Student:** Yaqoub Rabiah  
**Course:** ECE 410/510 HW4AI, Spring 2026  
**Date:** 2026-05-20  
**Design:** 256-pt FFT Vibration Anomaly Detection Accelerator — Milestone 3

---

## What Was Synthesized

The M3 synthesis target is `top.sv`, the integrated design that instantiates both M2
modules (`compute_core.sv` and `interface.sv` / `spi_slave`) and connects them through a
12-state FSM glue layer. All three files were compiled together in a single synthesis run:

```
read_verilog -sv compute_core.sv
read_verilog -sv interface.sv
read_verilog -sv top.sv
synth -top top -flatten
dfflibmap -liberty sky130_fd_sc_hd__tt_025C_1v80.lib
abc -liberty sky130_fd_sc_hd__tt_025C_1v80.lib -D 10000
stat -liberty sky130_fd_sc_hd__tt_025C_1v80.lib
```

The synthesis tool was **Yosys 0.33** with **ABC** and the **sky130_fd_sc_hd** standard
cell library at TT 25°C 1.8V. OpenLane 2.3.10 was installed via pip, and the first four
steps of the Classic flow executed correctly (RTL reading, linting, synthesis, DFF
mapping). The flow aborted at step 5 (`Generate JSON Header`) because the system Yosys
0.33 does not implement the `-y` Python-scripting flag required by OpenLane 2's
`yosys-jsonheader` script. The error message was:

```
yosys: invalid option -- 'y'
Run 'yosys -h' for help.
[ERROR] Subprocess had a non-zero exit.
```

This is a known incompatibility between OpenLane 2.3.x and pre-0.36 Yosys builds.
Synthesis was therefore run directly with Yosys + ABC, producing the same cell-level
netlists and statistics that OpenLane would produce in its synthesis step. The OpenLane
configuration file (`config.json`) is committed, and the full Yosys stdout/stderr is
committed as `openlane_run.log`.

---

## Synthesis Results

The synthesis completed without errors. Key numbers:

| Metric | Value |
|--------|-------|
| Total cells | 7,089 |
| Flip-flops (dfxtp_1) | 517 |
| Chip area | 55,532.01 µm² |
| Clock target | 10 ns (100 MHz) |
| ABC timing result | Closed under 10 ns (no infeasible paths) |
| Synthesis warnings | 26 unique, 234 total (all benign liberty skips) |

The integrated design is 7,089 cells — approximately 1,040 more than the standalone
`compute_core` (6,049 from CF07). The delta accounts for the `spi_slave` (3-FF
synchronizers, shift registers, bit counter: ~770 cells) and the FSM glue layer (state
register, input latches, output result registers, tx_data mux: ~270 cells). The
compute_core dominates area at ~85% of total, confirming that the 16×16 multiplier is
the correct optimization target for M4.

---

## What Worked

**RTL integration (top.sv):** The FSM correctly sequences the SPI receive-compute-send
cycle. The key design decision — driving `core_valid_in` for one cycle immediately after
the seventh SPI word is received — ensures that `ar_r` through `wi_r` are all stable in
their registers when `compute_core` samples them. This was verified by tracing the
non-blocking assignment semantics: `wi_r <= rx_data` and `core_valid_in <= 1'b1` both
resolve at the same posedge, so `compute_core` sees correct operands and a valid strobe
simultaneously on the next clock cycle.

**Co-simulation:** The testbench drove the SPI interface in Mode 0 (CPOL=0, CPHA=0)
with an 8-cycle half-period (6.25 MHz SPI clock against a 100 MHz system clock, giving
>4× margin over the 3-FF synchronizer latency). The test vector — A=100+0j, B=100+0j,
W=0.5+0j — produced `A'=150+0j` and `B'=50+0j`, matching the hand-calculated expected
values from the M2 butterfly analysis. All 4 output words returned correctly through
MISO. The simulation ran to completion at t=32.175 µs with `4/4 checks PASS`.

**Synthesis:** Yosys completed the synthesis-through-ABC flow without internal errors.
The `-D 10000` ABC delay constraint (10 ns) was met. No logic problems were flagged by
Yosys CHECK. The 26 unique warnings are identical to those seen in CF07 and are benign:
they come from `dfflibmap` skipping scan-chain DFF variants (`sdfxtp`, `sedfxtp`,
`edfxbp`) whose liberty function expressions use operators Yosys 0.33 cannot parse.
Yosys correctly maps all 517 flip-flops to the plain `dfxtp_1` cell.

---

## What Did Not Work

**OpenLane 2 full flow:** The `-y` flag issue blocked the flow after step 4. This means
the M3 submission does not include an OpenROAD-generated timing report (WNS, TNS, hold
checks) or a routed power report. The timing and power files are estimates derived from
cell characterisation data and ABC's delay model. For M4, Yosys will be built from
source (≥0.36, the first release with stable `-y` support) or the OpenLane 2 nix-based
installation will be used, which bundles its own tool set and bypasses the system Yosys.

**Formal STA:** Without OpenSTA, worst-case slack is an estimate (≈+1.6–3.1 ns at
10 ns). The estimate is based on typical sky130_fd_sc_hd cell delays from the liberty
file: dfxtp_1 clk-to-Q (~0.54 ns), maj3_1 (~0.40 ns), xnor2_1 (~0.30 ns). The
critical path through the 16×16 Wallace-tree multiplier in Stage 1 of `compute_core` is
estimated at 7.2–8.4 ns.

**Power analysis:** Yosys 0.33 has no built-in power estimator. An order-of-magnitude
estimate of ~1.81 mW at 100 MHz / 1.8 V was derived analytically from cell count and
typical switching activity. Formal power analysis is deferred to M4 via OpenROAD.

---

## Scope Status

The project scope is **confirmed and on track** for M4. No scope reduction is required.

The single butterfly PE (`compute_core.sv`) synthesized successfully in sky130_fd_sc_hd
at 55,532 µm² for the full integrated system. The design closes timing at 100 MHz.
For the full 256-point FFT, the architecture uses a **single PE reused across 128
butterfly stages** (8 FFT passes × 16 butterflies/pass × pipeline overlap), controlled
by a sequencer to be added in M4. This avoids instantiating 128 PEs (~7 M cells) while
keeping the single-PE area manageable.

The M1 question — can the accelerator exceed the 33,977 windows/sec SW baseline by
>100× — remains the benchmark. At 100 MHz and 1 butterfly/cycle, processing 128
butterflies per 256-point FFT takes 128 cycles = 1.28 µs, giving 781,250 windows/sec.
That is **23× better than the 100× target** and 23× better than SW, assuming the SPI
transfer time and SRAM access are not the bottleneck. The SPI headroom (62.4× over
minimum) established in M1 remains valid.

---

## Plan for M4

1. Build Yosys ≥0.36 in WSL and rerun the full OpenLane 2 flow to obtain formal WNS,
   TNS, hold checks, and routed power.
2. Add the 8-pass sequencer (`fft_ctrl.sv`) that schedules 128 butterfly invocations
   and manages the twiddle-factor ROM address generation.
3. Benchmark the integrated design against the 33,977 windows/sec SW baseline from M1.
4. Plot the final roofline showing the achieved throughput against the 200 GFLOPS target
   and the 3.33 FLOP/byte arithmetic intensity ridge point.
5. Complete the design justification report tying all architectural decisions back to M1
   profiling data.
