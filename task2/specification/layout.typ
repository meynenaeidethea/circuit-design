// Размеры полей и координаты титульного листа сняты с отчёта варианта 4.
#let serif = ("Times New Roman", "Liberation Serif")
#let mono = sys.inputs.at("mono-font", default: "Liberation Mono")

#let report-style(body) = {
  set page(
    paper: "a4",
    margin: (left: 68pt, right: 47pt, top: 57pt, bottom: 47pt),
    footer: context {
      let number = counter(page).get().first()
      if number > 1 {
        place(top + center, dy: -3pt, text(font: serif, size: 12pt, str(number)))
      }
    },
  )
  set text(font: serif, size: 14pt, lang: "ru", hyphenate: false)
  set par(justify: true, first-line-indent: (amount: 33pt, all: true),
    leading: 8pt, spacing: 4.5pt)
  set smartquote(enabled: false)
  set heading(numbering: "1.1.")
  show heading: set par(first-line-indent: 0pt, justify: false)
  show heading: set text(size: 14pt, weight: "bold")
  show heading: set align(center)
  show heading.where(level: 1): set block(above: 29pt, below: 15pt)
  show heading.where(level: 2): set block(above: 14pt, below: 15pt)
  show raw: set text(font: mono, size: 12pt, fill: black)
  show raw: set raw(theme: none)
  show raw.where(block: true): it => {
    set text(top-edge: 0.8em, bottom-edge: 0.2em)
    set par(first-line-indent: 0pt, leading: 8.4pt)
    set block(breakable: false)
    it
  }
  show figure: set par(first-line-indent: 0pt, justify: false)
  show figure.caption: set text(size: 12pt)
  show figure.where(kind: table): set figure.caption(position: top)
  show figure.where(kind: table): set block(breakable: true)
  body
}

#let contents() = {
  set par(first-line-indent: 0pt, justify: false, spacing: 8.5pt)
  show outline.entry: it => block(below: 12.6pt, text(size: 14pt, weight: "regular", it))
  set outline.entry(fill: repeat[.])
  align(center, strong[Оглавление])
  v(7pt)
  pad(left: 33pt, outline(title: none, depth: 2, indent: 10pt))
  pagebreak()
}

