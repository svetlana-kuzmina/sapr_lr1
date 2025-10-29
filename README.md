# САПР — Лабораторная работа №1 

**Автор:** Кузьмина Светлана
**Группа:** М3О-410Б-22

Данный проект представляет собой лабораторую работу №1 по курсу "Автоматизация проектирования"

## APB Project

### How to Compiler
iverilog -g2012 -o apb_tb.out tb_apb_slave.sv apb_slave.sv

### How to Run simulation
vvp apb_tb.out

### How to view waveforms
gtkwave wave.vcd




