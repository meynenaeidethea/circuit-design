create_clock -name clk50 -period 20.000 [get_ports {clk50_i}]
derive_clock_uncertainty
# Кнопка асинхронно включает сброс.
# Снятие сброса синхронизируется через resetSync_r.
set_false_path -from [get_ports {nRst_btn_i}]
# Светодиоды не требуют привязки к внешнему такту.
set_false_path -to [get_ports {conveyorLed_n_o rejectLed_n_o}]
