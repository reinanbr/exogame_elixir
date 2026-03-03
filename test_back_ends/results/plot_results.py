#!/usr/bin/env python3
"""
Benchmark Results Plotter
Generates comparison charts from the benchmark CSV summary.

Usage:
    python3 plot_results.py <summary.csv> <output_dir>
"""

import sys
import csv
import os
from pathlib import Path

try:
    import matplotlib
    matplotlib.use('Agg')  # Non-interactive backend
    import matplotlib.pyplot as plt
    import matplotlib.ticker as ticker
    import numpy as np
except ImportError:
    print("matplotlib/numpy not found. Install: pip install matplotlib numpy")
    sys.exit(1)

# ── Color palette (one per backend) ───────────────────────────────────
COLORS = {
    'rust':    '#DEA584',
    'go':      '#00ADD8',
    'c':       '#555555',
    'zig':     '#F7A41D',
    'java':    '#B07219',
    'scala':   '#DC322F',
    'clojure': '#DB5855',
    'elixir':  '#6E4A7E',
    'erlang':  '#B83998',
    'node':    '#339933',
    'python':  '#3572A5',
    'php':     '#4F5D95',
    'ruby':    '#CC342D',
    'fortran': '#4D41B1',
    'cobol':   '#334477',
    'lisp':    '#3FB68B',
}

DISPLAY_NAMES = {
    'rust':    'Rust\nActix-web',
    'go':      'Go\nFiber',
    'c':       'C\nMongoose',
    'zig':     'Zig\nZap',
    'java':    'Java\nQuarkus',
    'scala':   'Scala\nPekko',
    'clojure': 'Clojure\nHttp-kit',
    'elixir':  'Elixir\nPhoenix',
    'erlang':  'Erlang\nCowboy',
    'node':    'Node.js\nFastify',
    'python':  'Python\nFastAPI',
    'php':     'PHP\nSwoole',
    'ruby':    'Ruby\nFalcon',
    'fortran': 'Fortran\nC-Mongoose',
    'cobol':   'COBOL\nC-Mongoose',
    'lisp':    'Lisp\nHunchentoot',
}


