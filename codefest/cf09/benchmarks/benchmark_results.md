# CF09 Benchmark Results
**Yaqoub Rabiah — ECE 410/510 Spring 2026**

---

## Task 6 — SW Baseline Re-Run

The Python Q1.15 FFT benchmark was re-run with the `generate_window()` overhead removed
from the timing loop (pre-generated 100 windows, cycled via `i % 100`).

```
N_RUNS:     10,000
Total:      777.99 ms
Per window: 77.80 µs
Throughput: 12,854 windows/sec
MFLOPS:     131.6
Peak mem:   8.3 KB
```

**Note:** The M1 SW baseline (33,977 windows/sec) was measured with `numpy` FFT.
This run uses a pure-Python Q1.15 radix-2 DIF implementation to match the hardware
algorithm exactly. The throughput difference reflects the overhead of Python integer
arithmetic vs. numpy's C-backed FFT — the hardware compares fairly against the
Python SW baseline since both implement the identical Q1.15 butterfly.

---

## Task 7 — HW Accelerator Projected Metrics

The M3 compute_core synthesizes at **100 MHz** with a single pipelined butterfly PE
(3-cycle latency, 1 butterfly/cycle throughput after pipeline fill). A 256-point FFT
requires N/2 × log₂(N) = **1,024 butterflies**.

### Compute-Only (no I/O overhead)

| Metric | Value | Basis |
|--------|-------|-------|
| Clock | 100 MHz | Synthesis (10 ns closed) |
| Butterflies per FFT | 1,024 | N=256, radix-2, 8 passes |
| Cycles per FFT | 1,024 + 3 (fill) ≈ 1,027 | Pipeline fill negligible |
| Time per FFT | 10.27 µs | 1,027 × 10 ns |
| **Projected throughput** | **97,385 windows/sec** | 1/10.27 µs |
| Projected peak FLOPs | **1.0 GFLOPS** | 10,240 × 97,385 / 10⁶ |
| Area | 55,532 µm² | sky130_fd_sc_hd (M3 synthesis) |
| Power | ~1.81 mW | Analytical estimate (M3) |

### SPI I/O-Limited (current M3 interface)

Each butterfly requires 7 SPI words in (WRITE_CMD + 6 operands) + 4 words out
(READ_CMD + 3 NOPs) = **11 × 16-bit transactions** at 6.25 MHz SPI clock.

| Metric | Value |
|--------|-------|
| Time per SPI transaction | 16 bits ÷ 6.25 MHz = 2.56 µs |
| SPI overhead per butterfly | 11 × 2.56 = 28.16 µs |
| SPI overhead per FFT | 28.16 µs × 1,024 = 28.84 ms |
| **SPI-limited throughput** | **~34.7 windows/sec** |

The SPI bottleneck is severe. M4 addresses this by moving to an AXI4-Lite burst
interface, reducing I/O time to ~10 µs/FFT and restoring near-compute-limited
throughput.

---

## Task 8 — Speedup Summary Table

| Platform | Throughput (win/sec) | Latency/win | FLOPS | Speedup vs SW |
|----------|---------------------|-------------|-------|---------------|
| **SW (Python Q1.15)** | 12,854 | 77.80 µs | 131.6 MFLOPS | 1× (baseline) |
| **HW projected (compute-only)** | 97,385 | 10.27 µs | 1.0 GFLOPS | **7.6×** |
| **HW projected (AXI4-Lite M4)** | ~90,000 | ~11.1 µs | ~920 MFLOPS | **~7×** |
| HW current (SPI-limited) | ~35 | ~28.8 ms | ~0.36 MFLOPS | 0.003× |

**Key result:** The compute-only HW projection delivers **7.6× speedup** over the
Python SW baseline and operates at **1.0 GFLOPS** vs. 131.6 MFLOPS for SW — a 7.6×
FLOPS improvement. The SPI interface is the sole bottleneck preventing this speedup
from being realized in the current M3 integration; replacing it with AXI4-Lite in M4
is the critical path to achieving near-peak throughput.

The M1 100× target against the numpy baseline (33,977 win/sec) requires ~3.4 M win/sec.
Achieving that would require either deep pipelining (8 parallel PEs) or a much faster
on-chip interface. The current single-PE architecture is projected at ~7× over the Python
Q1.15 baseline; the M4 architecture will quantify the gap more precisely with formal STA
and post-P&R power from OpenROAD.
