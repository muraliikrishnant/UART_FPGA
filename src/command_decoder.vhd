library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.uart_led_pkg.ALL;

-- Command protocol:
--   'A'..'D'  (0x41-0x44)  -> select active LED channel (0-3)
--   '0'..'9'  (0x30-0x39)  -> set active channel's brightness (10 levels, 0 = off, 9 = full)
--   anything else          -> ignored
entity command_decoder is
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;
        data_in    : in  std_logic_vector(7 downto 0);
        data_valid : in  std_logic;
        duty_cycle : out duty_array_t
    );
end command_decoder;

architecture rtl of command_decoder is
    type duty_lut_t is array (0 to 9) of std_logic_vector(7 downto 0);
    constant DUTY_LUT : duty_lut_t := (
        x"00", x"1C", x"39", x"55", x"71", x"8E", x"AA", x"C6", x"E3", x"FF"
    );

    signal selected_channel : integer range 0 to NUM_LEDS - 1 := 0;
    signal duty_reg         : duty_array_t := (others => (others => '0'));
begin
    process(clk, reset)
        variable ascii : integer;
    begin
        if reset = '1' then
            selected_channel <= 0;
            duty_reg <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if data_valid = '1' then
                ascii := to_integer(unsigned(data_in));

                if ascii >= 48 and ascii <= 57 then
                    -- '0'..'9': set brightness of currently selected channel
                    duty_reg(selected_channel) <= DUTY_LUT(ascii - 48);
                elsif ascii >= 65 and ascii <= (64 + NUM_LEDS) then
                    -- 'A'..'D': select active channel
                    selected_channel <= ascii - 65;
                end if;
                -- any other character is silently ignored
            end if;
        end if;
    end process;

    duty_cycle <= duty_reg;
end rtl;
