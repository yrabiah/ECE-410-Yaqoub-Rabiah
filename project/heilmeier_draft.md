# Heilmeier Catechism — Project Draft
## ECE 410/510 Spring 2026 | Yaqoub Rabiah
## Project: Vibration Anomaly Detection Accelerator

---

## Q1: What are you trying to do?

I am building a small hardware chip that continuously monitors the vibration of a rotating 
machine like a motor, pump, or bearing and raises an alarm the moment the vibration pattern 
starts to look abnormal. The chip sits directly on the machine, reads data from a vibration 
sensor many thousands of times per second, and computes in real time whether the machine is 
behaving normally or showing early signs of failure. The goal is to catch a failing bearing 
or an unbalanced shaft before it causes a breakdown, using a chip that is cheap, small, and 
draws very little power so it can run continuously for years without human attention.

---

## Q2: How is it done today, and what are the limits of current practice?

Vibration-based predictive maintenance is handled today in one of two ways. The first is 
periodic manual inspection: a technician visits the machine on a schedule, attaches a handheld 
vibration meter, and compares readings against known-good baselines. The second is a continuous 
monitoring system using a general-purpose data acquisition board or an industrial IoT gateway 
that streams raw sensor data over a network to a cloud server, where the analysis runs on a CPU 
or GPU.

The limits of current practice are:

- **Latency:** Cloud-based analysis introduces seconds to minutes of delay. A bearing can fail 
  catastrophically in under a second once it enters a failure mode. Edge inference eliminates 
  this gap entirely.

- **Cost and complexity:** Industrial IoT gateways and DAQ boards cost hundreds to thousands of 
  dollars per installation point. A single factory floor may have hundreds of motors. A custom 
  low-cost chiplet changes the economics.

- **Power and connectivity:** Continuous wireless streaming of raw high-frequency vibration data 
  (sampled at 10-50 kHz) consumes significant radio bandwidth and power. A local inference chip 
  only transmits an alarm flag, reducing both.

- **Manual inspection:** Periodic manual checks miss faults that develop between visits. Continuous 
  monitoring is the only way to catch early-stage degradation.

---

## Q3: What is new in your approach, and why do you think it will succeed?

The new element is a hardware accelerator chiplet that computes a fixed-size Fast Fourier Transform 
(FFT) on short windows of raw accelerometer data and compares the resulting frequency spectrum 
against a stored normal-operation profile entirely in custom digital logic, with no CPU involved in 
the inner loop.

Specifically:
- Raw accelerometer samples arrive in a fixed-length window (256 samples at 10 kHz = 25.6 ms per window).

- The chiplet computes a 256-point FFT using a hardware butterfly pipeline. The FFT converts the 
  time-domain vibration signal into a frequency spectrum, where bearing faults, imbalance, and 
  misalignment each produce characteristic frequency peaks.

- The magnitude spectrum is compared against a stored baseline profile using a threshold comparison per frequency bin.

- If any bin exceeds its threshold, the chiplet asserts an alarm signal to the host.

Why it will succeed:
1. **The FFT butterfly maps directly to hardware.** A 256-point fixed-point FFT fits in a small 
   area, has well-understood arithmetic intensity, and synthesizes cleanly with OpenLane 2.

2. **The compute is genuinely dominant.** For a 256-point FFT, the operation count is 
   N/2 x log2(N) = 1024 complex multiply-adds per window. This is a dense, regular, repeating 
   computation.

3. **The interface is well-matched.** SPI is appropriate for an MCU-class host delivering one window
    of samples at a time. At 256 samples x 2 bytes = 512 bytes per window, SPI at 10 Mbit/s transfers 
   one window in ~0.4 ms, well within the 25.6 ms window period.

4. **The scope is controlled.** The deliverable is a single FFT + comparison pipeline, not a full ML 
   model. This is achievable within one term and produces a result that is easy to benchmark against 
   a NumPy software baseline.

5. **Public datasets exist.** The CWRU Bearing Dataset (Case Western Reserve University) provides 
   labeled accelerometer recordings of normal and faulty bearings, giving a reproducible software 
   baseline and ground truth for verifying detection accuracy.
