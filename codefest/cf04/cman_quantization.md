# CMAN CF04 Quantization
**Yaqoub Rabiah**

---

## 1. Scale Factor

max(|W|) = 2.31

S = 2.31 / 127 = **0.018189**

---

## 2. Quantized INT8 Matrix W_q

W_q = round(W / S), clamped to [-128, 127]:

```
[  47,  -66,   19,  115 ]
[  -4,   50, -103,    7 ]
[  85,    2,  -24, -127 ]
[ -10,   57,   42,   30 ]
```

---

## 3. Dequantized FP32 Matrix W_deq

W_deq = W_q x S:

```
[  0.8549, -1.2005,  0.3456,  2.0917 ]
[ -0.0728,  0.9094, -1.8735,  0.1273 ]
[  1.5461,  0.0364, -0.4365, -2.3100 ]
[ -0.1819,  1.0368,  0.7639,  0.5457 ]
```

---

## 4. Error Analysis

|W - W_deq|:

```
[ 0.004882, 0.000472, 0.005591, 0.008268 ]
[ 0.002756, 0.000551, 0.006535, 0.007323 ]
[ 0.003937, 0.006378, 0.003465, 0.000000 ]
[ 0.001890, 0.006772, 0.006063, 0.004331 ]
```

**Largest error:** 0.008268 at position (row 0, col 3), element W[0][3] = 2.10

**MAE:** 0.004326

---

## 5. Bad Scale Experiment (S_bad = 0.01)

W_q_bad (clamped):

```
[  85, -120,   34,  127 ]
[  -7,   91, -128,   12 ]
[ 127,    3,  -44, -128 ]
[ -18,  103,   77,   55 ]
```

W_deq_bad:

```
[  0.85, -1.20,  0.34,  1.27 ]
[ -0.07,  0.91, -1.28,  0.12 ]
[  1.27,  0.03, -0.44, -1.28 ]
[ -0.18,  1.03,  0.77,  0.55 ]
```

**MAE_bad = 0.171250**

**Explanation:** S too small causes large values to saturate at the INT8 limits, introducing unrecoverable clipping errors.
