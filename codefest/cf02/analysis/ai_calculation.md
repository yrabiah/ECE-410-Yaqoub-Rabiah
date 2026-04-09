# Arithmetic Intensity — 256-Point FFT Kernel
## ECE 410/510 Spring 2026 | Yaqoub Rabiah | Codefest 2

**Target kernel:** `compute_fft` — 256-point real-input FFT using Cooley-Tukey radix-2 butterfly  
**Algorithm:** Vibration anomaly detection via FFT spectrum comparison  
**Hardware:** Intel Core Ultra 7 155U (profiled platform)

---

## 1. FLOPs Calculation

A radix-2 Cooley-Tukey FFT of length N has **(N/2) × log₂(N)** butterfly stages.

For N = 256:

```
Butterflies = (256/2) × log₂(256) = 128 × 8 = 1,024 butterflies
```

Each radix-2 butterfly performs one complex multiply and two complex adds:
- Complex multiply:  4 real multiplications + 2 real additions = 6 FLOPs
- 2 complex adds:    2 × 2 real additions                      = 4 FLOPs
- FLOPs per butterfly: 10

```
Total FLOPs = 1,024 butterflies × 10 FLOPs/butterfly = 10,240 FLOPs
```

Equivalently, using the standard formula: **5 × N × log₂(N) / 2 = 5 × 256 × 8 / 2 = 5,120 FLOPs** (counting only multiply-adds). Using the fuller 10-FLOP per butterfly count gives **10,240 FLOPs**; this document uses **10,240 FLOPs** for a conservative (higher) intensity estimate.

---

## 2. Bytes Transferred (No DRAM Reuse)

All operands assumed loaded fresh from DRAM each window:

| Operand            | Size                              | Bytes (FP32) |
|--------------------|-----------------------------------|--------------|
| Input window       | 256 real samples × 4 bytes        | 1,024        |
| Twiddle factors    | 128 complex × 2 × 4 bytes         | 1,024        |
| Output spectrum    | 128 complex (rfft) × 2 × 4 bytes  | 1,024        |
| **Total**          |                                   | **3,072**    |

```
Bytes = 1,024 + 1,024 + 1,024 = 3,072 bytes
```

---

## 3. Arithmetic Intensity

```
AI = FLOPs / Bytes
   = 10,240 / 3,072
   = 3.33 FLOP/byte
```

---

## 4. Hardware Ridge Point (Intel Core Ultra 7 155U)

| Parameter              | Value        | Source                          |
|------------------------|--------------|---------------------------------|
| Peak FP32 (1 P-core)   | 77 GFLOPS    | 2 FMA × 8 FP32 (AVX2) × 4.8 GHz|
| Peak DRAM bandwidth    | 75 GB/s      | LPDDR5x-6400 dual-channel       |
| Ridge point            | 77/75 ≈ 1.03 FLOP/byte | —                    |

---

## 5. Bound Classification

```
AI = 3.33 FLOP/byte  >  Ridge point = 1.03 FLOP/byte
```

**The 256-point FFT kernel is COMPUTE-BOUND on the Intel Core Ultra 7 155U.**

Attainable performance on the CPU:

```
Attainable = min(Peak compute, AI × Peak BW)
           = min(77 GFLOPS, 3.33 × 75 GB/s)
           = min(77 GFLOPS, 249.75 GFLOPS)
           = 77 GFLOPS  (compute ceiling)
```

Measured throughput from profiling:
```
FLOPs per window    : 10,240
Time per window     : 11 µs  (tottime on _raw_fft, 1000-run average)
Measured throughput : 10,240 / 11e-6 = 931 MFLOPS = 0.93 GFLOPS
```

The measured 0.93 GFLOPS is far below the 77 GFLOPS ceiling because:
1. NumPy's pocketfft runs scalar (no AVX2 vectorization for small N).
2. Python function call overhead dominates at N=256.
3. A single window is too small to saturate a superscalar pipeline.

This gap is exactly the hardware acceleration opportunity: a pipelined butterfly unit
in hardware would eliminate interpreter overhead and exploit fine-grained parallelism.
