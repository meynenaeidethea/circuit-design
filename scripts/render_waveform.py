#!/usr/bin/env python3
"""Plot named signals from a GHDL flow_tester_tb VCD (requires matplotlib)."""
import argparse
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('vcd', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
base = 'flow_tester_tb.'
names = {
    base + 'nrst_s': ('nRst', False),
    base + 'sensora_s': ('Sensor A', False),
    base + 'sensorb_s': ('Sensor B', False),
    base + 'weight_s[7:0]': ('Weight', True),
    base + 'sorter_inst.measuredweight_r[7:0]': ('Measured', True),
    base + 'reject_s': ('Reject', False),
    base + 'rejectpulses_s': ('Reject pulses', False),
}
# Resolve identifiers from the VCD header: adding a signal must not relabel data.
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
        scale = float(timing[0]) * units[timing[1]]  # plot in microseconds
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
fig, axes = plt.subplots(len(names), 1, figsize=(12, 7), sharex=True, layout='constrained')
for ax, (name, (label, analog)) in zip(axes, names.items()):
    values = traces[name] + [(time, traces[name][-1][1])]
    ax.step(*zip(*values), where='post', lw=1.2, color='#173d5a')
    ax.set_ylabel(label, rotation=0, ha='right', va='center', fontsize=10)
    ax.grid(axis='x', color='#dddddd', linewidth=.5)
    ax.spines[['top', 'right']].set_visible(False)
    if analog:
        ax.set_yticks([0, 80, 100]); ax.set_ylim(-8, 115)
    else:
        ax.set_yticks([0, 1]); ax.set_ylim(-.15, 1.2)
axes[0].set_title('GHDL: flow_tester_tb, STEP_CYCLES=8, REJECT_CYCLES=3', fontsize=12)
axes[-1].set_xlabel('Time, us')
axes[-1].set_xlim(0, time)
fig.savefig(args.output, dpi=200)
plt.close(fig)
