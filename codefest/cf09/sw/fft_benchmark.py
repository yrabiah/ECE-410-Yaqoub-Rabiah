"""
CF09 Task 6 — SW Baseline Benchmark
256-point FFT vibration anomaly detection (INT16 / Q1.15)
Yaqoub Rabiah — ECE 410/510 Spring 2026
"""
import time, tracemalloc, math, random

RUNS   = 10_000
N      = 256
FS     = 10_000   # Hz
FLOPS_PER_FFT = 10_240   # N/2 * log2(N) * 10 FLOPs/butterfly

# --- Q1.15 helpers ---
def to_q15(x):
    v = int(round(x * 32768))
    return max(-32768, min(32767, v))

def q15_mul(a, b):
    return max(-32768, min(32767, (a * b) >> 15))

def generate_window(n=N, fs=FS):
    """Hann-windowed sine burst at 120 Hz and noise."""
    sig = []
    f0 = 120.0
    for k in range(n):
        t = k / fs
        s = 0.5 * math.sin(2 * math.pi * f0 * t) + 0.05 * (random.random() * 2 - 1)
        hann = 0.5 * (1 - math.cos(2 * math.pi * k / (n - 1)))
        sig.append(to_q15(s * hann))
    return sig

def fft_q15(x):
    """Radix-2 DIF Cooley-Tukey, Q1.15 butterfly, in-place."""
    n = len(x)
    xr = list(x)
    xi = [0] * n
    # bit-reversal
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j ^= bit
        if i < j:
            xr[i], xr[j] = xr[j], xr[i]
    # stages
    length = 2
    while length <= n:
        half = length >> 1
        for i in range(0, n, length):
            for k in range(half):
                angle = -2 * math.pi * k / length
                wr = to_q15(math.cos(angle))
                wi = to_q15(math.sin(angle))
                tr = q15_mul(wr, xr[i+k+half]) - q15_mul(wi, xi[i+k+half])
                ti = q15_mul(wr, xi[i+k+half]) + q15_mul(wi, xr[i+k+half])
                xr[i+k+half] = xr[i+k] - tr
                xi[i+k+half] = xi[i+k] - ti
                xr[i+k] += tr
                xi[i+k] += ti
        length <<= 1
    return xr, xi

def detect_anomaly(xr, xi, n=N):
    mag_sq = [xr[k]**2 + xi[k]**2 for k in range(n // 2)]
    peak   = max(mag_sq)
    mean   = sum(mag_sq) / len(mag_sq)
    return peak > 5 * mean

# --- Benchmark ---
tracemalloc.start()
random.seed(42)
windows = [generate_window() for _ in range(100)]   # pre-generate; not in timing loop

start = time.perf_counter()
for i in range(RUNS):
    sig    = windows[i % 100]
    xr, xi = fft_q15(sig)
    _      = detect_anomaly(xr, xi)
elapsed = time.perf_counter() - start

_, peak_mem = tracemalloc.get_traced_memory()
tracemalloc.stop()

per_win  = elapsed / RUNS * 1e6        # µs
tput     = RUNS / elapsed              # windows/sec
mflops   = (FLOPS_PER_FFT * tput) / 1e6

print(f"N_RUNS:     {RUNS}")
print(f"Total:      {elapsed*1000:.2f} ms")
print(f"Per window: {per_win:.2f} µs")
print(f"Throughput: {tput:,.0f} windows/sec")
print(f"MFLOPS:     {mflops:.1f}")
print(f"Peak mem:   {peak_mem/1024:.1f} KB")
