#!/usr/bin/env python3
"""Keep the report appendix identical to the tested project sources."""
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
source = root / 'task1'
target = root / 'docs/report/project/task1'
names = sorted(p.name for p in source.iterdir() if p.suffix in {'.vhd', '.qsf', '.qpf', '.sdc', '.do'})
if args.check:
    mismatches = [name for name in names if not (target / name).is_file() or (source / name).read_bytes() != (target / name).read_bytes()]
    extras = sorted(p.name for p in target.iterdir() if p.is_file() and p.name not in names)
    if mismatches or extras:
        parser.exit(1, f'Outdated appendix: {mismatches}; unexpected files: {extras}\n')
    print(f'All {len(names)} report source copies match')
else:
    target.mkdir(parents=True, exist_ok=True)
    for name in names:
        (target / name).write_bytes((source / name).read_bytes())
    print(f'Synchronized {len(names)} report source copies')
