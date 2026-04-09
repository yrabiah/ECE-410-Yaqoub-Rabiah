# HW/SW Partition Proposal
## ECE 410/510 Spring 2026 | Yaqoub Rabiah | Codefest 2

---

## (a) Which kernel to accelerate in hardware and why

The 256-point FFT butterfly computation (`compute_fft`) is the kernel targeted for hardware
acceleration. Profiling confirms it is the dominant function in the detection pipeline,
accounting for 29% of total CPU runtime (0.011 s / 0.038 s per 1,000 windows). Its arithmetic
intensity is 3.33 FLOP/byte, which places it to the right of the CPU ridge point (1.03 FLOP/byte),
making it compute-bound rather than memory-bound on the laptop CPU.

The roofline analysis exposes a large gap between theoretical and measured performance:
the peak CPU ceiling for this kernel is 77 GFLOPS, but the measured throughput is only
0.93 MFLOPS — a shortfall of ~83,000×. This gap exists because NumPy's pocketfft backend
executes the N=256 transform without AVX2 vectorization, and Python function-call overhead
dominates for small window sizes. A pipelined hardware butterfly unit eliminates both
sources of overhead. A fixed-point (INT16) radix-2 pipeline at 1 GHz can sustain one
butterfly per cycle, giving a target throughput of ~200 GFLOPS equivalent — a >200,000×
improvement over the measured software baseline.

---

## (b) What software will continue to handle

The host MCU software retains responsibility for: sensor SPI receive, double-buffering of
incoming 256-sample windows, alarm flag interpretation and system-level response (e.g.,
sending an alert over UART or activating a relay), one-time calibration of the frequency-bin
thresholds during the normal-operation learning phase, and any diagnostic logging.
These tasks are low-frequency control-plane operations that do not require hardware
acceleration and benefit from the flexibility of software.

---

## (c) Interface bandwidth requirement

One window = 256 INT16 samples = 512 bytes. At a 10 kHz sampling rate, one window
completes every 25.6 ms. The required SPI bandwidth to sustain real-time operation is:

```
BW = 512 bytes / 25.6 ms = 20 kB/s = 160 kbit/s
```

SPI at 10 Mbit/s provides 62.5× headroom over this requirement. The accelerator is not
interface-bound: the 160 kbit/s data rate is negligible compared to the SPI bandwidth
ceiling. Even at the lowest common SPI mode (1 Mbit/s), the transfer completes in 4 ms,
leaving 21.6 ms of idle time before the next window. The interface will not become the
bottleneck unless the window size is increased by more than 60× or the sampling rate
is raised above 600 kHz — neither of which is in scope.

---

## (d) Compute-bound vs. memory-bound, and expected change

On the current CPU platform the 256-point FFT is compute-bound (AI = 3.33 FLOP/byte >
ridge point 1.03 FLOP/byte). However, the measured performance is far below the compute
ceiling because the workload is too small to amortize Python and NumPy overhead across
enough arithmetic work per invocation.

The hardware accelerator is expected to remain compute-bound. With on-chip SRAM holding
the twiddle factors and both the input and output buffers (total ~3 KB, well within a
small SRAM), effective memory traffic drops to nearly zero during computation — all
operands are register-resident or fetched from single-cycle SRAM. The arithmetic intensity
effectively rises well above the hardware ridge point (0.40 FLOP/byte), pushing the design
firmly into the compute-bound regime. The compute ceiling of 200 GFLOPS will be the
limiting factor, not memory bandwidth, which is the desired outcome for a dense arithmetic
kernel like the FFT butterfly.
