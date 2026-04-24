# CF04 CLLM — MAC Code Review
**Course:** ECE 410/510 HW4AI, Spring 2026  
**Student:** Yaqoub Rabiah  
**Date:** 2026-04-23

---

## 1. LLM Attribution

| File | LLM | Model Version |
|------|-----|---------------|
| `codefest/cf04/hdl/mac_llm_A.v` | Claude | Claude Sonnet 4.6 |
| `codefest/cf04/hdl/mac_llm_B.v` | GPT-4o | gpt-4o-2024-11-20 |

---

## 2. Compilation Results

Both files were compiled with:
```
iverilog -g2012 -tnull <file>
```

| File | Exit Code | Errors |
|------|-----------|--------|
| `mac_llm_A.v` | 0 | None |
| `mac_llm_B.v` | 0 | None |

Neither file produced compile-time errors. Issues identified below are design-quality
and spec-compliance problems, not syntax errors.

---

## 3. Simulation Results

Testbench compiled and simulated with:
```
iverilog -g2012 -o mac_sim mac_tb.v mac_correct.v
vvp mac_sim
```

Output:
```
PASS  cycle1 [a=3,b=4]: out = 12
PASS  cycle2 [a=3,b=4]: out = 24
PASS  cycle3 [a=3,b=4]: out = 36
PASS   rst    [out=0] : out = 0
PASS  ycle5 [a=-5,b=2]: out = -10
PASS  ycle6 [a=-5,b=2]: out = -20
-------------------------------
Results: 6 PASS, 0 FAIL
-------------------------------
```

`mac_correct.v` passes all 6 assertions.

---

## 4. Code Review — Issues Found

### Issue 1 — Wrong process type in `mac_llm_B.v` (GPT-4o)

**Offending line (mac_llm_B.v:21):**
```verilog
always @(posedge clk) begin
```

**Why this is wrong:**  
The spec explicitly requires `always_ff`. The plain `always @(posedge clk)` construct
is Verilog-2001 style. In SystemVerilog, `always_ff` tells the compiler/linter that the
block must infer only flip-flops. Tools such as Questa Lint and SpyGlass will raise an
error if a non-flip-flop inference is found inside `always_ff`, catching accidental
latches or combinational paths early. With plain `always`, no such check is enforced —
bugs can silently pass lint. This directly violates the synthesis constraint in the spec.

**Corrected version:**
```systemverilog
always_ff @(posedge clk) begin
```

---

### Issue 2 — Non-SystemVerilog port types (`wire`/`reg`) in `mac_llm_B.v` (GPT-4o)

**Offending lines (mac_llm_B.v:15–19):**
```verilog
input wire clk,
input wire rst,
input wire signed [7:0] a,
input wire signed [7:0] b,
output reg signed [31:0] out
```

**Why this is wrong:**  
The spec requires synthesizable **SystemVerilog**. `wire` and `reg` are Verilog-2001
data types. In SystemVerilog, `logic` is the unified type for both combinational and
sequential signals and should be used for all ports. Using `reg` carries an implicit
semantic of a storage element driven by a procedural block — which is exactly what
`logic` with `always_ff` expresses more cleanly and correctly. Several SV-only linters
will flag `wire`/`reg` in an `.sv` context as a style violation.

**Corrected version:**
```systemverilog
input  logic              clk,
input  logic              rst,
input  logic signed [7:0] a,
input  logic signed [7:0] b,
output logic signed [31:0] out
```

---

### Issue 3 — Implicit sign extension of multiplication product in `mac_llm_B.v` (GPT-4o)

**Offending line (mac_llm_B.v:23):**
```verilog
out <= out + a * b;
```

**Why this is wrong:**  
`a` and `b` are both `signed [7:0]`. Their product `a * b` is a **16-bit signed**
value. When this 16-bit value is added to the 32-bit `out`, sign extension is required
to preserve the sign of the product. While the SystemVerilog LRM specifies that signed
operands should be sign-extended in a mixed-width expression, not all synthesis tools
interpret this consistently — some may zero-extend the 16-bit intermediate value,
turning a negative product (e.g., −10 = 0xFFF6) into a large positive number
(0x0000FFF6 = 65526). This is a classic LLM failure mode listed in the assignment spec
("Sign extension error").

**Example of the hazard:**  
With `a = -5, b = 2`: `a * b = -10` (16-bit: `0xFFF6`).  
- Correct (sign-extend): `0xFFFF_FFF6` = −10 in 32-bit  
- Incorrect (zero-extend): `0x0000_FFF6` = 65526 in 32-bit  

**Corrected version (as used in `mac_correct.v`):**
```systemverilog
logic signed [15:0] product;
always_comb product = a * b;

always_ff @(posedge clk) begin
    if (rst)
        out <= '0;
    else
        out <= out + {{16{product[15]}}, product};  // explicit sign extension
end
```
The bit-replication `{{16{product[15]}}, product}` manually sign-extends the 16-bit
product to 32 bits, making the behavior unambiguous across all tools.

---

### Issue 4 (minor) — Redundant `$signed()` cast in `mac_llm_A.v` (Claude Sonnet 4.6)

**Offending line (mac_llm_A.v:30):**
```systemverilog
out <= out + $signed({{16{product[15]}}, product});
```

**Why this is questionable:**  
`product` is declared `logic signed [15:0]`. The concatenation
`{{16{product[15]}}, product}` produces a 32-bit value. In the context of a `+=`
addition where `out` is `logic signed [31:0]`, this 32-bit value is already treated as
signed because `product` is signed and the replication preserves that. The outer
`$signed()` cast is redundant and adds visual noise that may mislead readers into
thinking an unsigned value is being converted. It is not harmful but indicates the LLM
was not fully confident in SystemVerilog's sign-propagation rules.

**Corrected version (simpler and clearer):**
```systemverilog
out <= out + {{16{product[15]}}, product};
```

---

## 5. Yosys Synthesis — `mac_correct.v`

Command:
```
yosys -p 'read_verilog -sv mac_correct.v; synth; stat'
```

Key output (Yosys 0.33, git sha1 2584903a060):
```
=== mac ===

   Number of wires:                639
   Number of wire bits:            746
   Number of public wires:           5
   Number of public wire bits:      50
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:                696
     $_ANDNOT_                     199
     $_AND_                         48
     $_NAND_                        32
     $_NOR_                         40
     $_NOT_                         13
     $_ORNOT_                       33
     $_OR_                          88
     $_SDFF_PP0_                    32
     $_XNOR_                        36
     $_XOR_                        175

Found and reported 0 problems.
```

**Interpretation:**
- `$_SDFF_PP0_` × 32: 32 synchronous-reset D flip-flops — correct for a 32-bit
  accumulator register with active-high synchronous reset.
- `$_XOR_` × 175 + `$_AND_` × 48 + ...: adder and multiplier logic for `a × b + out`.
- 0 problems reported — module synthesizes cleanly with no warnings.

---

## 6. Summary

| Item | Status |
|------|--------|
| `mac_llm_A.v` compiles | PASS |
| `mac_llm_B.v` compiles | PASS |
| `mac_correct.v` simulation (6/6) | PASS |
| `mac_correct.v` yosys synthesis | PASS (0 problems) |
| Issues documented | 4 (3 in LLM B, 1 minor in LLM A) |
