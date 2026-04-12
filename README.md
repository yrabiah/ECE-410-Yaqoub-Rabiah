# ECE 410/510 — HW4AI Spring 2026
### Yaqoub Rabiah | Portland State University

**Course:** ECE 410/510 — Hardware for Artificial Intelligence and Machine Learning, Spring 2026
**Instructor:** Christof Teuscher

---

## Project: 256-Point FFT Vibration Anomaly Detection Accelerator

A synthesizable hardware chiplet that accelerates real-time bearing fault detection by computing a 256-point FFT on raw accelerometer windows in custom digital logic. The chiplet connects to an MCU host over SPI, eliminates Python/NumPy overhead from the inner loop, and targets a >100× throughput improvement over the software baseline.

**Target kernel:** Radix-2 Cooley-Tukey FFT butterfly (256-point, fixed-point)
**Interface:** SPI at 10 Mbit/s
**HDL:** SystemVerilog, synthesized with OpenLane 2
**Software baseline:** 29.43 µs/window, 33,977 windows/sec on Intel Core Ultra 7 155U

---

## Repository Structure

```
├── project/
│   ├── heilmeier.md              ← Project goals and approach (Heilmeier Q1–Q3)
│   ├── algorithm_diagram.png     ← High-level algorithm block diagram
│   └── m1/
│       ├── sw_baseline.md        ← Software benchmark (M4 comparison point)
│       ├── interface_selection.md ← SPI interface justification + bandwidth analysis
│       └── system_diagram.png    ← Chiplet system block diagram
└── codefest/
    ├── cf01/
    │   ├── cman_workload_accounting.pdf ← Workload accounting (CMAN)
    │   └── profiling/
    │       ├── resnet18_profile.txt     ← ResNet-18 torchinfo output
    │       └── resnet18_analysis.md     ← Top-5 MAC table + arithmetic intensity
    └── cf02/
        ├── cman_roofline.pdf            ← Roofline construction (CMAN)
        ├── profiling/
        │   ├── project_profile.txt      ← cProfile output for FFT pipeline
        │   ├── roofline_project.png     ← Roofline: SW kernel + HW target
        │   └── fft_profile.py           ← Profiling script
        └── analysis/
            ├── ai_calculation.md        ← FLOPs/bytes/AI calculation
            └── partition_rationale.md   ← HW/SW partition proposal
```

---

## Milestones

| Milestone | Due | Status |
|-----------|-----|--------|
| M1 — Profiling, roofline, interface, SW baseline | Sun Apr 12 | ✅ Submitted |
| M2 — HDL compute core + interface testbench | Sun May 3 | Pending |
| M3 — OpenLane 2 synthesis + integration | Sun May 24 | Pending |
| M4 — Full package: synthesis, benchmark, report | Sun Jun 7 | Pending |
