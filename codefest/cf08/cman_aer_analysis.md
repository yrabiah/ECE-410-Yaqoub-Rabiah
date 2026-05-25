# CMAN AER Analysis
**Yaqoub Rabiah**

N = 1024 neurons, f = 50 Hz mean firing rate

---

## 1. Mean Aggregate Spike Rate

R = N x f = 1024 x 50 = **51,200 spikes/sec**

---

## 2. Mean AER Bandwidth

Each AER packet = 10-bit address + 6-bit timestamp + 4-bit framing = 20 bits/packet

B = R x 20 = 51,200 x 20 = 1,024,000 bits/sec = **1.024 Mbit/s**

---

## 3. Interface Comparison

| Interface | Max Bandwidth | Sufficient? |
|-----------|--------------|-------------|
| SPI | 50 Mbit/s | Yes |
| I2C | 3.4 Mbit/s | Yes |
| AXI4-Lite | 100 Mbit/s | Yes |

Mean bandwidth is only 1.024 Mbit/s, so all three interfaces can sustain it. The lowest-complexity interface that suffices is **I2C**, since 1.024 Mbit/s is within its 3.4 Mbit/s limit and it requires fewer pins and simpler protocol logic than SPI or AXI4-Lite.

---

## 4. Burst Analysis

25% of 1024 neurons fire within a 1 ms window:

Burst neurons = 256
Peak spike rate = 256 / 0.001 = 256,000 spikes/sec
Peak bandwidth = 256,000 x 20 = 5,120,000 bits/sec = **5.12 Mbit/s**

Burst-to-mean ratio = 5.12 / 1.024 = **5x**

I2C max is 3.4 Mbit/s, which cannot absorb the 5.12 Mbit/s peak. Buffering is required. Excess data during the burst window = (5.12 - 1.024) Mbit/s x 1 ms = ~4096 bits, requiring a buffer of roughly **205 packets** deep.

---

## 5. Frame-Based Comparison

Frame-based bandwidth: 1 bit per neuron per 1 ms = 1024 / 0.001 = 1,024,000 bits/sec = **1.024 Mbit/s**

AER-to-frame ratio at f = 50 Hz: 1.024 / 1.024 = **1.0**

Setting AER bandwidth equal to frame bandwidth:
N x f_cross x 20 = N x 1000
f_cross x 20 = 1000
**f_crossover = 50 Hz**

At the given firing rate of 50 Hz, AER and frame-based bandwidths are exactly equal. AER is the right choice when firing rates are below 50 Hz because it only sends data when neurons fire, saving bandwidth in sparse activity regimes.
