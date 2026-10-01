library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.uart_led_pkg.ALL;

entity tb_uart_led_top is
end tb_uart_led_top;

architecture sim of tb_uart_led_top is

    -- Use small clock divider for fast simulation
    constant CLK_FREQ  : integer := 10_000;
    constant BAUD_RATE : integer := 1_000;
    constant CLK_PERIOD : time := 100 us; -- 10 kHz clock
    constant BIT_PERIOD : time := 1 ms;   -- 1000 baud

    signal clk     : std_logic := '0';
    signal reset   : std_logic := '1';
    signal rx      : std_logic := '1'; -- idle high
    signal led_pwm : std_logic_vector(NUM_LEDS - 1 downto 0);

    signal sim_done : boolean := false;
    signal test_pass_count : integer := 0;
    signal test_fail_count : integer := 0;

    -- Send one UART byte (LSB first, 8N1)
    procedure uart_send(
        signal   tx_line : out std_logic;
        constant data    : in  std_logic_vector(7 downto 0)
    ) is
    begin
        tx_line <= '0'; -- start bit
        wait for BIT_PERIOD;
        for i in 0 to 7 loop
            tx_line <= data(i);
            wait for BIT_PERIOD;
        end loop;
        tx_line <= '1'; -- stop bit
        wait for BIT_PERIOD;
    end procedure;

    -- Measure PWM duty cycle (%) of one channel over a 256-clock PWM period.
    -- Takes the whole led_pwm vector plus an index (rather than an indexed
    -- signal) because GHDL requires a static signal name for a signal-class
    -- actual, and indexing by a loop variable is not static.
    procedure measure_duty(
        signal   pwm_vec      : in  std_logic_vector;
        constant index        : in  integer;
        signal   clk_sig      : in  std_logic;
        variable duty_percent : out integer
    ) is
        variable high_count : integer := 0;
        constant SAMPLE_CYCLES : integer := 256;
    begin
        high_count := 0;
        for i in 0 to SAMPLE_CYCLES - 1 loop
            wait until rising_edge(clk_sig);
            if pwm_vec(index) = '1' then
                high_count := high_count + 1;
            end if;
        end loop;
        duty_percent := (high_count * 100) / SAMPLE_CYCLES;
    end procedure;

    procedure check(
        constant test_name : in string;
        constant actual     : in integer;
        constant lo         : in integer;
        constant hi         : in integer;
        signal   pass_count : inout integer;
        signal   fail_count : inout integer
    ) is
    begin
        if actual >= lo and actual <= hi then
            report test_name & " PASS (duty=" & integer'image(actual) & "%)";
            pass_count <= pass_count + 1;
        else
            report test_name & " FAIL: expected " & integer'image(lo) & "-" & integer'image(hi) &
                   "%, got " & integer'image(actual) & "%" severity error;
            fail_count <= fail_count + 1;
        end if;
    end procedure;

begin

    clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';

    uut : entity work.uart_led_top
        generic map (
            CLK_FREQ       => CLK_FREQ,
            BAUD_RATE      => BAUD_RATE,
            PWM_RESOLUTION => 8
        )
        port map (
            clk     => clk,
            reset   => reset,
            rx      => rx,
            led_pwm => led_pwm
        );

    stim : process
        variable duty : integer;
    begin
        -- ============================================================
        -- TEST 1: Reset — all 4 LEDs off
        -- ============================================================
        reset <= '1';
        wait for 5 * CLK_PERIOD;
        reset <= '0';
        wait for 3 * CLK_PERIOD;

        for i in 0 to NUM_LEDS - 1 loop
            measure_duty(led_pwm, i, clk, duty);
            check("TEST 1 (LED" & integer'image(i) & " off after reset)", duty, 0, 0,
                  test_pass_count, test_fail_count);
        end loop;

        -- ============================================================
        -- TEST 2: Default channel is 0 — send '5' sets LED0 to mid brightness
        -- ============================================================
        uart_send(rx, x"35"); -- '5'
        wait for 2 * CLK_PERIOD;

        measure_duty(led_pwm, 0, clk, duty);
        check("TEST 2 (LED0 mid brightness from '5', no channel select needed)",
              duty, 45, 65, test_pass_count, test_fail_count);

        -- ============================================================
        -- TEST 3: Select channel B (LED1), set to '9' (full), LED0 unchanged
        -- ============================================================
        uart_send(rx, x"42"); -- 'B'
        wait for 2 * CLK_PERIOD;
        uart_send(rx, x"39"); -- '9'
        wait for 2 * CLK_PERIOD;

        measure_duty(led_pwm, 1, clk, duty);
        check("TEST 3 (LED1 full brightness from 'B'+'9')", duty, 95, 100,
              test_pass_count, test_fail_count);

        measure_duty(led_pwm, 0, clk, duty);
        check("TEST 3 (LED0 unaffected by channel switch)", duty, 45, 65,
              test_pass_count, test_fail_count);

        -- ============================================================
        -- TEST 4: Select channel C (LED2), set to '0' (off)
        -- ============================================================
        uart_send(rx, x"43"); -- 'C'
        wait for 2 * CLK_PERIOD;
        uart_send(rx, x"30"); -- '0'
        wait for 2 * CLK_PERIOD;

        measure_duty(led_pwm, 2, clk, duty);
        check("TEST 4 (LED2 off from 'C'+'0')", duty, 0, 0,
              test_pass_count, test_fail_count);

        -- ============================================================
        -- TEST 5: Unsupported character 'Z' — no channel changes
        -- ============================================================
        uart_send(rx, x"5A"); -- 'Z'
        wait for 2 * CLK_PERIOD;

        measure_duty(led_pwm, 1, clk, duty);
        check("TEST 5 (LED1 unchanged after unsupported 'Z')", duty, 95, 100,
              test_pass_count, test_fail_count);

        -- ============================================================
        -- TEST 6: Reset during operation — all LEDs return to off
        -- ============================================================
        reset <= '1';
        wait for 5 * CLK_PERIOD;
        reset <= '0';
        wait for 3 * CLK_PERIOD;

        for i in 0 to NUM_LEDS - 1 loop
            measure_duty(led_pwm, i, clk, duty);
            check("TEST 6 (LED" & integer'image(i) & " off after mid-op reset)", duty, 0, 0,
                  test_pass_count, test_fail_count);
        end loop;

        -- ============================================================
        -- TEST 7: Recovery — select channel D (LED3), set to '3' (low-mid)
        -- ============================================================
        uart_send(rx, x"44"); -- 'D'
        wait for 2 * CLK_PERIOD;
        uart_send(rx, x"33"); -- '3'
        wait for 2 * CLK_PERIOD;

        measure_duty(led_pwm, 3, clk, duty);
        check("TEST 7 (LED3 low-mid brightness from 'D'+'3' after reset)",
              duty, 25, 40, test_pass_count, test_fail_count);

        -- ============================================================
        -- SUMMARY
        -- ============================================================
        wait for 1 ns;
        report "====================================";
        report "TESTS PASSED: " & integer'image(test_pass_count);
        report "TESTS FAILED: " & integer'image(test_fail_count);
        if test_fail_count = 0 then
            report "ALL TESTS PASSED" severity note;
        else
            report "SOME TESTS FAILED" severity error;
        end if;
        report "====================================";

        sim_done <= true;
        wait;
    end process;

end sim;
