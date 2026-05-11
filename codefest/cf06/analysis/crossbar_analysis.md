# Codefest 6 — 4×4 Binary-Weight Crossbar MAC Unit

**Student:** Yaqoub Rabiah  
**Date:** 2026-05-10  
**LLM used:** Claude Sonnet 4.6

---

## Task 1 — LLM Prompt and Module Design

### LLM Prompt Used

> "Generate a synthesizable SystemVerilog module for a 4×4 binary-weight crossbar MAC unit.
> Requirements:
> - 4 signed 8-bit inputs, 4 signed 10-bit outputs (10 bits needed because max |sum| = 4 × 127 = 508)
> - Weights are binary: each weight[i][j] is either +1 or −1, stored as a 1-bit register (1 = +1, 0 = −1)
> - A 4×4 register file holds the weight matrix; it can be loaded by asserting load_w for one cycle
> - Each clock cycle when valid_in=1, compute: out[j] = Σ_{i=0..3} (weight[i][j] ? +in[i] : −in[i])
> - Registered output (1-cycle latency), synchronous active-low reset
> - Use valid_in / valid_out handshaking"

### Module Design — How the Crossbar Computes `out[j]`

The crossbar is modelled after an analog current-summing crossbar array. In hardware, each row wire carries the input signal, each column wire accumulates contributions, and each intersection node has a conductance set to +G or −G (binary weight).

In this digital implementation:

```
         out[0]   out[1]   out[2]   out[3]
          |        |        |        |
in[0] ── ⊕W[0,0] ⊖W[0,1] ⊕W[0,2] ⊖W[0,3]
          |        |        |        |
in[1] ── ⊖W[1,0] ⊕W[1,1] ⊖W[1,2] ⊕W[1,3]
          |        |        |        |
in[2] ── ⊕W[2,0] ⊕W[2,1] ⊖W[2,2] ⊖W[2,3]
          |        |        |        |
in[3] ── ⊖W[3,0] ⊖W[3,1] ⊕W[3,2] ⊕W[3,3]
```

**Step-by-step computation for output column j:**

1. **Sign-extension**: Each 8-bit signed input `data_in[i]` is sign-extended to 10 bits
   (`e_i = {{2{data_in[i][7]}}, data_in[i]}`), giving range −512…+511.

2. **Binary multiply**: Each weight intersection computes a ±1 multiplication using a
   conditional negation — no multiplier required:
   ```
   term[i][j] = weight[i][j] ? +e_i : −e_i
   ```

3. **Accumulation**: All four terms for column j are added (combinationally):
   ```
   out[j] = term[0][j] + term[1][j] + term[2][j] + term[3][j]
   ```
   Maximum magnitude = 4 × 127 = 508, which fits in 10-bit signed (range −512…+511).

4. **Registration**: The sum is registered on the rising edge of `clk` when `valid_in=1`,
   producing a 1-cycle pipeline latency. `valid_out` is the registered `valid_in`.

**Weight storage**: `weight[i]` is a 4-bit register; bit `j` encodes `weight[i][j]`.
Loading is done by asserting `load_w=1` for one cycle with `w_row[i]` valid.

**Implementation note**: iverilog 12.0 does not support driving elements of an unpacked
output port array from `always_ff`. The workaround used here is to keep internal scalar
registers (`do0_r … do3_r`) and drive a packed `output logic [3:0][9:0] data_out` via
continuous `assign` — confirmed working by a minimal reproduce test.

---

## Task 2 — Weight Matrix and Test Vectors

### Weight Matrix Loaded

| Row i (input i) | j=0 | j=1 | j=2 | j=3 | `w_row[i]` encoding |
|-----------------|-----|-----|-----|-----|---------------------|
| i=0             | +1  | −1  | +1  | −1  | `4'b0101`           |
| i=1             | −1  | +1  | −1  | +1  | `4'b1010`           |
| i=2             | +1  | +1  | −1  | −1  | `4'b0011`           |
| i=3             | −1  | −1  | +1  | +1  | `4'b1100`           |

