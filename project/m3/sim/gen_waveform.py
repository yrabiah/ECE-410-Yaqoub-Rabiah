"""
gen_waveform.py — Generate annotated co-simulation waveform for M3
Produces cosim_waveform.png showing:
  Region 1: SPI WRITE phase (WRITE_CMD + 6 operand words)
  Region 2: Internal compute phase (valid_in pulse, 3-cycle pipeline, valid_out)
  Region 3: SPI READ phase (READ_CMD + 3 NOPs returning ar/ai/br/bi)
"""

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

# ── Colour palette ──────────────────────────────────────────────────────────
CLK_CLR   = '#2c3e50'
CS_CLR    = '#e74c3c'
SCLK_CLR  = '#2980b9'
MOSI_CLR  = '#27ae60'
MISO_CLR  = '#8e44ad'
VIN_CLR   = '#f39c12'
VOUT_CLR  = '#16a085'
REG1 = '#ffeeba'   # write region
REG2 = '#d4edda'   # compute region
REG3 = '#cce5ff'   # read region

def make_clock(n):
    t = np.arange(n)
    return t, (t % 2).astype(float)

def step_signal(times, values, n_total):
    """Build a step-function signal from (time, value) pairs."""
    sig = np.zeros(n_total)
    for i, (t, v) in enumerate(zip(times, values)):
        end = times[i+1] if i+1 < len(times) else n_total
        sig[t:end] = v
    return sig

# ── Time axis (arbitrary units = system clock cycles, condensed) ─────────────
# We show a representative subset of the simulation for clarity.
# SPI half-period = 8 sys clocks → each SPI bit = 16 sys clocks
# One 16-bit word transaction ≈ 16*16 + 32 (gap) = 288 cycles (too many to show all)
# Instead we show schematic timing at 1 unit = 1 SPI bit-period.

N = 200   # display units

clk_t = np.linspace(0, N, N*4)
clk_v = 0.5 + 0.5*np.sign(np.sin(2*np.pi*clk_t/2))

t = np.linspace(0, N, N*4)

# ── cs_n: WRITE phase 0-70, COMPUTE gap 70-80, READ phase 80-170, idle 170+ ─
cs_n_times  = [0, 2, 12, 14, 24, 26, 36, 38, 48, 50, 60, 62, 72,
               80, 90, 102, 114, 126, 138, 170, N]
cs_n_vals   = [1, 0, 1,  0,  1,  0,  1,  0,  1,  0,  1,  0,  1,
               1, 0, 1,  0,  1,  0,  1]

cs_n_sig = step_signal(cs_n_times, cs_n_vals, N*4)

