# ResNet-18 Analysis — ECE 410/510 Spring 2026

## Top-5 Layers by MAC Count

| Rank | Layer Name              | Layer Type | MACs        | Parameters |
|------|-------------------------|------------|-------------|------------|
| 1    | conv1 (1-1)             | Conv2d     | 118,013,952 | 9,408      |
| 2    | layer1.0.conv1 (3-1)    | Conv2d     | 115,605,504 | 36,864     |
| 3    | layer1.0.conv2 (3-4)    | Conv2d     | 115,605,504 | 36,864     |
| 4    | layer1.1.conv1 (3-7)    | Conv2d     | 115,605,504 | 36,864     |
| 5    | layer1.1.conv2 (3-10)   | Conv2d     | 115,605,504 | 36,864     |

---

## Arithmetic Intensity — Most MAC-Intensive Layer

**Layer:** `conv1` (1-1) — Conv2d, kernel 7×7, in\_channels=3, out\_channels=64, output=112×112, no bias

### Calculation

**FLOPs:**
```
FLOPs = 2 × MACs = 2 × 118,013,952 = 236,027,904
```

**Weight memory (FP32):**
```
weight_bytes = 9,408 params × 4 bytes = 37,632 bytes
```

**Activation memory (FP32):**
```
input_bytes  = 3 × 224 × 224 × 4 = 602,112 bytes
output_bytes = 64 × 112 × 112 × 4 = 3,211,264 bytes
activation_bytes = 602,112 + 3,211,264 = 3,813,376 bytes
```

**Arithmetic Intensity:**
```
AI = FLOPs / (weight_bytes + activation_bytes)
   = 236,027,904 / (37,632 + 3,813,376)
   = 236,027,904 / 3,851,008
   ≈ 61.29 FLOP/byte
```
