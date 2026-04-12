# Software Baseline Benchmark
## ECE 410/510 Spring 2026 | Yaqoub Rabiah
## Project: 256-Point FFT Vibration Anomaly Detection Accelerator

---

## Platform Configuration

| Parameter        | Value                                         |
|------------------|-----------------------------------------------|
| CPU              | Intel Core Ultra 7 155U (12-core, 4.8 GHz boost) |
| RAM              | LPDDR5x dual-channel                          |
| OS               | Windows 11 (Build 10.0.26100)                 |
| Python           | 3.12.10 (MSC v.1943 64-bit)                  |
| NumPy            | 2.4.4 (pocketfft backend)                     |
| Batch size       | 1 window (256 samples) per inference call     |
| Precision        | FP32 (weights and activations)                |
| FFT window size  | N = 256 samples                               |
| Sampling rate    | fs = 10,000 Hz → window period = 25.6 ms      |

---

## Benchmark Method

The pipeline processes one 256-sample window per call:
1. Convert INT16 sensor samples → FP32
2. Compute 256-point rfft (np.fft.rfft)
3. Take magnitude of 128 positive bins
4. Compare against stored FP32 threshold profile

Timing was measured using `time.perf_counter` over **20 independent runs of 1,000 windows each**
after a 10-window warm-up. Median is reported to suppress OS scheduling noise.

---

## Results

| Metric                        | Value              |
|-------------------------------|--------------------|
| Median time per window        | **29.43 µs**       |
| Median time per 1,000 windows | 29.43 ms           |
| Throughput                    | **33,977 windows/sec** |
| Compute throughput            | **347.9 MFLOPS**   |
| Peak memory (tracemalloc)     | **7.73 KB**        |
| Real-time margin              | 25,600 µs / 29.43 µs = **870×** |

---

## M4 Comparison Point

At M4, the hardware accelerator throughput will be compared against this baseline:

- **Software baseline:** 33,977 windows/sec @ 347.9 MFLOPS on Intel Core Ultra 7 155U
- Target speedup: ≥ 100× in windows/sec at equivalent or lower power

To reproduce: run `codefest/cf02/profiling/fft_profile.py` on the same platform with N=256,
fs=10000, N_RUNS=1000, 20 outer timing iterations.
