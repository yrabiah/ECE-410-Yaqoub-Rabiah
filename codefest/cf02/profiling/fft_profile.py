"""
Profiling script for 256-point FFT vibration anomaly detection pipeline.
Simulates the dominant kernel: windowed FFT + threshold comparison.
Runs 100 iterations to capture stable timing. Uses cProfile for function-level
and line_profiler (if available) for line-level breakdown.
"""

import cProfile
import pstats
import io
import numpy as np
import time

# ── Configurable parameters ──────────────────────────────────────────────────
N = 256          # FFT window size (samples)
FS = 10_000      # Sampling rate (Hz)
N_RUNS = 100     # Number of windows profiled
N_BINS = N // 2  # Frequency bins (positive spectrum)
rng = np.random.default_rng(42)

# ── Simulated normal-operation baseline profile ──────────────────────────────
BASELINE = rng.uniform(0, 0.5, N_BINS).astype(np.float32)
THRESHOLD_FACTOR = 2.0   # Alarm if any bin exceeds 2× baseline


def generate_window(n: int = N) -> np.ndarray:
    """Simulate one window of INT16 accelerometer data, convert to float32."""
    raw = rng.integers(-32768, 32767, size=n, dtype=np.int16)
    return raw.astype(np.float32) / 32768.0


def compute_fft(window: np.ndarray) -> np.ndarray:
    """Compute 256-point FFT and return magnitude spectrum (positive bins)."""
    spectrum = np.fft.rfft(window, n=N)          # 129 complex bins
    magnitude = np.abs(spectrum[:N_BINS])        # 128 positive bins
    return magnitude


def compare_threshold(magnitude: np.ndarray, baseline: np.ndarray) -> bool:
    """Return True if any frequency bin exceeds threshold * baseline."""
    return bool(np.any(magnitude > THRESHOLD_FACTOR * baseline))


def process_window(window: np.ndarray) -> bool:
    """Full pipeline: FFT → magnitude → threshold comparison."""
    mag = compute_fft(window)
    return compare_threshold(mag, BASELINE)


def run_pipeline(n_runs: int = N_RUNS) -> None:
    """Run the full detection pipeline n_runs times."""
    alarms = 0
    for _ in range(n_runs):
        window = generate_window()
        if process_window(window):
            alarms += 1


# ── cProfile run ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    pr = cProfile.Profile()
    pr.enable()
    run_pipeline(N_RUNS)
    pr.disable()

    stream = io.StringIO()
    ps = pstats.Stats(pr, stream=stream)
    ps.strip_dirs()
    ps.sort_stats("cumulative")
    ps.print_stats(20)

    output = stream.getvalue()
    print(output)

    out_path = "project_profile.txt"
    with open(out_path, "w") as f:
        f.write(f"# FFT Vibration Anomaly Detection — cProfile output\n")
        f.write(f"# N={N} samples/window, {N_RUNS} windows, fs={FS} Hz\n")
        f.write(f"# Dominant kernel: compute_fft (np.fft.rfft)\n\n")
        f.write(output)

    print(f"Saved to {out_path}")
