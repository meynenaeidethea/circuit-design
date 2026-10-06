# Сортировщик товара на конвейере

`task1` содержит VHDL-проект для QMTECH Cyclone 10 Starter Kit V03 с FPGA `10CL080YU484C8G`.

## Файлы

- `conveyor_sorter.vhd` - RTL автомата сортировки.
- `conveyor_sorter_top.vhd` - обёртка для реальных датчиков. Входы датчиков и веса намеренно не имеют pin assignment: их нужно назначать только после согласования физического подключения.
- `flow_tester.vhd` - медленный демонстрационный генератор входных сигналов.
- `qmtech_demo_top.vhd` - top-level, соединяющий генератор и сортировщик.
- `qmtech_demo.qpf`, `qmtech_demo.qsf`, `qmtech_demo.sdc` - проект Quartus для демонстрации.
- `struct_tb.vhd` - самопроверяющийся тестбенч.

## Что исправлено

Автомат разделён на регистр состояния, комбинаторную логику следующего состояния, регистры данных и логику выходов. Счётчики используют `natural`, поэтому нет лишних преобразований между `std_logic_vector` и `unsigned`. Используются только `IEEE.STD_LOGIC_1164` и `IEEE.NUMERIC_STD`.

`REJECT_PULSE_CYCLES = 5_000_000` при 50 MHz задаёт импульс отбраковки 100 ms. `flow_tester` также изменяет шаг раз в 100 ms, чтобы индикацию было видно на плате.

## Сборка и прошивка

1. Откройте `task1/qmtech_demo.qpf` в Quartus Prime.
2. Выполните `Processing -> Start Compilation`.
3. Подключите плату и откройте `Tools -> Programmer`.
4. Нажмите `Auto Detect`, добавьте созданный `.sof`, отметьте `Program/Configure` и нажмите `Start`.

Назначения демонстрации: `CLK_50M` - `PIN_G1`, `SW1` (active-low reset) - `PIN_P4`, D1 - `PIN_V10`, D2 - `PIN_U9`. Все назначенные I/O используют `3.3-V LVTTL`.

D1 и D2 на плате active-low: логический ноль включает светодиод. Поэтому инверсия выполнена только в board-level top-level, а `conveyorRun_o` и `reject_o` в ядре сохраняют обычную active-high семантику. D1 показывает работу конвейера, D2 загорается на импульс отбраковки.
