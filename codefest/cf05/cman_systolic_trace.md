# CMAN CF05 Systolic Array Trace
**Yaqoub Rabiah**

A = [[1, 2], [3, 4]], B = [[5, 6], [7, 8]], expected C = [[19, 22], [43, 50]]

---

## 1. PE Diagram

```
        col 0          col 1
row 0 [ PE[0][0]=5 ][ PE[0][1]=6 ]
row 1 [ PE[1][0]=7 ][ PE[1][1]=8 ]
```

Weights preloaded: PE[i][j] holds B[i][j]. Inputs stream in from the left. Partial sums flow downward.

---

## 2. Cycle-by-Cycle Table

Inputs are staggered by 1 cycle so partial sums from row 0 arrive at row 1 aligned with the correct input.

| Cycle | Row 0 in | Row 1 in | PE[0][0] psum | PE[0][1] psum | PE[1][0] psum | PE[1][1] psum | Output |
|-------|----------|----------|---------------|---------------|---------------|---------------|--------|
| 1     | 1        | 0        | 0 + 1x5 = 5   | 0 + 1x6 = 6   | 0             | 0             |        |
| 2     | 3        | 2        | 0 + 3x5 = 15  | 0 + 3x6 = 18  | 5 + 2x7 = 19  | 6 + 2x8 = 22  | C[0][0]=19, C[0][1]=22 |
| 3     | 0        | 4        | 0             | 0             | 15 + 4x7 = 43 | 18 + 4x8 = 50 | C[1][0]=43, C[1][1]=50 |
| 4     | 0        | 0        | 0             | 0             | 0             | 0             | drain  |

---

## 3. Counts

**(a) Total MAC operations:** 8 (each of the 4 PEs performs 2 MACs)

**(b) Input reuse:** Each input value is reused 2 times (each A[i][k] value is used across 2 columns of B)

**(c) Off-chip memory accesses:**
- A: 4 accesses (each element loaded once)
- B: 4 accesses (preloaded into PEs once)
- C: 4 accesses (each output element written once)

---

## 4. Output-Stationary

In output-stationary dataflow, the partial sums (accumulating output values) stay fixed in each PE, while both input values from A and weights from B stream through.