# ── SCLK: active only when cs_n=0, at ~8x slower than sys clk ──────────────
sclk_sig = np.zeros(N*4)
for i in range(len(cs_n_times)-1):
    t0 = cs_n_times[i]; t1 = cs_n_times[i+1]
    v  = cs_n_vals[i]
    if v == 0:  # cs_n low → SPI active
        idx0 = int(t0 * 4); idx1 = int(t1 * 4)
        period = max(1, (idx1-idx0)//8)
        for j in range(idx0, idx1):
            sclk_sig[j] = 0.5 + 0.5*np.sign(np.sin(np.pi*(j-idx0)/period))

# ── MOSI: schematic labels during write transactions ─────────────────────────
# Just draw a mid-level "data bus" representation
mosi_sig = np.zeros(N*4)
write_windows = [(2,12,'WR_CMD\n0x0001'), (14,24,'ar=0x0064'),
                 (26,36,'ai=0x0000'), (38,48,'br=0x0064'),
                 (50,60,'bi=0x0000'), (62,72,'wr=0x4000')]
for (t0,t1,_) in write_windows:
    mosi_sig[int(t0*4):int(t1*4)] = 0.5

# ── MISO: schematic labels during read transactions ──────────────────────────
miso_sig = np.zeros(N*4)
read_windows = [(90,102,'ar=0x0096\n(150)'), (114,126,'ai=0x0000\n(0)'),
                (126,138,'br=0x0032\n(50)'), (138,150,'bi=0x0000\n(0)')]
for (t0,t1,_) in read_windows:
    miso_sig[int(t0*4):int(t1*4)] = 0.5

# wi word (7th write)
mosi_sig[int(72*4):int(78*4)] = 0.5

# ── valid_in pulse (1 cycle after wi rx_valid) ───────────────────────────────
vin_sig = np.zeros(N*4)
vin_sig[int(79*4):int(80*4)] = 1.0

# ── valid_out pulse (3 pipeline stages later) ────────────────────────────────
vout_sig = np.zeros(N*4)
vout_sig[int(82*4):int(83*4)] = 1.0

x = np.linspace(0, N, N*4)

# ── Plot ─────────────────────────────────────────────────────────────────────
fig, axes = plt.subplots(7, 1, figsize=(16, 10), sharex=True)
fig.patch.set_facecolor('#f8f9fa')

rows = [
    (axes[0], clk_t,  clk_v,   CLK_CLR,  'CLK',      0.6),
    (axes[1], x,      cs_n_sig, CS_CLR,   'CS_n',     0.6),
    (axes[2], x,      sclk_sig, SCLK_CLR, 'SCLK',     0.6),
    (axes[3], x,      mosi_sig, MOSI_CLR, 'MOSI',     0.6),
    (axes[4], x,      miso_sig, MISO_CLR, 'MISO',     0.6),
    (axes[5], x,      vin_sig,  VIN_CLR,  'valid_in', 0.6),
    (axes[6], x,      vout_sig, VOUT_CLR, 'valid_out',0.6),
]

for ax, xt, sig, clr, label, lw in rows:
    ax.fill_between(xt, sig, alpha=0.25, color=clr)
    ax.plot(xt, sig, color=clr, linewidth=lw)
    ax.set_ylim(-0.2, 1.4)
    ax.set_ylabel(label, fontsize=9, rotation=0, labelpad=55, va='center')
    ax.set_yticks([0, 1])
    ax.yaxis.set_tick_params(labelsize=7)
    ax.grid(axis='x', linestyle='--', linewidth=0.4, alpha=0.5)
    ax.set_facecolor('#fdfdfd')
    for spine in ax.spines.values():
        spine.set_linewidth(0.5)

# ── Region shading ────────────────────────────────────────────────────────────
regions = [
    (0,  78,  REG1, 'Region 1: SPI WRITE\n(WRITE_CMD + 6 operands)'),
    (78, 90,  REG2, 'Region 2: Compute\n(valid_in→pipeline→valid_out)'),
    (90, N,   REG3, 'Region 3: SPI READ\n(READ_CMD + ar/ai/br/bi)'),
]
for ax, _, _, _, _, _ in rows:
    for (x0, x1, colour, label) in regions:
        ax.axvspan(x0, x1, alpha=0.12, color=colour, zorder=0)

# Annotate regions on top axis
for (x0, x1, colour, label) in regions:
    axes[0].text((x0+x1)/2, 1.25, label, ha='center', va='center',
                 fontsize=8, color='#333',
                 bbox=dict(boxstyle='round,pad=0.3', fc=colour, ec='#999', alpha=0.8))

# Annotate MOSI word labels
for (t0, t1, lbl) in write_windows:
    axes[3].text((t0+t1)/2, 0.5, lbl, ha='center', va='center',
                 fontsize=6.5, color='#155724',
                 bbox=dict(boxstyle='round,pad=0.15', fc='#d4edda', ec='none', alpha=0.8))

# wi word
axes[3].text(75, 0.5, 'wi=0x0000', ha='center', va='center', fontsize=6.5,
             color='#155724',
             bbox=dict(boxstyle='round,pad=0.15', fc='#d4edda', ec='none', alpha=0.8))

# Annotate MISO word labels
for (t0, t1, lbl) in read_windows:
    axes[4].text((t0+t1)/2, 0.5, lbl, ha='center', va='center',
                 fontsize=6.5, color='#4a235a',
                 bbox=dict(boxstyle='round,pad=0.15', fc='#e8daef', ec='none', alpha=0.8))

# Annotate READ_CMD
axes[3].text(96, 0.5, 'READ_CMD\n0x0002', ha='center', va='center', fontsize=6.5,
             color='#155724',
             bbox=dict(boxstyle='round,pad=0.15', fc='#d4edda', ec='none', alpha=0.8))

axes[-1].set_xlabel('Simulation time (schematic, 1 unit ≈ SPI bit period)', fontsize=9)

fig.suptitle(
    'M3 End-to-End Co-Simulation Waveform\n'
    '256-pt FFT Butterfly via SPI: A=B=100, W=0.5 → A′=150, B′=50',
    fontsize=11, fontweight='bold', color='#1a1a2e'
)

plt.tight_layout(rect=[0, 0, 1, 0.95])
plt.savefig('cosim_waveform.png', dpi=150, bbox_inches='tight',
            facecolor=fig.get_facecolor())
print("Saved cosim_waveform.png")
