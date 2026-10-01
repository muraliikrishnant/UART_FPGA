library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.uart_led_pkg.ALL;

entity uart_led_top is
    generic (
        CLK_FREQ       : integer := 100_000_000;
        BAUD_RATE      : integer := 9600;
        PWM_RESOLUTION : integer := 8
    );
    port (
        clk     : in  std_logic;
        reset   : in  std_logic;
        rx      : in  std_logic;
        led_pwm : out std_logic_vector(NUM_LEDS - 1 downto 0)
    );
end uart_led_top;

architecture structural of uart_led_top is
    signal rx_data    : std_logic_vector(7 downto 0);
    signal rx_valid   : std_logic;
    signal duty_cycle : duty_array_t;
begin

    uart_inst : entity work.uart_rx
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => BAUD_RATE
        )
        port map (
            clk        => clk,
            reset      => reset,
            rx         => rx,
            data_out   => rx_data,
            data_valid => rx_valid
        );

    decoder_inst : entity work.command_decoder
        port map (
            clk        => clk,
            reset      => reset,
            data_in    => rx_data,
            data_valid => rx_valid,
            duty_cycle => duty_cycle
        );

    gen_pwm : for i in 0 to NUM_LEDS - 1 generate
        pwm_inst : entity work.pwm_generator
            generic map (
                PWM_RESOLUTION => PWM_RESOLUTION
            )
            port map (
                clk        => clk,
                reset      => reset,
                duty_cycle => duty_cycle(i),
                pwm_out    => led_pwm(i)
            );
    end generate;

end structural;
