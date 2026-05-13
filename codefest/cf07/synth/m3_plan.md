# M3 Plan — compute_core Synthesis (Option A)

**Target date:** May 24, 2026

## What I Will Change for M3

The synthesis confirmed that the four parallel 16×16 multipliers in Stage 1 dominate
both area (32% of cells) and the critical path. Based on the numbers:

**Keep the 10 ns clock target (100 MHz):** ABC closed timing under 10 ns. The estimated
7–9 ns critical path leaves enough margin to proceed without changing the clock period.

**Run full OpenLane 2 with a newer yosys:** The yosys 0.33 `-y` flag issue will be
resolved by building yosys from source (≥0.36) or using the OpenLane 2 nix environment,
enabling proper STA via OpenROAD/OpenSTA and an actual WNS/TNS number to replace the
ABC estimate.

**Explore DSP mapping:** 6,049 cells for a single butterfly PE is large. For the full
256-point FFT (128 PEs or 1 PE reused), area scales directly. If sky130 provides DSP
primitives, mapping the 16×16 multipliers to them would reduce cell count significantly.

**Add the full 8-stage FFT datapath:** M3 requires integrating compute_core with the SPI
slave and SRAM controller. The 47,356 µm² per PE provides the baseline for estimating
total die area once all 128 butterfly stages are instantiated or scheduled.
