## Xilinx constraints file for Digilent Arty A7-35T
## Adjust pin assignments to match your specific board

## Clock (100 MHz)
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports {clk}]
create_clock -period 10.000 -name sys_clk [get_ports {clk}]

## Reset (active-high, directly on BTN0)
set_property -dict { PACKAGE_PIN D9  IOSTANDARD LVCMOS33 } [get_ports {reset}]

## UART RX (USB-UART bridge)
set_property -dict { PACKAGE_PIN A9  IOSTANDARD LVCMOS33 } [get_ports {rx}]

## LEDs (LD4-LD7, active-high, 4 discrete green LEDs on Arty A7)
set_property -dict { PACKAGE_PIN H5  IOSTANDARD LVCMOS33 } [get_ports {led_pwm[0]}]
set_property -dict { PACKAGE_PIN J5  IOSTANDARD LVCMOS33 } [get_ports {led_pwm[1]}]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports {led_pwm[2]}]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {led_pwm[3]}]