Encoding rule: bit `j` of `w_row[i]` = 1 → weight[i][j] = +1; bit = 0 → weight[i][j] = −1.

### Hand-Calculated Expected Outputs

**Formula**: `out[j] = Σ_i (weight[i][j] × in[i])`  
Weight sign: w[i][j]=1 → ×(+1), w[i][j]=0 → ×(−1)

#### TV1: in = [1, −1, 1, −1]

| Output | Expansion | Result |
|--------|-----------|--------|
| out[0] | (+1)(1) + (−1)(−1) + (+1)(1) + (−1)(−1) | 1+1+1+1 = **4** |
| out[1] | (−1)(1) + (+1)(−1) + (+1)(1) + (−1)(−1) | −1−1+1+1 = **0** |
| out[2] | (+1)(1) + (−1)(−1) + (−1)(1) + (+1)(−1) | 1+1−1−1 = **0** |
| out[3] | (−1)(1) + (+1)(−1) + (−1)(1) + (+1)(−1) | −1−1−1−1 = **−4** |

Expected: **[4, 0, 0, −4]**

#### TV2: in = [2, 3, −1, 2]

| Output | Expansion | Result |
|--------|-----------|--------|
| out[0] | (+1)(2) + (−1)(3) + (+1)(−1) + (−1)(2) | 2−3−1−2 = **−4** |
| out[1] | (−1)(2) + (+1)(3) + (+1)(−1) + (−1)(2) | −2+3−1−2 = **−2** |
| out[2] | (+1)(2) + (−1)(3) + (−1)(−1) + (+1)(2) | 2−3+1+2 = **2** |
| out[3] | (−1)(2) + (+1)(3) + (−1)(−1) + (+1)(2) | −2+3+1+2 = **4** |

Expected: **[−4, −2, 2, 4]**

#### TV3: in = [0, 0, 0, 0]

All outputs = 0 regardless of weights (zero inputs). Expected: **[0, 0, 0, 0]**

---

## Task 3 — Simulation Results

**Command:**
```bash
cd /mnt/c/Users/yaqou/ECE\ 410/ECE-410-Yaqoub-Rabiah/codefest/cf06
iverilog -g2012 -o sim/crossbar_mac.vvp hdl/crossbar_mac.sv tb/tb_crossbar_mac.sv
vvp sim/crossbar_mac.vvp
```

**Output:**
```
PASS [TV1 in=[1,-1,1,-1]]: out=[4,0,0,-4]
PASS [TV2 in=[2,3,-1,2]]: out=[-4,-2,2,4]
PASS [TV3 in=[0,0,0,0]]: out=[0,0,0,0]

3/3 tests PASS
```

---

## Task 4 — Verification

**Did simulation results match hand-calculated outputs? YES — 3/3 PASS**

| Test Vector | Hand Calc | Simulation | Match? |
|-------------|-----------|------------|--------|
| TV1: [1,−1,1,−1] | [4, 0, 0, −4] | [4, 0, 0, −4] | ✓ |
| TV2: [2,3,−1,2] | [−4, −2, 2, 4] | [−4, −2, 2, 4] | ✓ |
| TV3: [0,0,0,0] | [0, 0, 0, 0] | [0, 0, 0, 0] | ✓ |

All three test vectors match exactly. The ternary-sign crossbar computes the correct
signed MAC accumulation using only additions and conditional negations — no multipliers.

---

## Files

| File | Description |
|------|-------------|
| `hdl/crossbar_mac.sv` | LLM-generated 4×4 binary-weight crossbar MAC (Claude Sonnet 4.6) |
| `tb/tb_crossbar_mac.sv` | Testbench: 3 test vectors with hand-verified expected outputs |
| `sim/crossbar_mac_run.log` | Simulation log: 3/3 PASS |
| `analysis/crossbar_analysis.md` | This document |
