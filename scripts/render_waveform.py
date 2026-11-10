#!/usr/bin/env python3
"""Построение диаграммы по VCD теста flow_tester_tb; нужен matplotlib."""
import argparse
from bisect import bisect_right
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import MultipleLocator

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('vcd', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--detail', action='store_true', help='показать первый импульс крупным планом')
args = parser.parse_args()
base = 'flow_tester_tb.'
names = {
    base + 'clk_s': 'Такт',
    base + 'nrst_s': 'Сброс nRst',
    base + 'sensora_s': 'Датчик A',
    base + 'sensorb_s': 'Датчик B',
    base + 'weight_s[7:0]': 'Вес на входе',
    base + 'sorter_inst.measuredweight_r[7:0]': 'Зафикс. вес',
    base + 'reject_s': 'Отбраковка',
}
# Имена из заголовка VCD не зависят от порядка сигналов.
stack, identifiers = [], {}
traces = {name: [] for name in names}
time = 0.0
scale = None
lines = iter(args.vcd.read_text().splitlines())
for line in lines:
    fields = line.split()
    if not fields:
        continue
    if fields[0] == '$scope':
        stack.append(fields[2])
    elif fields[0] == '$upscope':
        stack.pop()
    elif fields[0] == '$timescale':
        timing = fields[1:] if len(fields) > 1 else next(lines).split()
        units = {'fs': 1e-9, 'ps': 1e-6, 'ns': 1e-3, 'us': 1, 'ms': 1e3, 's': 1e6}
        scale = float(timing[0]) * units[timing[1]]  # время в микросекундах
    elif fields[0] == '$var':
        name = '.'.join(stack + [fields[4]])
        if name in names:
            identifiers[fields[3]] = name
    elif line.startswith('#'):
        assert scale is not None, 'Missing VCD timescale'
        time = int(line[1:]) * scale
    elif line.startswith('b'):
        value, key = line[1:].split()
        if key in identifiers and set(value) <= {'0', '1'}:
            traces[identifiers[key]].append((time, int(value, 2)))
    elif line[0] in '01' and line[1:] in identifiers:
        traces[identifiers[line[1:]]].append((time, int(line[0])))
assert all(traces.values()), 'Some requested signals were not recorded'
clock, reset, sensor_a, sensor_b, weight, measured, reject = names
reject_edges = traces[reject]
first_on = next(t for t, level in reject_edges if level == 1)
first_off = next(t for t, level in reject_edges if t > first_on and level == 0)

if args.detail:
    shown = (clock, weight, measured, reject)
    offset, scale = first_on, 1000
    pulse_ns = round((first_off - first_on) * scale)
    limits = (-60, pulse_ns + 30)
    axis_label = 'Время относительно начала импульса, нс'
else:
    shown = (reset, sensor_a, sensor_b, weight, measured, reject)
    offset, scale = 0, 1
    limits = (0, time)
    axis_label = 'Время, мкс'

fig, axes = plt.subplots(len(shown), 1, figsize=(8, 0.57 * len(shown) + 0.6),
                         sharex=True, layout='constrained')
for ax, name in zip(axes, shown):
    values = traces[name] + [(time, traces[name][-1][1])]
    times, levels = zip(*values)
    plot_times = [(t - offset) * scale for t in times]
    ax.step(plot_times, levels, where='post', lw=1.2, color='#173d5a')
    ax.set_ylabel(names[name], rotation=0, ha='right', va='center', fontsize=10)
    ax.grid(axis='x', color='#dddddd', linewidth=0.6)
    ax.spines[['top', 'right', 'left']].set_visible(False)
    ax.tick_params(axis='y', length=0, labelsize=8)
    if name in (weight, measured):
        if args.detail:
            left = max(0, bisect_right(plot_times, limits[0]) - 1)
            right = bisect_right(plot_times, limits[1])
            visible = levels[left:right]
            low, high = min(visible), max(visible)
            padding = max(1, (high - low) * 0.2)
            ax.set_yticks(sorted({low, high}))
            ax.set_ylim(low - padding, high + padding)
        else:
            ax.set_yticks([0, 50, 100])
            ax.set_ylim(-8, 114)
    else:
        ax.set_yticks([0, 1])
        ax.set_ylim(-0.2, 1.3)
    if args.detail:
        ax.axvspan(0, pulse_ns, color='#dce8ee', zorder=0)

if args.detail:
    axes[-1].xaxis.set_major_locator(MultipleLocator(20))
    axes[-1].text(pulse_ns / 2, 0.36, f'{pulse_ns} нс', ha='center', fontsize=10)
else:
    axes[-1].xaxis.set_major_locator(MultipleLocator(1))
axes[-1].set_xlabel(axis_label)
axes[-1].set_xlim(*limits)
fig.savefig(args.output, dpi=220)
plt.close(fig)
