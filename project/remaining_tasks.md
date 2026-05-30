# CF09 Task 10 — Remaining Tasks Before M4
**Yaqoub Rabiah — ECE 410/510 Spring 2026**

---

## Three Most Important Changes Before M4

### 1. Build Yosys ≥ 0.36 and Run Full OpenLane 2 Flow

**Why it matters:** The M3 synthesis used Yosys 0.33 + direct ABC, which cannot run the
OpenLane 2 flow to completion. As a result, M3 has no formal WNS/TNS slack values from
OpenSTA, no routed power estimate from OpenROAD, and no physical design (DEF/GDSII). M4
requires all three to close the design and measure real performance.

**Action:** Install Yosys ≥ 0.36 in WSL (either built from source at the 0.38 release tag
or via the OpenLane 2 nix-based installer that bundles its own tool set). Then rerun the
full OpenLane 2 Classic flow on `top.sv` to obtain:
- `reports/signoff/timing.rpt` — WNS, TNS, hold slack
- `reports/signoff/power.rpt` — post-P&R dynamic and leakage from OpenROAD
- `results/signoff/top.gds` — layout for area/DRC verification

---

### 2. Implement the 8-Pass FFT Sequencer (`fft_ctrl.sv`)

**Why it matters:** The current `compute_core.sv` implements a single butterfly PE. A
256-point radix-2 DIF FFT requires 1,024 butterflies across 8 passes with a specific
butterfly scheduling pattern and twiddle-factor address sequence. Without a sequencer,
the SPI master must issue 1,024 separate WRITE+READ transactions per FFT, which limits
throughput to ~35 windows/sec (SPI-limited). The sequencer moves operand fetching and
twiddle ROM addressing on-chip, eliminating 99.9% of the SPI overhead.

**Action:** Write `fft_ctrl.sv` with:
- A twiddle-factor ROM (256 × 32-bit entries for cos/sin in Q1.15)
- A butterfly scheduling counter (pass index 0–7, butterfly index 0–127)
- A 512-word INT16 data RAM (ping-pong buffers for in-place DIF)
- A sequencer FSM that drives `compute_core` for all 1,024 butterflies per FFT trigger

---

### 3. Replace the SPI Interface with AXI4-Lite and Measure Actual Throughput

**Why it matters:** The roofline analysis (CF09 Task 9) shows the HW is capable of
1.0 GFLOPS (compute-bound), but the current SPI interface reduces effective throughput
to ~35 windows/sec — three orders of magnitude below the compute ceiling. The M4
benchmark comparing HW to the SW 33,977 windows/sec baseline cannot be meaningful until
the I/O bottleneck is removed.

**Action:**
- Replace `spi_slave.sv` with an `axi4_lite_slave.sv` that supports 64-byte burst
  transfers for loading the 512-word input RAM in a single AXI burst (~40 cycles at
  100 MHz, vs. 28 ms for SPI per FFT).
- Update `top.sv` to connect the AXI slave to the FFT sequencer and data RAM.
- Re-run the co-simulation testbench with an AXI master model.
- Measure throughput: projected AXI-limited FFT time ≈ 40 cycles (AXI load) +
  1,027 cycles (compute) ≈ 10.7 µs → **~93,000 windows/sec**, within 5% of the
  compute-only ceiling and **2.7× beyond the M1 100× target** vs. the numpy baseline.
