# Interface Selection
## ECE 410/510 Spring 2026 | Yaqoub Rabiah
## Project: 256-Point FFT Vibration Anomaly Detection Accelerator

---

## 1. Host Platform

**Assumed host:** MCU-class microcontroller (e.g., ARM Cortex-M4/M33)
mounted on the same PCB as the vibration sensor and chiplet. The MCU
receives raw INT16 samples from the MEMS accelerometer over I²C/analog,
assembles 256-sample windows, and transfers them to the FFT chiplet.
The MCU also receives the 1-bit alarm flag back from the chiplet and
triggers any system-level response (relay, UART alert, LED).

---

## 2. Interface Chosen: SPI (Serial Peripheral Interface)

**Selected interface:** SPI at 10 Mbit/s (Mode 0, CPOL=0 CPHA=0)

**SPI lines exposed by chiplet:**
| Signal | Direction     | Function                    |
|--------|---------------|-----------------------------|
| MOSI   | MCU → Chiplet | Sample window data in        |
| MISO   | Chiplet → MCU | Alarm flag / status byte out |
| SCLK   | MCU → Chiplet | Clock (up to 10 MHz)         |
| CS_N   | MCU → Chiplet | Chip select (active low)     |

---

## 3. Bandwidth Requirement Calculation

One inference transaction transfers one window of 256 INT16 samples:

```
Payload per window = 256 samples × 2 bytes/sample = 512 bytes
Window period      = 256 samples / 10,000 Hz      = 25.6 ms
Required bandwidth = 512 bytes / 25.6 ms           = 20,000 B/s
                   = 160,000 bit/s = 160 kbit/s
```

Adding SPI framing overhead (8-bit CS assertion, 1 byte status return):

```
Total bits per window ≈ (512 + 1) × 8 = 4,104 bits
Required rate         = 4,104 bits / 25.6 ms ≈ 160.3 kbit/s
```

---

## 4. Interface Bandwidth vs. Requirement

| Parameter                  | Value           |
|----------------------------|-----------------|
| Required bandwidth         | 160.3 kbit/s    |
| SPI rated bandwidth        | 10,000 kbit/s   |
| Headroom                   | **62.4×**       |
| Transfer time per window   | 4,104 bits / 10 Mbit/s = **0.41 ms** |
| Idle time per window period| 25.6 ms − 0.41 ms = **25.19 ms**    |

**The accelerator is NOT interface-bound.** SPI at 10 Mbit/s provides
62.4× more bandwidth than the kernel requires. The interface would only
become the bottleneck if the window size were increased beyond ~32,000
samples or the sampling rate raised above 625 kHz — neither is in scope.

---

## 5. Roofline Position of the Interface

The effective interface throughput in compute terms:

```
Interface delivers  : 512 bytes / 0.41 ms = 1.25 MB/s = 0.00125 GB/s
Kernel FLOPs        : 10,240 FLOPs per window
Interface AI ceiling: 10,240 FLOPs / 512 bytes = 20 FLOP/byte
```

The kernel's arithmetic intensity (3.33 FLOP/byte) is well below the
interface AI ceiling (20 FLOP/byte), confirming the design is not
interface-bound on the roofline.

---

## 6. Justification for SPI over Other Interfaces

| Interface   | Bandwidth     | Verdict for this design                        |
|-------------|---------------|------------------------------------------------|
| I²C         | ≤ 3.4 Mbit/s  | Sufficient (21× headroom) but no standard MCU SPI |
| **SPI**     | **10 Mbit/s** | **Chosen — simple, universal, 62× headroom**  |
| AXI4-Lite   | Varies        | Overkill for MCU host; requires FPGA SoC       |
| AXI4 Stream | High          | Overkill; no MCU-native support                |
| PCIe        | GB/s range    | Far exceeds need; major complexity             |

SPI is the natural fit for an MCU-class host delivering 512-byte
windows at a 39 Hz window rate. It is universally supported on
embedded MCUs, trivial to implement and verify in HDL, and provides
ample bandwidth headroom without the complexity of a bus fabric.
