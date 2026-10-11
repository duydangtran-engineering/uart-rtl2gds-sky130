#!/usr/bin/env bash
# Chạy flow OpenLane với nhiều chu kỳ clock, rồi gom kết quả vào một bảng.
# Cách dùng (trong thư mục uart, đã kích hoạt .venv):
#   bash sweep.sh                # mặc định: 20 10 8 6 5 4 (ns)
#   bash sweep.sh 12 9 7         # hoặc tự chọn các chu kỳ
cd "$(dirname "$0")" || exit 1

command -v openlane >/dev/null 2>&1 || {
  echo "Không thấy lệnh openlane. Hãy chạy: source ~/vlsi/.venv/bin/activate"
  exit 1
}

PERIODS=("$@")
[ ${#PERIODS[@]} -eq 0 ] && PERIODS=(20 10 8 6 5 4)
mkdir -p sweep_logs

for P in "${PERIODS[@]}"; do
  TAG="p${P}ns"
  IO=$(python3 -c "print(round(0.2 * $P, 4))")   # độ trễ I/O = 20% chu kỳ

  cat > "sweep_constraints_${P}ns.sdc" <<SDC
# Chu kỳ ${P} ns, độ trễ I/O ${IO} ns (20% chu kỳ)
create_clock -name clk -period ${P} [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
set_clock_transition  0.15 [get_clocks clk]
set_input_delay  -clock clk ${IO} [get_ports {rst_n tx_start tx_data[*] rx_serial}]
set_output_delay -clock clk ${IO} [get_ports {tx_busy tx_serial rx_data[*] rx_valid rx_frame_err}]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y -input_transition_rise 0 -input_transition_fall 0 [get_ports {clk rst_n tx_start tx_data[*] rx_serial}]
set_load -pin_load 0.0334 [get_ports {tx_busy tx_serial rx_data[*] rx_valid rx_frame_err}]
set_max_transition  0.75 [current_design]
set_max_capacitance 0.2  [current_design]
set_max_fanout      10   [current_design]
SDC

  cat > "sweep_config_${P}ns.json" <<JSON
{
  "DESIGN_NAME": "uart",
  "VERILOG_FILES": "dir::src/*.v",
  "CLOCK_PORT": "clk",
  "CLOCK_PERIOD": ${P},
  "PDK": "sky130A",
  "PNR_SDC_FILE": "dir::sweep_constraints_${P}ns.sdc",
  "SIGNOFF_SDC_FILE": "dir::sweep_constraints_${P}ns.sdc"
}
JSON

  rm -rf "runs/${TAG}"
  echo ">>> Chạy chu kỳ ${P} ns (tag: ${TAG})"
  if openlane --dockerized --run-tag "${TAG}" "sweep_config_${P}ns.json" > "sweep_logs/${TAG}.log" 2>&1; then
    echo "    xong"
  else
    echo "    flow báo lỗi (xem sweep_logs/${TAG}.log)"
  fi
done

python3 collect.py "${PERIODS[@]}"
