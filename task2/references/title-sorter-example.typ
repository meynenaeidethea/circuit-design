// Координаты строк и линий измерены по приложенному PDF шаблона.
// Позиции в pt от левого верхнего угла листа, поля — из sectPr DOCX.
#let group-name = "С24-501"
#let supervisor-full = "Решетько В. М."
#let supervisor-short = "Решетько В. М."
#let report-year = "2026"
#let stamp(x, y, w, size, body, align-to: left, weight: "regular", font: "Liberation Serif", tracking: 0pt) = place(
  top + left, dx: x * 1pt - 56.7pt, dy: y * 1pt - 56.7pt,
  block(width: w * 1pt)[
    #set par(first-line-indent: 0pt, spacing: 0pt, leading: 0pt, justify: false)
    #set text(size: size * 1pt, font: font, weight: weight, tracking: tracking, top-edge: if font == "Book Antiqua" {0.92334em} else {0.89111328125em}, bottom-edge: 0.21630859375em)
    #align(align-to, body)
  ],
)
#let rule(x, y, w) = place(top + left, dx: x * 1pt - 56.7pt, dy: y * 1pt - 56.7pt, line(length: w * 1pt, stroke: 0.5pt))
#stamp(56.7,57.0,496.05,11,[МИНИСТЕРСТВО НАУКИ И ВЫСШЕГО ОБРАЗОВАНИЯ РОССИЙСКОЙ ФЕДЕРАЦИИ],align-to:center)
#stamp(56.7,72.76,496.05,8,[ФЕДЕРАЛЬНОЕ ГОСУДАРСТВЕННОЕ АВТОНОМНОЕ ОБРАЗОВАТЕЛЬНОЕ УЧРЕЖДЕНИЕ ВЫСШЕГО ОБРАЗОВАНИЯ],align-to:center)
#stamp(56.7,81.75,496.05,11,[«Национальный исследовательский ядерный университет «МИФИ»],align-to:center,weight:"bold",font:"Book Antiqua")
#stamp(56.7,95.07,496.05,11,[(НИЯУ МИФИ)],align-to:center,weight:"bold",font:"Book Antiqua")
#rule(62.06,108.5,485.0)
#stamp(56.7,114.98,496.05,11,[ИНСТИТУТ ИНТЕЛЛЕКТУАЛЬНЫХ КИБЕРНЕТИЧЕСКИХ СИСТЕМ],align-to:center)
#stamp(56.7,133.58,496.05,11,[КАФЕДРА «КОМПЬЮТЕРНЫЕ СИСТЕМЫ И ТЕХНОЛОГИИ» (№12)],align-to:center)
#stamp(56.7,180.56,496.05,16,[ОТЧЕТ],align-to:center,weight:"bold",tracking:1.5pt)
#stamp(56.7,198.95,496.05,14,[КУРСОВОЙ ПРОЕКТ (СХЕМОТЕХНИКА ЦИФРОВЫХ УСТРОЙСТВ)],align-to:center,weight:"bold")
#stamp(56.7,220.93,496.05,12,[Семестр 5],align-to:center,weight:"bold")
#stamp(62.06,246.25,490,12,[*Тема:* «Сортировщик продукции на конвейере»])
#rule(56.7,260.1,496.05)
#stamp(62.06,270.4,65,12,[Студенты])
#stamp(124.5,270.4,300,12,[Коротаев С. А., Моря К. О.])
#rule(118.6,284.2,311.9)
#stamp(118.6,285.33,311.9,8,[ФИО],align-to:center)
#stamp(435.19,270.4,48,12,[Группа])
#stamp(487.5,270.4,67.3,12,[#group-name])
#rule(486.4,284.2,67.6)
#stamp(62.06,316.72,85,12,[Руководитель])
#stamp(152.3,309.88,400,12,[#supervisor-full])
#rule(146.6,322.4,407.4)
#rule(146.6,336.85,407.4)
#stamp(146.6,337.77,407.4,8,[ФИО, должность, звание, степень],align-to:center)
#for (y, role, name) in ((360.88,"Студент","Коротаев С. А."),(389.08,"Студент","Моря К. О."),(417.16,"Руководитель",supervisor-short)) {
  stamp(136.94,y,70.8,12,role,align-to:right)
  rule(213.5,y+13.0,138.6)
  stamp(213.5,y+14.21,138.6,8,[подпись],align-to:center)
  stamp(375.91,y,155,12,name)
  rule(371.0,y+13.0,155.0)
  stamp(371.0,y+14.21,155.0,8,[ФИО],align-to:center)
}
#stamp(133.46,454.5,74.3,12,[Оценка],align-to:right,weight:"bold")
#rule(213.5,468.1,138.6)
#stamp(133.46,486.78,74.3,12,[Баллы, ECTS],align-to:right,weight:"bold")
#rule(213.5,500.2,138.6)
#stamp(388.15,514.86,145,12,("«____»__________" + report-year + " г."))
#stamp(56.7,786.23,496.05,12,("Москва  " + report-year + " г."),align-to:center,weight:"bold")
