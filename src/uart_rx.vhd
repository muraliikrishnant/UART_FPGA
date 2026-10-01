library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
    generic (
        CLK_FREQ  : integer := 100_000_000;
        BAUD_RATE : integer := 9600
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        rx        : in  std_logic;
        data_out  : out std_logic_vector(7 downto 0);
        data_valid: out std_logic
    );
end uart_rx;

architecture rtl of uart_rx is
    constant CLKS_PER_BIT : integer := CLK_FREQ / BAUD_RATE;

    type state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state     : state_t := IDLE;
    signal clk_count : integer range 0 to CLKS_PER_BIT - 1 := 0;
    signal bit_index : integer range 0 to 7 := 0;
    signal rx_data   : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_sync   : std_logic_vector(1 downto 0) := "11";
    signal rx_clean  : std_logic := '1';
begin

    -- Double-flop synchronizer for metastability
    process(clk, reset)
    begin
        if reset = '1' then
            rx_sync <= "11";
        elsif rising_edge(clk) then
            rx_sync <= rx_sync(0) & rx;
        end if;
    end process;
    rx_clean <= rx_sync(1);

    process(clk, reset)
    begin
        if reset = '1' then
            state      <= IDLE;
            clk_count  <= 0;
            bit_index  <= 0;
            rx_data    <= (others => '0');
            data_out   <= (others => '0');
            data_valid <= '0';
        elsif rising_edge(clk) then
            data_valid <= '0';

            case state is
                when IDLE =>
                    clk_count <= 0;
                    bit_index <= 0;
                    if rx_clean = '0' then
                        state <= START_BIT;
                    end if;

                when START_BIT =>
                    if clk_count = CLKS_PER_BIT / 2 then
                        clk_count <= 0;
                        if rx_clean = '0' then
                            state <= DATA_BITS;
                        else
                            state <= IDLE;
                        end if;
                    else
                        clk_count <= clk_count + 1;
                    end if;

                when DATA_BITS =>
                    if clk_count = CLKS_PER_BIT - 1 then
                        clk_count <= 0;
                        rx_data(bit_index) <= rx_clean;
                        if bit_index = 7 then
                            bit_index <= 0;
                            state <= STOP_BIT;
                        else
                            bit_index <= bit_index + 1;
                        end if;
                    else
                        clk_count <= clk_count + 1;
                    end if;

                when STOP_BIT =>
                    if clk_count = CLKS_PER_BIT - 1 then
                        clk_count <= 0;
                        if rx_clean = '1' then
                            data_valid <= '1';
                            data_out   <= rx_data;
                        end if;
                        state <= IDLE;
                    else
                        clk_count <= clk_count + 1;
                    end if;
            end case;
        end if;
    end process;
end rtl;
