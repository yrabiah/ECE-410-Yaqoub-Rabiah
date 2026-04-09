# Heilmeier Catechism — Refined Project Answers
## ECE 410/510 Spring 2026 | Yaqoub Rabiah
## Project: 256-Point FFT Vibration Anomaly Detection Accelerator
## Updated: Codefest 2 — profiling data now informs Q2 and Q3

---

## Q1: What are you trying to do?

I am building a small hardware chiplet that continuously monitors the vibration of a rotating
machine — such as a motor, pump, or bearing — and raises an alarm the moment the vibration
frequency spectrum deviates from a stored normal-operation profile. The chiplet sits directly
on the machine, receives raw accelerometer samples at 10 kHz over SPI, computes a 256-point
FFT on each incoming window of 256 samples, and compares the resulting magnitude spectrum
against a stored per-bin threshold. If any frequency bin exceeds its threshold, the chiplet
asserts an alarm signal to the host MCU. The goal is to catch a failing bearing or an
unbalanced shaft before it causes a breakdown, using a chip that is cheap, small, and draws
very little power so it can run continuously without human attention.

---

## Q2: How is it done today, and what are the limits of current practice?

Vibration-based predictive maintenance is handled today in one of two ways. The first is
periodic manual inspection using a handheld vibration meter compared against known-good
baselines. The second is a continuous monitoring system using a general-purpose data
acquisition board or an industrial IoT gateway that streams raw sensor data over a network
to a cloud server, where the analysis runs on a CPU or GPU.

**Limits — now grounded in profiling data:**

- **Latency:** Cloud-based analysis introduces seconds to minutes of delay. A bearing can
  fail catastrophically in under a second once it enters a failure mode.

- **CPU throughput gap:** Profiling the NumPy FFT baseline on an Intel Core Ultra 7 155U
  shows a measured throughput of only **0.93 MFLOPS** for the 256-point FFT kernel, against
  a theoretical ceiling of **77 GFLOPS**. The gap (~83,000×) is caused by Python interpreter
  overhead and the inability of pocketfft to vectorize small-N transforms. This means a
  high-performance CPU still spends disproportionate cycles on a 10,240-FLOP kernel because
  the overhead cannot be amortized over a short 256-sample window.

- **Cost and power:** Industrial IoT gateways cost hundreds to thousands of dollars per
  installation point and require continuous wireless streaming of raw high-frequency
  vibration data. A custom chiplet transmits only a 1-bit alarm flag.

- **Manual inspection:** Periodic checks miss faults that develop between visits.

---

## Q3: What is new in your approach, and why do you think it will succeed?

The new element is a pipelined radix-2 butterfly hardware accelerator that computes the
256-point FFT entirely in custom digital logic, eliminating all Python, NumPy, and OS
overhead from the inner loop.

**Specific design choices, now justified by profiling:**

1. **The FFT is the right kernel to accelerate.** cProfile confirms `compute_fft`
   (→ `_pocketfft._raw_fft`) is the dominant function at 29% of total runtime. The
   arithmetic intensity of 3.33 FLOP/byte places the kernel in the compute-bound regime
   (above the CPU ridge point of 1.03 FLOP/byte), meaning more arithmetic throughput
   directly translates to faster execution.

2. **Hardware eliminates the throughput gap.** The roofline shows 0.93 MFLOPS measured vs.
   77 GFLOPS theoretical on the CPU — an 83,000× shortfall caused by overhead, not by
   memory bandwidth. A pipelined butterfly unit at 1 GHz processes one butterfly per clock,
   targeting **200 GFLOPS** equivalent throughput. This is a >200,000× improvement over the
   measured baseline, far exceeding a purely architectural speedup.

3. **The interface is well-matched and not the bottleneck.** The required data rate is only
   160 kbit/s (512 bytes per 25.6 ms window). SPI at 10 Mbit/s provides 62.5× headroom,
   so the accelerator will not be interface-bound at the target operating point.

4. **The scope is controlled and synthesizable.** The deliverable is a single 256-point
   fixed-point FFT pipeline with per-bin threshold comparison, described in SystemVerilog
   and synthesized with OpenLane 2. This is achievable within one term.

5. **Public datasets provide ground truth.** The CWRU Bearing Dataset gives labeled
   accelerometer recordings of normal and faulty bearings, enabling a reproducible software
   baseline and verification of detection accuracy at M4.
