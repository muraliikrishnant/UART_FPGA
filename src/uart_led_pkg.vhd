library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package uart_led_pkg is
    constant NUM_LEDS : integer := 4;
    type duty_array_t is array (0 to NUM_LEDS - 1) of std_logic_vector(7 downto 0);
end package uart_led_pkg;