#let title-page(
  topic: [],
  authors: (),
  kind: [ОТЧЕТ],
  group: "С24-501",
  semester: "5",
  supervisor: "Решетько В. М.",
  year: "2026",
) = {
  set page(paper: "a4", margin: 0pt, footer: none)
  set par(first-line-indent: 0pt, justify: false, leading: 3pt)
  let stamp(x, y, w, size, body, alignment: left, bold: false, font: serif) = place(
    top + left, dx: x * 1pt, dy: y * 1pt,
    block(width: w * 1pt, align(alignment, text(
      font: font, size: size * 1pt, weight: if bold { "bold" } else { "regular" },
      top-edge: 0.89em, bottom-edge: 0.22em, body,
    ))),
  )
  let rule(x, y, w) = place(top + left, dx: x * 1pt, dy: y * 1pt,
    line(length: w * 1pt, stroke: 0.55pt + black))
  let centered(x, y, w, size, body, bold: false, font: serif) = {
    stamp(x, y, w, size, body, alignment: center, bold: bold, font: font)
  }
  let university-font = ("Book Antiqua", ..serif)

  centered(67, 57, 516, 11, [МИНИСТЕРСТВО НАУКИ И ВЫСШЕГО ОБРАЗОВАНИЯ РОССИЙСКОЙ ФЕДЕРАЦИИ])
  centered(67, 78, 516, 8, [ФЕДЕРАЛЬНОЕ ГОСУДАРСТВЕННОЕ АВТОНОМНОЕ ОБРАЗОВАТЕЛЬНОЕ УЧРЕЖДЕНИЕ ВЫСШЕГО ОБРАЗОВАНИЯ])
  centered(67, 88, 516, 11, [«Национальный исследовательский ядерный университет „МИФИ“»], bold: true, font: university-font)
  centered(67, 107, 516, 11, [(НИЯУ МИФИ)], bold: true, font: university-font)
  rule(67, 125, 483)
  centered(67, 132, 516, 11, [ИНСТИТУТ ИНТЕЛЛЕКТУАЛЬНЫХ КИБЕРНЕТИЧЕСКИХ СИСТЕМ])
  centered(67, 152, 516, 11, [КАФЕДРА «КОМПЬЮТЕРНЫЕ СИСТЕМЫ И ТЕХНОЛОГИИ» (№12)])

  centered(65, 226, 486, 16, text(tracking: 2pt, kind), bold: true)
  centered(65, 246, 486, 14, [КУРСОВОЙ ПРОЕКТ (СХЕМОТЕХНИКА ЦИФРОВЫХ], bold: true)
  centered(65, 263, 486, 14, [УСТРОЙСТВ)], bold: true)
  centered(65, 287, 486, 12, [Семестр #semester], bold: true)
  stamp(71, 322, 484, 12, [*Тема\:* #topic])
  rule(65, 340, 494)
  stamp(71, 356, 70, 12, if authors.len() == 1 { [Студент] } else { [Студенты] })
  centered(142, 356, 284, 12, authors.join(", "))
  rule(142, 375.5, 283.5)
  centered(142, 376, 284, 8, [ФИО])
  stamp(431, 356, 60, 12, [Группа])
  centered(493.5, 356, 65.5, 12, group)
  rule(493.5, 375.5, 65.5)
  stamp(80, 415, 84, 12, [Руководитель])
  centered(164.5, 415, 394.5, 12, supervisor)
  rule(164.5, 434.5, 394.5)
  centered(164.5, 435, 394.5, 8, [ФИО])

  let signature(y, role, name) = {
    stamp(120, y, 100, 12, role, alignment: right)
    centered(382, y, 156.5, 12, name)
    rule(224.5, y + 18.5, 138.5)
    rule(382, y + 18.5, 156.5)
    centered(224.5, y + 19, 138.5, 8, [подпись])
    centered(382, y + 19, 156.5, 8, [ФИО])
  }
  let signers = if authors.len() == 0 { ("", "") } else { authors }
  for (index, name) in signers.enumerate() {
    signature(469 + 39 * index, [Студент], name)
  }
  assert(signers.len() <= 3, message: "На титульном листе предусмотрено до трёх подписей студентов.")
  let offset = 39 * (signers.len() - 2)
  signature(547 + offset, [Руководитель], supervisor)
  stamp(120, 599 + offset, 100, 12, [Оценка], alignment: right, bold: true)
  rule(224.5, 618.5 + offset, 138.5)
  stamp(120, 637 + offset, 100, 12, [Баллы, ECTS], alignment: right, bold: true)
  rule(224.5, 652 + offset, 138.5)
  stamp(399, 675 + offset, 145, 12, [«\_\_\_\_»\_\_\_\_\_\_\_\_\_\_ #year г.])
  centered(65, 763, 486, 12, [Москва  #year г.], bold: true)
  // Резервируем страницу, занятую позиционированными полями.
  v(1pt)
}

#let report-table(columns, caption, ..cells) = figure(
  {
    show table.cell.where(y: 0): set text(weight: "bold")
    // Полуторный шаг в ячейках: 21 пт между базовыми линиями.
    set text(size: 14pt, top-edge: 0.8em, bottom-edge: 0.2em)
    set par(first-line-indent: 0pt, justify: false, leading: 9.6pt, spacing: 0pt)
    table(
      columns: columns, align: (_, y) => if y == 0 { center + horizon } else { left + horizon },
      stroke: 0.45pt + black, inset: (x: 4pt, y: 4.5pt),
      fill: (_, y) => if y == 0 { luma(90%) } else { white },
      ..cells.pos(),
    )
  },
  caption: caption, kind: table, supplement: [Таблица],
)
