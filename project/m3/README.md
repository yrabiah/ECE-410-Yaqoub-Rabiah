# Milestone 3 — Integration and Synthesis

**Student:** Yaqoub Rabiah | **Course:** ECE 410/510 HW4AI, Spring 2026  
**Due:** May 24, 2026 | **Design:** 256-pt FFT Vibration Anomaly Detection Accelerator

---

## File Catalog

| Path | Description |
|------|-------------|
| `rtl/top.sv` | Integrated top module: instantiates `spi_slave` + `compute_core`, wired through a 12-state FSM glue layer. Only SPI pins are exposed externally. |
| `tb/tb_top.sv` | End-to-end co-simulation testbench. Drives SPI Mode-0 master transactions only — no direct compute_core port access. Tests butterfly A=B=100, W=0.5 → A′=150, B′=50. |
| `sim/cosim_run.log` | Simulation transcript from `vvp sim/cosim.vvp`. Shows 4/4 PASS and final PASS line. |
| `sim/cosim_waveform.png` | Annotated waveform with three regions: SPI WRITE phase, internal compute phase (valid_in→pipeline→valid_out), SPI READ phase. |
| `sim/gen_waveform.py` | Python/matplotlib script that generated `cosim_waveform.png`. |
| `synth/config.json` | OpenLane 2 configuration (design name, source files, clock period, PDK). Includes note on yosys -y flag issue that prevented full OpenLane run. |
| `synth/openlane_run.log` | Full Yosys 0.33 stdout/stderr for the synthesis run (read → synth → dfflibmap → abc → stat). |
| `synth/area_report.txt` | Total cell area (55,532 µm²), cell count (7,089), DFF count (517), full cell-type breakdown. |
| `synth/timing_report.txt` | Critical path estimate (7.2–8.4 ns, source: Stage 1 product register, sink: Stage 2 register), estimated slack (+1.6–3.1 ns at 10 ns). |
| `synth/power_report.txt` | Estimated power ~1.81 mW at 100 MHz / 1.8 V; documents why full OpenROAD power analysis is deferred to M4. |
| `synth/critical_path.md` | Identifies start/end registers, logic stages, cell types, and what would shorten the path. |
| `synthesis_notes.md` | ≥500-word narrative: what worked, what did not (OpenLane -y flag), synthesis results, scope status, M4 plan. |

---

## Co-Simulation Reproduction

**Simulator:** iverilog 12.0 / vvp (installed in WSL Ubuntu)  
**SystemVerilog flag:** `-g2012`

```bash
# From project/m3/
iverilog -g2012 -o sim/cosim.vvp \
  ../m2/rtl/compute_core.sv \
  ../m2/rtl/interface.sv \
  rtl/top.sv \
  tb/tb_top.sv

vvp sim/cosim.vvp
```

Expected output:
```
4/4 checks PASS
PASS — end-to-end co-simulation PASSED
```

---

## Synthesis Reproduction

**Tool:** Yosys 0.33, sky130_fd_sc_hd TT 25°C 1.8V liberty  
**PDK:** sky130A, installed via `volare enable --pdk sky130 bdc9412b3e...`  
**OpenLane 2 version:** 2.3.10 (pip install openlane==2.3.10)  
**OpenLane config:** `synth/config.json`  
**Environment variables:** `PDK_ROOT=$HOME/pdk`

Note: OpenLane 2.3.10 aborts at the JsonHeader step with system Yosys 0.33 (missing
`-y` flag). Synthesis was run directly with Yosys:

```bash
export PDK_ROOT=$HOME/pdk
LIB=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

yosys << 'EOF'
read_verilog -sv ../m2/rtl/compute_core.sv
read_verilog -sv ../m2/rtl/interface.sv
read_verilog -sv rtl/top.sv
synth -top top -flatten
dfflibmap -liberty $LIB
abc -liberty $LIB -D 10000
stat -liberty $LIB
EOF
```

---

## Key Results

| Metric | Value |
|--------|-------|
| Co-simulation | 4/4 PASS |
| Total cells | 7,089 |
| Chip area | 55,532 µm² |
| Flip-flops | 517 |
| Clock target | 10 ns (100 MHz) |
| Critical path (est.) | 7.2–8.4 ns (Stage 1 multiplier) |
| Est. slack at 10 ns | +1.6–3.1 ns |
| Est. power | ~1.81 mW at 100 MHz / 1.8 V |
| FFT throughput (projected) | 781,250 windows/sec (23× target) |
