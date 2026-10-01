# FPGA UART Command Controller

A VHDL design that receives commands over UART and independently controls the brightness of 4 LEDs via PWM, using a channel-select + brightness-level protocol.

## Block Diagram

```
                     ┌──────────┐     ┌───────────────────┐
 rx ────────────────►│ UART RX  │────►│  Command Decoder   │
                     │ (8N1)    │     │  'A'-'D' → select  │
                     └──────────┘     │  channel 0-3       │
                                      │  '0'-'9' → set      │
                                      │  that channel's     │
                                      │  brightness (10     │
                                      │  levels)            │
                                      └─────────┬──────────┘
                                                 │ duty_cycle(0..3)
                                   ┌─────────────┼─────────────┬─────────────┐
                                   ▼             ▼             ▼             ▼
                              ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
                              │PWM Gen │    │PWM Gen │    │PWM Gen │    │PWM Gen │
                              │  LED0  │    │  LED1  │    │  LED2  │    │  LED3  │
                              └───┬────┘    └───┬────┘    └───┬────┘    └───┬────┘
                                  ▼             ▼             ▼             ▼
                              led_pwm(0)    led_pwm(1)    led_pwm(2)    led_pwm(3)
```

## Command Protocol

The decoder keeps a "selected channel" register (default: channel 0 after reset).

| Character | ASCII | Effect |
|-----------|-------|--------|
| `A`       | 0x41  | Select LED0 as active channel |
| `B`       | 0x42  | Select LED1 as active channel |
| `C`       | 0x43  | Select LED2 as active channel |
| `D`       | 0x44  | Select LED3 as active channel |
| `0`–`9`   | 0x30–0x39 | Set active channel's brightness (0=off … 9=full, 10 steps) |
| Any other | —     | Ignored |
| Reset     | —     | All 4 LEDs off, channel resets to 0 |

**Example:** typing `B5` selects LED1, then sets it to ~56% brightness. Typing `9` alone (no channel select) affects whichever channel was last selected (LED0 by default after reset).

## File Structure

```
src/
  uart_led_pkg.vhd     — Shared package: NUM_LEDS constant, duty_array_t type
  pwm_generator.vhd    — 8-bit PWM output (one instance per LED)
  uart_rx.vhd          — UART receiver (8N1, configurable baud, synchronized input)
  command_decoder.vhd  — Channel-select + 10-level brightness decoder
  uart_led_top.vhd     — Top-level: generates 4 PWM instances from decoded duty array
tb/
  tb_uart_led_top.vhd  — Self-checking testbench (7 tests, all 4 channels exercised)
constraints/
  arty_a7.xdc          — Pin constraints for Digilent Arty A7 (4 onboard LEDs)
```

## How to Simulate

### EDA Playground (browser, no install)
1. Go to [edaplayground.com](https://edaplayground.com/)
2. Set **Testbench + Design** to `VHDL`
3. Under **Tools & Simulators**, select **GHDL**
4. In the **design pane** (right side), add a tab per file (click the **+** icon) and paste:
   - `uart_led_pkg.vhd`
   - `pwm_generator.vhd`
   - `uart_rx.vhd`
   - `command_decoder.vhd`
   - `uart_led_top.vhd`
5. In the **testbench pane** (left side), paste `tb_uart_led_top.vhd`
6. Set **Top entity** to `tb_uart_led_top`
7. Check **Open EPWave after run** if you want waveforms
8. Click **Run**, then check the **Log** tab for `TEST 1 PASS` ... `ALL TESTS PASSED`

### Vivado (AMD/Xilinx)
1. Create a new project targeting `xc7a35ticpg236-1L` (Arty A7)
2. Add all `src/*.vhd` files as design sources (package first)
3. Add `tb/tb_uart_led_top.vhd` as a simulation-only source
4. Add `constraints/arty_a7.xdc` as constraints
5. Run **Behavioral Simulation** — check the Tcl console log for `ALL TESTS PASSED`
6. Run **Synthesis** then **Implementation** to confirm it maps to the FPGA

### GHDL (command line)
```bash
cd src
ghdl -a uart_led_pkg.vhd pwm_generator.vhd uart_rx.vhd command_decoder.vhd uart_led_top.vhd
cd ../tb
ghdl -a ../src/*.vhd tb_uart_led_top.vhd
ghdl -e tb_uart_led_top
ghdl -r tb_uart_led_top --wave=uart_led.ghw
# Open uart_led.ghw in GTKWave to view waveforms
```

## Tests Covered

1. **Reset** — all 4 LEDs off
2. **Default channel** — sending `5` with no prior select affects LED0 (~56%)
3. **Channel select + set** — `B9` sets LED1 to full brightness; LED0 stays unchanged
4. **Channel select + off** — `C0` turns LED2 off
5. **Unsupported character** — `Z` leaves all channels unchanged
6. **Reset during operation** — all 4 LEDs return to off
7. **Recovery after reset** — `D3` sets LED3 to low-mid brightness, confirming the system still works after reset

## Configuration

| Generic/Constant | Default     | Description                        |
|-------------------|-------------|-------------------------------------|
| `CLK_FREQ`        | 100,000,000 | System clock in Hz                 |
| `BAUD_RATE`        | 9,600       | UART baud rate                     |
| `PWM_RESOLUTION`   | 8           | PWM counter bit width              |
| `NUM_LEDS`         | 4           | Number of independent LED channels (set in `uart_led_pkg.vhd`) |

## Bug Found & Fixed

During development, the UART receiver initially sampled the `rx` line directly without a synchronizer. This risks metastability when the asynchronous serial input transitions near a clock edge. Fixed by adding a two-flip-flop synchronizer (`rx_sync`) before the UART state machine samples the line.

## Status

**VHDL design verified in simulation.** Not tested on physical hardware.

## Resume Bullet

> FPGA UART Command Controller | VHDL, Vivado — Designed a UART-controlled 4-channel LED brightness system with a channel-select + 10-level command protocol, built from a UART receiver, decoder, and parallel PWM generators; verified channel independence, unsupported inputs, and reset recovery with a self-checking VHDL test bench covering 7 scenarios.
