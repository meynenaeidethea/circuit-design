# Отчёт по проекту «Сортировщик продукции на конвейере»

`report.pdf` обновлён по состоянию на 27.10.2026. Исходники — `report.typ`, `title.typ`; листинги приложения — в `project/task1/`.

В отчёте отражены STD_LOGIC_UNSIGNED, счётчики вниз до нуля, тактовая логика формирования веса без предварительного обнуления, синхронное снятие сброса, исправленные тесты и актуальная сборка Quartus. Временная диаграмма построена из VCD выполненной симуляции GHDL. Старые снимки Quartus явно помечены как исторические; текущие показатели приведены отдельной таблицей и подтверждены протоколами в `../verification/`.

Перед пересборкой из корня репозитория:

```sh
python3 scripts/sync_report_sources.py
python3 scripts/sync_report_sources.py --check
```

Затем из `docs/report`:

```sh
typst compile --font-path assets/fonts report.typ report.pdf
```

Используется Typst 0.15 и вложенные шрифты, Windows и Courier New не требуются. Поля подписей, даты сдачи и оценки остаются для заполнения при сдаче. Проверка физической платы пока не выполнена; оставшиеся действия перечислены в `COMPLETION_CHECKLIST.md`.

Для воспроизведения временной диаграммы после запуска тестов (требуется matplotlib):

```sh
# Из корня репозитория:
ghdl -r --std=08 -fsynopsys --workdir=task1/simulation/ghdl flow_tester_tb --assert-level=error --vcd=task1/simulation/flow.vcd
python3 scripts/render_waveform.py task1/simulation/flow.vcd docs/report/screens/alternating-waveform.png
```
