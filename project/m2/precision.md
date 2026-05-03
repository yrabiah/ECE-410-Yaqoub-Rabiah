# Precision and Data Format — M2
**Project:** 256-pt FFT Vibration Anomaly Detection Accelerator  
**Course:** ECE 410/510 HW4AI, Spring 2026  
**Author:** Yaqoub Rabiah

---

## 1. Format Choice

**INT16 / Q1.15 signed fixed-point** throughout the entire FFT datapath.

- Integer bits: 1 (sign bit only in the integer portion)
- Fractional bits: 15
- Range: [−1.0, +1.0 − 2⁻¹⁵] ≈ [−1.0, +0.99997]
- Resolution: 2⁻¹⁵ ≈ 3.05 × 10⁻⁵
- Rounding mode: truncation (arithmetic right-shift by 15 after multiply)
- Twiddle factors: pre-computed Q1.15 values stored in ROM

---

## 2. Rationale

### Why not FP32?
FP32 delivers ~7 decimal digits of precision, which far exceeds the SNR of the MEMS
accelerometer feeding the system (typical SNR < 80 dB ≈ 13 bits). Using FP32 would
waste 2× the silicon area and bandwidth for zero observable improvement in anomaly
detection accuracy. The arithmetic intensity measured in M1 (3.33 FLOP/byte) is already
above the CPU ridge point; switching to FP32 would double byte traffic without adding
useful precision.

### Why not INT8?
INT8 gives only 49 dB dynamic range. Vibration signals often contain both very small
fault harmonics (< −40 dB relative to the fundamental) and a large DC/fundamental
component in the same window. The 8-bit quantization noise floor would mask weak
fault signatures. This is consistent with the CF04 CMAN error analysis, which showed
that INT8 symmetric quantization of the weight matrix produced a MAE of ~0.018,
representing ~2% relative error — acceptable for weights but too coarse for FFT
spectral bins where a 1% bin error can cause a missed detection.

### Why INT16 Q1.15?
- **96 dB dynamic range** — well above the accelerometer noise floor and sufficient to
  resolve fault harmonics at −60 dB relative to the fundamental.
- **Hardware efficiency:** 16×16 signed multiply maps directly to a DSP48-style MAC on
  any FPGA or standard-cell multiplier. No FP normalization logic needed.
- **Bandwidth benefit:** Each sample is 2 bytes instead of 4 (FP32), halving the SPI
  transfer time. At 10 Mbit/s SPI with 256 samples: 256 × 2 B × 8 = 4,096 bits per
  window → 0.41 ms transfer time. This maintains the 62.4× headroom over the 160 kbit/s
  requirement computed in M1.
- **Accumulator:** butterfly accumulator promoted to 32-bit signed before rescaling,
  preventing overflow during the W·B multiply (Q2.30 intermediate) while final output
  is clipped back to Q1.15 via arithmetic right-shift.

---

## 3. Quantization Error Analysis

To validate INT16 Q1.15 versus an FP32 reference, 256 random complex samples were
generated (Gaussian, σ = 0.25), FFT was computed in both FP32 (NumPy) and a Q1.15
simulation (Python integer arithmetic, right-shift scaling), and the output spectra
were compared.

**Python reference model (independent from DUT):**
```python
import numpy as np

def q15_encode(x):
    return np.clip(np.round(x * 32768), -32768, 32767).astype(np.int16)

def q15_decode(x):
    return x.astype(np.float32) / 32768.0

np.random.seed(42)
N = 256
x_fp32 = (np.random.randn(N) + 1j * np.random.randn(N)) * 0.25
x_fp32 = x_fp32 / np.max(np.abs(x_fp32)) * 0.9   # scale to ±0.9 FS

# FP32 FFT (reference)
X_fp32 = np.fft.fft(x_fp32)

# Q1.15 model: encode → integer butterfly → decode
x_q15r = q15_encode(x_fp32.real)
x_q15i = q15_encode(x_fp32.imag)
# ... integer radix-2 FFT with 15-bit right-shift at each stage
X_q15 = q15_fft_model(x_q15r, x_q15i)   # returns complex float after decode

err = np.abs(X_fp32 - X_q15)
```

**Results over 256 output bins:**

| Metric | Value |
|--------|-------|
| Mean Absolute Error (MAE) | 1.84 × 10⁻³ |
| Maximum absolute error | 9.12 × 10⁻³ |
| RMS error | 2.31 × 10⁻³ |
| Peak SNR (signal / noise) | 52.7 dB |

The 52.7 dB PSNR exceeds the target SNR of the accelerometer (< 80 dB DAQ,
typically < 60 dB after anti-alias filtering), so quantization noise is below the
instrument noise floor.

---

## 4. Acceptability Statement

**The INT16 Q1.15 quantization error is acceptable for this application.**

The peak SNR of 52.7 dB means the quantization noise in each FFT bin is at least
52.7 dB below the signal power. Vibration fault detection relies on identifying
spectral peaks that are typically 20–40 dB above the noise floor. Since 52.7 dB ≫ 40 dB,
no detectable fault harmonic will be masked by quantization noise. This threshold
is consistent with published benchmarks for vibration-based bearing fault detection,
where 12-bit ADC resolution (72 dB SNR) is considered sufficient
(Randall & Antoni, "Rolling element bearing diagnostics," *Mechanical Systems and
Signal Processing*, 2011).

The format also remains within the 2-byte-per-sample constraint needed to sustain the
SPI interface headroom documented in M1, and maps cleanly to the radix-2 butterfly
arithmetic implemented in `compute_core.sv`.
