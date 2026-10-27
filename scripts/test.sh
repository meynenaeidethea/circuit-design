#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
build="$root/task1/simulation/ghdl"
mkdir -p "$build"
cd "$build"
ghdl=${GHDL:-ghdl}
flags=(--std=08 -fsynopsys)
"$ghdl" -a "${flags[@]}" "$root/task1/conveyor_sorter.vhd" "$root/task1/flow_tester.vhd" \
    "$root/task1/conveyor_sorter_top.vhd" "$root/task1/qmtech_demo_top.vhd" \
    "$root/task1/struct_tb.vhd" "$root/task1/flow_tester_tb.vhd"
for cycles in 1 2 3 8; do
    "$ghdl" -r "${flags[@]}" struct_tb -gREJECT_CYCLES="$cycles" --assert-level=error
 done
for cycles in 1 2 8; do
    "$ghdl" -r "${flags[@]}" flow_tester_tb -gSTEP_CYCLES="$cycles" --assert-level=error
 done
# Неверный диапазон должен вызвать ожидаемую ошибку.
if "$ghdl" -r "${flags[@]}" conveyor_sorter -gWEIGHT_MIN=106 -gWEIGHT_MAX=95 --assert-level=error > invalid-range.log 2>&1; then
    echo 'ERROR: invalid weight range was accepted' >&2
    exit 1
fi
grep -q 'WEIGHT_MIN must not exceed WEIGHT_MAX' invalid-range.log
echo 'All 7 simulation runs and invalid-range check passed'
