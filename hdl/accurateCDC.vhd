--! @file accurateCDC.vhd
--! @brief Connects the 20Mhz system to the 100Mhz accurate interface
-- Copyright (C) CERN CROME Project

-- For the PS interface, a simple 2FF synchronizer is used, as the signals do not change often and are unidirectional.
-- For wind, after a 2FF sync, the rising edge is detected so that we ensure a single cycle pulse-width.
-- For voltageChangeIntervalxDO, a 2FF sync is used.
-- For voltageChangeRdy, things are more complicated, as we want to transfer a single cycle pulse from high to low frequency.
-- In order to do that, I used a bistable in the high clock to set on voltageChangeRdy, and only de-assert it once the lower clock side had acknowledged it. An edge detector is used to ensure an end result with single cycle pulse width.

--! Use standard library
library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;
--! Use for bitwidth voltageChangeInterval
use work.configPkg.all;
--! For overflow-protected accumulation of charge
use ieee.fixed_pkg.all;
use work.customFixedUtilsPkg.all;

use work.IOPkg.all;

--! Possible caviat: if a new vRdy comes in while the incoming has not
--! completely finished processing (feedback back to low), then it is missed
--! Will not happen with 100ms measurements
entity accurateCDC is
    port (
        clk20  : in  std_logic; --! System clock
        clk100 : in  std_logic; --! ACCURATE clock
        rst    : in  std_logic; --! Synchronous reset

        windIntervalSysxDI : in  std_logic; --! Window high for one clock period each Interval
        windIntervalAccxDO : out std_logic; --! Window high for one clock period each Interval

        voltageChangeIntervalSysxDO : out sfixed(voltageChangeRegLengthC - 1 downto 0); --! Change in voltage over the last Interval period
        voltageChangeIntervalAccxDI : in  sfixed(voltageChangeRegLengthC - 1 downto 0); --! Change in voltage over the last Interval period

        voltageChangeRdySysxDO : out std_logic; --! The voltageChangeIntervalxDO value is ready
        voltageChangeRdyAccxDI : in  std_logic;  --! The voltageChangeIntervalxDI value is ready

        -- PS Interface
        accurateConfigSysxDI : in  accurateRecordT;
        accurateConfigAccxDO : out accurateRecordT
    );
end entity accurateCDC;

architecture behavioral of accurateCDC is
    signal windInterval100_r, windInterval100_2r : std_logic;
    signal windInterval100xDP : std_logic;
    signal windIntervalAccxDN, windIntervalAccxDP : std_logic;

    signal voltageChangeInterval20_r, voltageChangeInterval20_2r : sfixed(voltageChangeIntervalAccxDI'range);
    signal accurateConfig100_r, accurateConfig100_2r : accurateRecordT;

    signal vRdyEdgeDetected100xDN, vRdyEdgeDetected100xDP : std_logic;
    signal vRdy20_r, vRdy20_2r : std_logic;
    signal vRdyDelayed20 : std_logic;
    signal vRdyFeedback100_r, vRdyFeedback100_2r : std_logic;
    signal voltageChangeRdySysxDP, voltageChangeRdySysxDN : std_logic;

begin

    ------------------------------- Registers ---------------------------------
    regP20 : process (clk20)
    begin
        if rising_edge(clk20) then
            if (rst = '1') then
                voltageChangeInterval20_r  <= (others => '0');
                voltageChangeInterval20_2r <= (others => '0');

                vRdy20_r  <= '0';
                vRdy20_2r <= '0';
                vRdyDelayed20 <= '0';
                voltageChangeRdySysxDP <= '0';

            else
                voltageChangeInterval20_r  <= voltageChangeIntervalAccxDI;
                voltageChangeInterval20_2r <= voltageChangeInterval20_r;

                vRdy20_r  <= vRdyEdgeDetected100xDP;
                vRdy20_2r <= vRdy20_r;
                vRdyDelayed20 <= vRdy20_2r;
                voltageChangeRdySysxDP <= voltageChangeRdySysxDN;
            end if;
        end if;
    end process regP20;

    regP100 : process (clk100)
    begin
        if (rising_edge (clk100)) then
            if (rst = '1') then
                windInterval100_r  <= '0';
                windInterval100_2r <= '0';
                windInterval100xDP <= '0';
                windIntervalAccxDP <= '0';

                vRdyEdgeDetected100xDP <= '0';
                vRdyFeedback100_r  <= '0';
                vRdyFeedback100_2r <= '0';

                accurateConfig100_r <= accurateRecordTInit;
                accurateConfig100_2r <= accurateRecordTInit;
            else
                windInterval100_r  <= windIntervalSysxDI;
                windInterval100_2r <= windInterval100_r;
                windInterval100xDP <= windInterval100_2r;
                windIntervalAccxDP <= windIntervalAccxDN;

                accurateConfig100_r <= accurateConfigSysxDI;
                accurateConfig100_2r <= accurateConfig100_r;

                vRdyEdgeDetected100xDP <= vRdyEdgeDetected100xDN;
                vRdyFeedback100_r  <= vRdy20_2r;
                vRdyFeedback100_2r <= vRdyFeedback100_r;

            end if;
        end if;
    end process regP100;

    -- edge detection so that windIntervalAccxDO is high in a single cycle
    windIntervalAccxDN <= '1' when windInterval100xDP = '0' and windInterval100_2r = '1' else
                          '0';

    assert not (voltageChangeRdyAccxDI = '1' and vRdyEdgeDetected100xDP = '1')
        report "Voltage change rdy came in while processing previous one"
        severity error;

    -- Keep vRdy high when edge detected, as long as it is not acknowledged (feedback is high)
    vRdyEdgeDetected100xDN <= '1' when voltageChangeRdyAccxDI = '1' else
                              '0' when vRdyFeedback100_2r = '1' else
                              vRdyEdgeDetected100xDP;

    -- Say that system is ready only for a single cycle
    voltageChangeRdySysxDN <= '1' when vRdyDelayed20 = '0' and vRdy20_2r = '1' else
                              '0';

    windIntervalAccxDO <= windIntervalAccxDP;
    voltageChangeIntervalSysxDO <= voltageChangeInterval20_2r;
    voltageChangeRdySysxDO <= voltageChangeRdySysxDP;
    accurateConfigAccxDO <= accurateConfig100_2r;
end architecture behavioral;