def parse_csv(filepath):
    """Parse the summary CSV into a list of dicts."""
    results = []
    with open(filepath, newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = row['backend']
            try:
                results.append({
                    'name': name,
                    'display': DISPLAY_NAMES.get(name, name),
                    'color': COLORS.get(name, '#888888'),
                    'crud_avg': float(row['crud_avg_ms']) if row['crud_avg_ms'] != 'N/A' else None,
                    'crud_p95': float(row['crud_p95_ms']) if row['crud_p95_ms'] != 'N/A' else None,
                    'crud_rps': float(row['crud_rps']) if row['crud_rps'] != 'N/A' else None,
                    'ws_avg': float(row['ws_avg_ms']) if row['ws_avg_ms'] != 'N/A' else None,
                    'ws_p95': float(row['ws_p95_ms']) if row['ws_p95_ms'] != 'N/A' else None,
                    'ws_conns': int(row['ws_connections']) if row['ws_connections'] != 'N/A' else None,
                })
            except (ValueError, KeyError) as e:
                print(f"Skipping {name}: {e}")
                continue
    return results


def plot_crud_latency(results, outdir):
    """Bar chart: CRUD avg + p95 latency (ms)."""
    valid = [r for r in results if r['crud_avg'] is not None]
    if not valid:
        return
    valid.sort(key=lambda r: r['crud_avg'])

    names = [r['display'] for r in valid]
    avgs = [r['crud_avg'] for r in valid]
    p95s = [r['crud_p95'] for r in valid]
    colors = [r['color'] for r in valid]

    x = np.arange(len(names))
    width = 0.35

    fig, ax = plt.subplots(figsize=(max(14, len(names) * 1.2), 7))
    bars1 = ax.bar(x - width/2, avgs, width, label='Avg', color=colors, alpha=0.85)
    bars2 = ax.bar(x + width/2, p95s, width, label='p95', color=colors, alpha=0.5,
                   edgecolor=[c for c in colors], linewidth=1.5)

    ax.set_xlabel('Backend', fontsize=12)
    ax.set_ylabel('Latência (ms)', fontsize=12)
    ax.set_title('CRUD — Latência por Backend (inserção + leitura)', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(names, fontsize=9)
    ax.legend(fontsize=11)
    ax.yaxis.set_major_formatter(ticker.FormatStrFormatter('%.1f'))
    ax.grid(axis='y', alpha=0.3)

    # Value labels
    for bar in bars1:
        h = bar.get_height()
        ax.annotate(f'{h:.1f}', xy=(bar.get_x() + bar.get_width()/2, h),
                    xytext=(0, 3), textcoords='offset points', ha='center', fontsize=7)

    plt.tight_layout()
    fig.savefig(os.path.join(outdir, 'crud_latency.png'), dpi=150)
    fig.savefig(os.path.join(outdir, 'crud_latency.pdf'))
    plt.close(fig)
    print(f"  ✓ crud_latency.png/pdf")


def plot_crud_throughput(results, outdir):
    """Horizontal bar chart: CRUD requests/sec."""
    valid = [r for r in results if r['crud_rps'] is not None]
    if not valid:
        return
    valid.sort(key=lambda r: r['crud_rps'])

    names = [r['display'] for r in valid]
    rps = [r['crud_rps'] for r in valid]
    colors = [r['color'] for r in valid]

    fig, ax = plt.subplots(figsize=(12, max(6, len(names) * 0.5)))
    bars = ax.barh(names, rps, color=colors, alpha=0.85, height=0.6)

    ax.set_xlabel('Requisições/segundo', fontsize=12)
    ax.set_title('CRUD — Throughput (req/s)', fontsize=14, fontweight='bold')
    ax.grid(axis='x', alpha=0.3)

    for bar, val in zip(bars, rps):
        ax.text(bar.get_width() + max(rps) * 0.01, bar.get_y() + bar.get_height()/2,
                f'{val:,.0f}', va='center', fontsize=9)

    plt.tight_layout()
    fig.savefig(os.path.join(outdir, 'crud_throughput.png'), dpi=150)
    fig.savefig(os.path.join(outdir, 'crud_throughput.pdf'))
    plt.close(fig)
    print(f"  ✓ crud_throughput.png/pdf")


def plot_ws_latency(results, outdir):
    """Bar chart: WebSocket latency."""
    valid = [r for r in results if r['ws_avg'] is not None]
    if not valid:
        return
    valid.sort(key=lambda r: r['ws_avg'])

    names = [r['display'] for r in valid]
    avgs = [r['ws_avg'] for r in valid]
    p95s = [r['ws_p95'] for r in valid]
    colors = [r['color'] for r in valid]

    x = np.arange(len(names))
    width = 0.35

    fig, ax = plt.subplots(figsize=(max(14, len(names) * 1.2), 7))
    ax.bar(x - width/2, avgs, width, label='Avg', color=colors, alpha=0.85)
    ax.bar(x + width/2, p95s, width, label='p95', color=colors, alpha=0.5,
           edgecolor=colors, linewidth=1.5)

    ax.set_xlabel('Backend', fontsize=12)
    ax.set_ylabel('Latência (ms)', fontsize=12)
    ax.set_title('WebSocket — Latência de Sessão por Backend', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(names, fontsize=9)
    ax.legend(fontsize=11)
    ax.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    fig.savefig(os.path.join(outdir, 'ws_latency.png'), dpi=150)
    fig.savefig(os.path.join(outdir, 'ws_latency.pdf'))
    plt.close(fig)
    print(f"  ✓ ws_latency.png/pdf")


def plot_ws_connections(results, outdir):
    """Bar chart: max WebSocket connections achieved."""
    valid = [r for r in results if r['ws_conns'] is not None]
    if not valid:
        return
    valid.sort(key=lambda r: r['ws_conns'])

    names = [r['display'] for r in valid]
    conns = [r['ws_conns'] for r in valid]
    colors = [r['color'] for r in valid]

    fig, ax = plt.subplots(figsize=(12, max(6, len(names) * 0.5)))
    bars = ax.barh(names, conns, color=colors, alpha=0.85, height=0.6)

    ax.set_xlabel('Conexões simultâneas', fontsize=12)
    ax.set_title('WebSocket — Conexões Simultâneas Máximas', fontsize=14, fontweight='bold')
    ax.grid(axis='x', alpha=0.3)
    ax.xaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f'{x/1000:.0f}k'))

    for bar, val in zip(bars, conns):
        label = f'{val/1000:.0f}k' if val >= 1000 else str(val)
        ax.text(bar.get_width() + max(conns) * 0.01, bar.get_y() + bar.get_height()/2,
                label, va='center', fontsize=9)

    plt.tight_layout()
    fig.savefig(os.path.join(outdir, 'ws_connections.png'), dpi=150)
    fig.savefig(os.path.join(outdir, 'ws_connections.pdf'))
    plt.close(fig)
    print(f"  ✓ ws_connections.png/pdf")


def plot_combined_radar(results, outdir):
    """Radar/spider chart comparing top backends across all metrics."""
    valid = [r for r in results if all(r[k] is not None for k in
             ['crud_avg', 'crud_rps', 'ws_avg', 'ws_conns'])]
    if len(valid) < 3:
        return

    # Normalize metrics to 0-1 (higher = better)
    metrics = ['crud_rps', 'ws_conns']  # Higher is better
    inv_metrics = ['crud_avg', 'crud_p95', 'ws_avg', 'ws_p95']  # Lower is better

    all_metrics = metrics + inv_metrics
    labels = ['CRUD RPS', 'WS Conns', 'CRUD Avg\n(inv)', 'CRUD p95\n(inv)',
              'WS Avg\n(inv)', 'WS p95\n(inv)']

    # Pick top 8 by CRUD RPS for readability
    valid.sort(key=lambda r: r['crud_rps'], reverse=True)
    valid = valid[:8]

    # Normalize
    normalized = {}
    for m in all_metrics:
        vals = [r[m] for r in valid if r[m] is not None]
        if not vals:
            continue
        mn, mx = min(vals), max(vals)
        rng = mx - mn if mx != mn else 1
        for r in valid:
            if r.get(m) is None:
                continue
            if m in inv_metrics:
                normalized.setdefault(r['name'], []).append(1 - (r[m] - mn) / rng)
            else:
                normalized.setdefault(r['name'], []).append((r[m] - mn) / rng)

    N = len(labels)
    angles = np.linspace(0, 2 * np.pi, N, endpoint=False).tolist()
    angles += angles[:1]

    fig, ax = plt.subplots(figsize=(10, 10), subplot_kw=dict(polar=True))

    for r in valid:
        vals = normalized.get(r['name'], [])
        if len(vals) != N:
            continue
        vals += vals[:1]
        ax.plot(angles, vals, 'o-', linewidth=2, label=r['display'].replace('\n', ' '),
                color=r['color'])
        ax.fill(angles, vals, alpha=0.1, color=r['color'])

    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(labels, fontsize=10)
    ax.set_title('Comparativo Multidimensional — Top 8 Backends', fontsize=14,
                 fontweight='bold', pad=20)
    ax.legend(loc='upper right', bbox_to_anchor=(1.3, 1.1), fontsize=9)

    plt.tight_layout()
    fig.savefig(os.path.join(outdir, 'radar_comparison.png'), dpi=150)
    fig.savefig(os.path.join(outdir, 'radar_comparison.pdf'))
    plt.close(fig)
    print(f"  ✓ radar_comparison.png/pdf")


def generate_latex_table(results, outdir):
    """Generate a LaTeX table for the TCC article."""
    valid = [r for r in results if r['crud_avg'] is not None]
    valid.sort(key=lambda r: r['crud_rps'] or 0, reverse=True)

    latex = []
    latex.append(r"\begin{table}[htbp]")
    latex.append(r"\centering")
    latex.append(r"\caption{Resultados do benchmark comparativo de backends}")
    latex.append(r"\label{tab:benchmark-results}")
    latex.append(r"\begin{tabular}{l r r r r r r}")
    latex.append(r"\toprule")
    latex.append(r"\textbf{Backend} & \textbf{CRUD Avg} & \textbf{CRUD p95} & "
                 r"\textbf{CRUD RPS} & \textbf{WS Avg} & \textbf{WS p95} & "
                 r"\textbf{WS Conns} \\")
    latex.append(r" & \textbf{(ms)} & \textbf{(ms)} & & \textbf{(ms)} & "
                 r"\textbf{(ms)} & \\")
    latex.append(r"\midrule")

    for r in valid:
        name = DISPLAY_NAMES.get(r['name'], r['name']).replace('\n', ' ')
        ca = f"{r['crud_avg']:.2f}" if r['crud_avg'] is not None else "—"
        cp = f"{r['crud_p95']:.2f}" if r['crud_p95'] is not None else "—"
        cr = f"{r['crud_rps']:,.0f}" if r['crud_rps'] is not None else "—"
        wa = f"{r['ws_avg']:.2f}" if r['ws_avg'] is not None else "—"
        wp = f"{r['ws_p95']:.2f}" if r['ws_p95'] is not None else "—"
        wc = f"{r['ws_conns']:,}" if r['ws_conns'] is not None else "—"
        latex.append(f"  {name} & {ca} & {cp} & {cr} & {wa} & {wp} & {wc} \\\\")

    latex.append(r"\bottomrule")
    latex.append(r"\end{tabular}")
    latex.append(r"\fonte{Elaborado pelo autor}")
    latex.append(r"\end{table}")

    outpath = os.path.join(outdir, 'benchmark_table.tex')
    with open(outpath, 'w') as f:
        f.write('\n'.join(latex))
    print(f"  ✓ benchmark_table.tex")


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <summary.csv> <output_dir>")
        sys.exit(1)

    csv_path = sys.argv[1]
    outdir = sys.argv[2]
    os.makedirs(outdir, exist_ok=True)

    print(f"Parsing {csv_path}...")
    results = parse_csv(csv_path)
    print(f"Found {len(results)} backends\n")

    if not results:
        print("No valid results found.")
        sys.exit(1)

    print("Generating plots:")
    plot_crud_latency(results, outdir)
    plot_crud_throughput(results, outdir)
    plot_ws_latency(results, outdir)
    plot_ws_connections(results, outdir)
    plot_combined_radar(results, outdir)

    print("\nGenerating LaTeX table:")
    generate_latex_table(results, outdir)

    print(f"\nAll outputs saved to {outdir}/")


if __name__ == '__main__':
    main()
