library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Testbench for UartLogic
entity UartLogicTB is
end entity UartLogicTB;

architecture test of UartLogicTB is
    constant CLK_PERIOD : time := 50 ns; -- 20 MHz clock
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal tx_data : std_logic_vector(51 downto 0) := (others => '0');
    signal tx_start : std_logic := '0';
    signal rxFpgaxDI : std_logic := '0';
    signal txFpgaxDO : std_logic := '0';

begin
    -- Loopback
    rxFpgaxDI <= txFpgaxDO;

    -- Instantiate the UartLogic module
    U1 : entity work.UartLogic
        port map (
            clk => clk,
            rst => rst,
            voltageChangeIntervalxDI => tx_data,
            voltageChangeRdyxDI => tx_start,
            rxFpgaxDI => rxFpgaxDI,
            txFpgaxDO => txFpgaxDO
    );

    -- Clock process
    clk_process :process
    begin
        clk <= '1';
        wait for CLK_PERIOD/2;
        clk <= '0';
        wait for CLK_PERIOD/2;
    end process;

    -- Stimulus process
    stimulus : process
    begin
        report "Starting test" severity note;

        -- Reset
        rst <= '1';
        wait for CLK_PERIOD;
        rst <= '0';
        wait for CLK_PERIOD;

        -- Shift of half a clock cycle to make things clearer in the simulation waveform
        wait for CLK_PERIOD/2;

        -- Test 1: Transmit the signal once
        -- Length of the signal is 52 bits
        tx_data <= x"D123456789abc";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';


        wait;
    end process stimulus;

end architecture test;