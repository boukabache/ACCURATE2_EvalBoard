library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Testbench for UartLogic
entity UartWrapperTB is
end entity UartWrapperTB;

architecture test of UartWrapperTB is
    constant CLK_PERIOD : time := 50 ns; -- 20 MHz clock
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    -- UART signals
    signal rxFpgaxDI : std_logic := '0';
    signal txFpgaxDO : std_logic := '0';

    -- UartWrapper signals
    signal fifoDataInxDI  : std_logic_vector(7 downto 0);
    signal fifoDataOutxDO : std_logic_vector(7 downto 0);
    signal fifoEmptyxDO   : std_logic := '0';
    signal fifoFullxDO    : std_logic := '0';
    signal fifoReadxDI    : std_logic := '0';
    signal fifoWritexDI   : std_logic := '0';

begin

    -- Instantiate the UartWrapper module
    U1 : entity work.UartWrapper
        port map (
            clk         => clk,
            rst         => rst,

            rxUartxDI   => rxFpgaxDI,
            txUartxDO   => txFpgaxDO,

            fifoDataInxDI  => fifoDataInxDI,
            fifoDataOutxDO => fifoDataOutxDO,
            fifoEmptyxDO   => fifoEmptyxDO,
            fifoFullxDO    => fifoFullxDO,
            fifoReadxDI    => fifoReadxDI,
            fifoWritexDI   => fifoWritexDI
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

        -- Byte 1
        fifoDataInxDI <= x"AC"; -- 8bit data
        fifoWritexDI <= '1';
        wait for CLK_PERIOD;
        fifoWritexDI <= '0';
        wait for CLK_PERIOD;

        -- Byte 2
        fifoDataInxDI <= x"FF"; -- 8bit data
        fifoWritexDI <= '1';
        wait for CLK_PERIOD;
        fifoWritexDI <= '0';
        wait for CLK_PERIOD;



        wait;
    end process stimulus;

end architecture test;