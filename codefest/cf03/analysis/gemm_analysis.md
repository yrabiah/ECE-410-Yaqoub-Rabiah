# GEMM Kernel Analysis — Naive vs. Tiled
## ECE 410/510 Spring 2026 | Yaqoub Rabiah | Codefest 3 CLLM

**Hardware:** NVIDIA T4 GPU (Google Colab — no local CUDA-capable GPU on host machine)
**Specs (NVIDIA data sheet):** Peak FP32 = 8.1 TFLOPS | Peak DRAM BW = 300 GB/s | Ridge point = 27.1 FLOP/byte
**Profiling tool:** cudaEventRecord (10-run average), Nsight Compute metrics referenced below

---

## Measured Results (N = 1024, FP32)

| Kernel         | Avg time  | Achieved GFLOPS | Theoretical AI  | Roofline bound   |
|----------------|-----------|-----------------|-----------------|------------------|
| Naive          | 11.8 ms   | 182 GFLOPS      | 0.25 FLOP/byte  | Memory-bound     |
| Tiled (T=8)    | 3.5 ms    | 614 GFLOPS      | 1.99 FLOP/byte  | Memory-bound     |

**Nsight Compute (ncu) summary:**
- Naive: achieved memory BW ≈ 244 GB/s (81% of peak); compute SM utilization ≈ 2.2%
- Tiled: achieved memory BW ≈ 205 GB/s (68% of peak); compute SM utilization ≈ 7.5%

---

## (a) Why the naive kernel is memory-bound

The naive kernel assigns one thread per output element C[i][j]. Each thread independently
loads a full row of A (1024 FP32 values) and a full column of B (1024 FP32 values) directly
from DRAM with no data reuse. The theoretical DRAM traffic is (2 × N³ + N²) × 4 bytes ≈ 8.59 GB
for a single pass, giving an arithmetic intensity of only 0.25 FLOP/byte — far left of the
T4 ridge point at 27.1 FLOP/byte. The roofline attainable ceiling is 0.25 × 300 = 75 GFLOPS,
yet the measured 182 GFLOPS exceeds this because L2 cache serves many repeated B-column
accesses. Even so, the kernel is firmly memory-bound: Nsight Compute reports SM compute
utilization of only 2.2%, confirming that compute units are stalled waiting for memory.

## (b) How tiling reduces DRAM traffic

The tiled kernel partitions A and B into TILE_SIZE × TILE_SIZE (8×8) blocks loaded into
shared memory. Each time a tile is loaded from DRAM, all TILE_SIZE threads in the block
reuse it TILE_SIZE times before loading the next tile. This reduces the number of DRAM
accesses per element from N (naive) to N/TILE_SIZE = 128, cutting total DRAM traffic by a
factor of TILE_SIZE = 8: from 8.59 GB to 1.07 GB. The result is a higher arithmetic
intensity of 1.99 FLOP/byte and a 3.4× measured speedup (11.8 ms → 3.5 ms).

## (c) Whether the tiled kernel achieved the expected improvement

The tiled kernel achieved a 3.4× wall-clock speedup and moved the roofline position from
0.25 to 1.99 FLOP/byte, consistent with the expected 8× DRAM traffic reduction. The
measured 614 GFLOPS is close to the roofline attainable ceiling of 598 GFLOPS, indicating
efficient memory utilization. However, both kernels remain memory-bound: with TILE_SIZE=8,
the arithmetic intensity (1.99 FLOP/byte) is still well below the ridge point (27.1 FLOP/byte).
The remaining bottleneck is insufficient tile reuse — a larger tile (e.g., T=32) would
increase AI to ~16 FLOP/byte and push the design near the ridge. The 8×8 tile also
under-utilizes the warp width (32 threads), leaving occupancy lower than achievable with
a 16×16 or 32×32 tile configuration.
