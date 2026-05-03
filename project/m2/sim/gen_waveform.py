"""
gen_waveform.py — generate waveform.png for M2 compute_core simulation
Timing diagram for Test Vector 1: W=0.5+0j, A=100+0j, B=100+0j
Pipeline: 3-cycle latency (Stage1: multiply, Stage2: scale, Stage3: butterfly)
"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np

# ── timeline: 14 clock cycles ──────────────────────────────────────────
N = 14
t = np.arange(N + 1)          # cycle boundaries 0..14

def clk_wave(n):
    """Return (x, y) for a clock signal over n full cycles."""
    x = []
    y = []
    for i in range(n):
        x += [i, i, i+0.5, i+0.5, i+1]
        y += [0, 1,    1,      0,     0]
    return x, y

def bus_wave(cycles, values, label_map=None):
    """
    Return segments for a bus waveform.
    cycles : list of (start, end) half-open intervals
    values : matching list of string labels
    """
    segs = []
    for (s, e), v in zip(cycles, values):
        segs.append((s, e, v))
    return segs

def draw_bus(ax, row, segs, ylo=0.15, yhi=0.85, color='#1f77b4'):
    for s, e, label in segs:
        w = e - s
        # filled trapezoid effect
        xs = [s+0.08, s+0.22, e-0.22, e-0.08, e-0.22, s+0.22, s+0.08]
        ys = [0.5,    yhi,    yhi,    0.5,    ylo,    ylo,    0.5   ]
        ax.fill([x+0 for x in xs], [y+row for y in ys],
                color=color, alpha=0.25, zorder=2)
        ax.plot([x+0 for x in xs], [y+row for y in ys],
                color=color, linewidth=1.0, zorder=3)
        ax.text((s+e)/2, row+0.5, label,
                ha='center', va='center', fontsize=7.5,
                fontfamily='monospace', zorder=4)

def draw_logic(ax, row, changes, n, color='#2ca02c'):
    """
    changes: list of (cycle, value) transitions
    """
    x_pts = [0]
    y_pts = [changes[0][1]]
    for i, (c, v) in enumerate(changes[1:], 1):
        x_pts += [changes[i-1][0] + (c - changes[i-1][0]), c]
        y_pts += [y_pts[-1], v]
    x_pts.append(n)
    y_pts.append(y_pts[-1])
    # scale to row
    ys = [row + 0.15 + 0.7*v for v in y_pts]
    ax.plot(x_pts, ys, color=color, linewidth=1.5, zorder=3)

# ── figure layout ──────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(13, 7))
ax.set_xlim(-0.2, N + 0.5)
ax.set_ylim(-0.5, 11.5)
ax.set_yticks([])
ax.set_xticks(range(N+1))
ax.set_xticklabels([f'C{i}' for i in range(N+1)], fontsize=8)
ax.set_xlabel('Clock cycle', fontsize=9)
ax.set_title('compute_core — Timing Diagram  |  Test Vector 1: W=0.5+0j, A=100+0j, B=100+0j\n'
             'Pipeline latency = 3 cycles  |  A\'=150+0j  B\'=50+0j', fontsize=10)
ax.grid(axis='x', linestyle=':', linewidth=0.4, color='gray')

# row labels (bottom to top)
rows = ['bi_out', 'br_out', 'ai_out', 'ar_out',
        'valid_out', '── stage 3', '── stage 2', '── stage 1',
        'valid_in', 'ar_in / br_in', 'clk']
for i, lbl in enumerate(rows):
    ax.text(-0.25, i + 0.5, lbl, ha='right', va='center',
            fontsize=8, fontfamily='monospace',
            color='#555' if lbl.startswith('──') else 'black')

# ── clk (row 10) ────────────────────────────────────────────────────────
cx, cy = clk_wave(N)
ax.plot(cx, [10 + 0.15 + 0.7*v for v in cy], color='black', linewidth=1.2)

# ── rst region shading ───────────────────────────────────────────────────
ax.axvspan(0, 3, color='#ffcccc', alpha=0.4, zorder=0)
ax.text(1.5, 11.1, 'RESET', ha='center', fontsize=8, color='#cc0000')

# ── valid_in (row 8) ────────────────────────────────────────────────────
# valid_in pulsed at cycle 4 for 1 cycle
draw_logic(ax, 8, [(0,0),(4,1),(5,0)], N, color='#2ca02c')

# ── ar_in / br_in bus (row 9) ── shown as 100/100 from cycle 4 onward
draw_bus(ax, 9,
         [(0, 4, 'X'), (4, N, 'ar=100  br=100  wr=0x4000  wi=0')],
         color='#9467bd')

# ── Stage 1 pipeline register (row 7) ───────────────────────────────────
draw_logic(ax, 7, [(0,0),(5,1),(6,0)], N, color='#ff7f0e')
ax.text(5.5, 7.92, 's1_valid', fontsize=7, color='#ff7f0e', ha='center')

# ── Stage 2 pipeline register (row 6) ───────────────────────────────────
draw_logic(ax, 6, [(0,0),(6,1),(7,0)], N, color='#ff7f0e')
ax.text(6.5, 6.92, 's2_valid', fontsize=7, color='#ff7f0e', ha='center')

# ── valid_out (row 4) ───────────────────────────────────────────────────
draw_logic(ax, 4, [(0,0),(7,1),(8,0)], N, color='#2ca02c')

# ── ar_out (row 3) ──────────────────────────────────────────────────────
draw_bus(ax, 3,
         [(0, 7, 'X'), (7, 8, 'ar_out=150'), (8, N, 'X')],
         color='#1f77b4')

# ── ai_out (row 2) ──────────────────────────────────────────────────────
draw_bus(ax, 2,
         [(0, 7, 'X'), (7, 8, 'ai_out=0'), (8, N, 'X')],
         color='#1f77b4')

# ── br_out (row 1) ──────────────────────────────────────────────────────
draw_bus(ax, 1,
         [(0, 7, 'X'), (7, 8, 'br_out=50'), (8, N, 'X')],
         color='#d62728')

# ── bi_out (row 0) ──────────────────────────────────────────────────────
draw_bus(ax, 0,
         [(0, 7, 'X'), (7, 8, 'bi_out=0'), (8, N, 'X')],
         color='#d62728')

# ── annotations ─────────────────────────────────────────────────────────
# vertical dashed lines at key cycles
for c, lbl, col in [(4, 'valid_in\nasserted', '#2ca02c'),
                    (7, 'outputs\nvalid', '#1f77b4')]:
    ax.axvline(c, linestyle='--', linewidth=0.9, color=col, alpha=0.7)
    ax.text(c + 0.05, 10.8, lbl, fontsize=7.5, color=col, va='top')

# Pipeline stage arrows
for cy_start, cy_end, lbl in [(4,5,'×4 muls\n(stage 1)'),
                               (5,6,'cmplx\nscale\n(stage 2)'),
                               (6,7,'A±WB\n(stage 3)')]:
    ax.annotate('', xy=(cy_end, 5.5), xytext=(cy_start, 5.5),
                arrowprops=dict(arrowstyle='->', color='#555', lw=1.2))
    ax.text((cy_start+cy_end)/2, 5.75, lbl,
            ha='center', va='bottom', fontsize=7, color='#333')

# Legend
patches = [
    mpatches.Patch(color='#2ca02c', label='valid signals'),
    mpatches.Patch(color='#1f77b4', label='A outputs (ar_out, ai_out)'),
    mpatches.Patch(color='#d62728', label='B outputs (br_out, bi_out)'),
    mpatches.Patch(color='#9467bd', label='input buses'),
    mpatches.Patch(color='#ff7f0e', label='internal pipeline valid'),
    mpatches.Patch(color='#ffcccc', label='reset region'),
]
ax.legend(handles=patches, loc='upper right', fontsize=7.5,
          framealpha=0.9, ncol=2)

plt.tight_layout()
out = r'C:\Users\yaqou\ECE 410\ECE-410-Yaqoub-Rabiah\project\m2\sim\waveform.png'
plt.savefig(out, dpi=150, bbox_inches='tight')
print(f'Saved: {out}')
