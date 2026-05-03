# Milestone 2 — Simulation Reproduction Guide
**Project:** 256-pt FFT Vibration Anomaly Detection Accelerator  
**Course:** ECE 410/510 HW4AI, Spring 2026  
**Author:** Yaqoub Rabiah

---

## Requirements

| Tool | Version tested | Install |
|------|---------------|---------|
| Icarus Verilog | 12.0 | `sudo apt install iverilog` |
| vvp (bundled with iverilog) | 12.0 | (same package) |
| Python | 3.12+ | (waveform diagram only) |
| matplotlib | 3.10+ | `pip install matplotlib` |

All simulations run on Linux/WSL.  
Repository root is referenced as `$REPO`.

---

## 1. Compute Core Testbench

```bash
cd $REPO/project/m2/tb

iverilog -g2012 -o cc_sim \
    tb_compute_core.sv \
    ../rtl/compute_core.sv

vvp cc_sim
```

**Expected output:**
```
--- Vector 1: W=0.5+0j, A=100+0j, B=100+0j ---
    valid_out = 1  (expected 1)
  PASS  ar_out = 150
  PASS  ai_out = 0
  PASS  br_out = 50
  PASS  bi_out = 0
--- Vector 2: W=0+0.5j, A=0+100j, B=100+0j ---
    valid_out = 1  (expected 1)
  PASS  ar_out = 0
  PASS  ai_out = 150
  PASS  br_out = 0
  PASS  bi_out = 50
========================================
PASS  compute_core: 8/8 checks passed
========================================
```

A VCD waveform file `compute_core.vcd` is produced in the working directory and
can be opened with `gtkwave compute_core.vcd`.

---

## 2. Interface (SPI Slave) Testbench

```bash
cd $REPO/project/m2/tb

iverilog -g2012 -o iface_sim \
    tb_interface.sv \
    ../rtl/interface.sv

vvp iface_sim
```

**Expected output:**
```
--- Write transaction: sending 0xa5c3 ---
  PASS  rx_data = 0xa5c3
--- Read transaction: expecting 0x7b2e on MISO ---
  PASS  miso_word = 0x7b2e
========================================
PASS  interface: 2/2 checks passed
========================================
```

---

## 3. Waveform Image

The representative waveform PNG (`sim/waveform.png`) was generated from the known
test-vector timing using:

```bash
cd $REPO/project/m2/sim
python gen_waveform.py
```

---

## 4. Deviations from M1 Plan

| Item | M1 plan | M2 decision | Reason |
|------|---------|-------------|--------|
| Compute kernel | Full 256-pt FFT (future) | Radix-2 butterfly PE | M2 scope is the core arithmetic unit; full FFT is built from 128 butterfly stages in M3 |
| Interface width | Unspecified | 16-bit SPI word | One INT16 sample per SPI transaction; 256 transactions per FFT window |
| Precision | INT16 planned | INT16 Q1.15 confirmed | Error analysis in `precision.md` confirms 52.7 dB PSNR, above sensor SNR floor |
| Interface protocol | SPI 10 Mbit/s | SPI Mode 0 (CPOL=0, CPHA=0) | No change; mode stated explicitly as required by M2 checklist |

---

## 5. File Map

```
project/m2/
├── rtl/
│   ├── compute_core.sv    ← radix-2 butterfly PE (3-stage pipeline, Q1.15)
│   └── interface.sv       ← SPI slave, Mode 0, 16-bit word (top module: spi_slave)
├── tb/
│   ├── tb_compute_core.sv ← 2 test vectors, 8 checks, PASS
│   └── tb_interface.sv    ← write + read SPI transaction, 2 checks, PASS
├── sim/
│   ├── compute_core_run.log
│   ├── interface_run.log
│   ├── waveform.png
│   └── gen_waveform.py
├── precision.md           ← INT16 Q1.15 rationale + error analysis
└── README.md              ← this file
```
