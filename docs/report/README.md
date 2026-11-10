# Отчёт «Сортировщик продукции на конвейере»

[Готовый PDF](report.pdf). Редактируемый источник находится в `report.typ`, титульный лист в `title.typ`, копии листингов в `project/task1/`.

Пересборка из корня репозитория с Typst 0.14.2 и вложенными шрифтами:

```sh
python3 scripts/sync_report_sources.py
python3 scripts/sync_report_sources.py --check
typst compile --ignore-system-fonts --font-path docs/report/assets/fonts docs/report/report.typ docs/report/report.pdf
```

Воспроизведение обеих временных диаграмм с GHDL и matplotlib:

```sh
./scripts/test.sh
ghdl -r --std=08 -fsynopsys --workdir=task1/simulation/ghdl flow_tester_tb --assert-level=error --vcd=task1/simulation/flow.vcd
python3 scripts/render_waveform.py task1/simulation/flow.vcd docs/report/screens/alternating-waveform.png
python3 scripts/render_waveform.py task1/simulation/flow.vcd docs/report/screens/reject-pulse.png --detail
```

[Протоколы проверок](../verification/README.md) и [этапы аппаратной проверки](COMPLETION_CHECKLIST.md).
