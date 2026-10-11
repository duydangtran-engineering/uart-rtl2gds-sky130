# 1. Clock: 20 ns = 50 MHz
create_clock -name clk -period 20 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
set_clock_transition  0.15 [get_clocks clk]

# 2. I/O delay: phan ben ngoai chiem 20% chu ky (4 ns)
set_input_delay  -clock clk 4 [get_ports {rst_n tx_start tx_data[*] rx_serial}]
set_output_delay -clock clk 4 [get_ports {tx_busy tx_serial rx_data[*] rx_valid rx_frame_err}]

# 3. Environment: cell lai cong vao va tai o cong ra
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y -input_transition_rise 0 -input_transition_fall 0 [get_ports {clk rst_n tx_start tx_data[*] rx_serial}]
set_load -pin_load 0.0334 [get_ports {tx_busy tx_serial rx_data[*] rx_valid rx_frame_err}]

# 4. Design rules
set_max_transition  0.75 [current_design]
set_max_capacitance 0.2  [current_design]
set_max_fanout      10   [current_design]
