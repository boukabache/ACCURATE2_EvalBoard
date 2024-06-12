--! @file accurateCDC.vhd
--! @brief Connects the 20Mhz system to the 100Mhz accurate interface
-- Copyright (C) CERN CROME Project

-- For the PS interface, a simple 2FF synchronizer is used, as the signals do not change often and are unidirectional.
-- For wind, after a 2FF sync, the rising edge is detected so that we ensure a single cycle pulse-width.
-- For measurementDataxDO, a 2FF sync is used.
-- For measurementReady, things are more complicated, as we want to transfer a single cycle pulse from high to low frequency.
-- In order to do that, I used a bistable in the high clock to set on measurementReady, and only de-assert it once the lower clock side had acknowledged it. An edge detector is used to ensure an end result with single cycle pulse width.

--! Use standard library
library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;
--! Use for bitwidth measurementData
use work.configPkg.all;
use work.accurateConfigPkg.all;

--! Possible caviat: if a new vRdy comes in while the incoming has not
--! completely finished processing (feedback back to low), then it is missed
--! Will not happen with 100ms measurements
entity accurateCDC is
    generic (
        measurementWidthG : integer := voltageChangeRegLengthC
    );
    port (
        clk20  : in  std_logic; --! System clock
        clk100 : in  std_logic; --! ACCURATE clock
        rst    : in  std_logic; --! Synchronous reset

        sampleSysxDI : in  std_logic; --! Window high for one clock period each Interval
        sampleAccxDO : out std_logic; --! Window high for one clock period each Interval

        measurementDataSysxDO : out std_logic_vector(measurementWidthG - 1 downto 0); --! Measurement data to slow clock
        measurementDataAccxDI : in  std_logic_vector(measurementWidthG - 1 downto 0); --! Measurement data from fast clock

        measurementReadySysxDO : out std_logic; --! The measurementDataxDO value is ready
        measurementReadyAccxDI : in  std_logic;  --! The measurementDataxDI value is ready

        -- PS Interface
        accurateConfigSysxDI : in  accurateRecordT;
        accurateConfigAccxDO : out accurateRecordT
    );
end entity accurateCDC;

architecture behavioral of accurateCDC is
    signal sample100_r, sample100_2r : std_logic;
    signal sample100xDP : std_logic;
    signal sampleAccxDN, sampleAccxDP : std_logic;

    signal measurementData20_r, measurementData20_2r : std_logic_vector(measurementDataAccxDI'range);
    signal accurateConfig100_r, accurateConfig100_2r : accurateRecordT;

    signal vRdyEdgeDetected100xDN, vRdyEdgeDetected100xDP : std_logic;
    signal vRdy20_r, vRdy20_2r : std_logic;
    signal vRdyDelayed20 : std_logic;
    signal vRdyFeedback100_r, vRdyFeedback100_2r : std_logic;
    signal measurementReadySysxDP, measurementReadySysxDN : std_logic;

begin

    ------------------------------- Registers ---------------------------------
    regP20 : process (clk20)
    begin
        if rising_edge(clk20) then
            if (rst = '1') then
                measurementData20_r  <= (others => '0');
                measurementData20_2r <= (others => '0');

                vRdy20_r  <= '0';
                vRdy20_2r <= '0';
                vRdyDelayed20 <= '0';
                measurementReadySysxDP <= '0';

            else
                measurementData20_r  <= measurementDataAccxDI;
                measurementData20_2r <= measurementData20_r;

                vRdy20_r  <= vRdyEdgeDetected100xDP;
                vRdy20_2r <= vRdy20_r;
                vRdyDelayed20 <= vRdy20_2r;
                measurementReadySysxDP <= measurementReadySysxDN;
            end if;
        end if;
    end process regP20;

    regP100 : process (clk100)
    begin
        if (rising_edge (clk100)) then
            if (rst = '1') then
                sample100_r  <= '0';
                sample100_2r <= '0';
                sample100xDP <= '0';
                sampleAccxDP <= '0';

                vRdyEdgeDetected100xDP <= '0';
                vRdyFeedback100_r  <= '0';
                vRdyFeedback100_2r <= '0';

                accurateConfig100_r <= accurateRecordTInit;
                accurateConfig100_2r <= accurateRecordTInit;
            else
                sample100_r  <= sampleSysxDI;
                sample100_2r <= sample100_r;
                sample100xDP <= sample100_2r;
                sampleAccxDP <= sampleAccxDN;

                accurateConfig100_r <= accurateConfigSysxDI;
                accurateConfig100_2r <= accurateConfig100_r;

                vRdyEdgeDetected100xDP <= vRdyEdgeDetected100xDN;
                vRdyFeedback100_r  <= vRdy20_2r;
                vRdyFeedback100_2r <= vRdyFeedback100_r;

            end if;
        end if;
    end process regP100;

    -- edge detection so that sampleAccxDO is high in a single cycle
    sampleAccxDN <= '1' when sample100xDP = '0' and sample100_2r = '1' else
                          '0';

    assert not (measurementReadyAccxDI = '1' and vRdyEdgeDetected100xDP = '1')
        report "Voltage change rdy came in while processing previous one"
        severity error;

    -- Keep vRdy high when edge detected, as long as it is not acknowledged (feedback is high)
    vRdyEdgeDetected100xDN <= '1' when measurementReadyAccxDI = '1' else
                              '0' when vRdyFeedback100_2r = '1' else
                              vRdyEdgeDetected100xDP;

    -- Say that system is ready only for a single cycle
    measurementReadySysxDN <= '1' when vRdyDelayed20 = '0' and vRdy20_2r = '1' else
                              '0';

    sampleAccxDO <= sampleAccxDP;
    measurementDataSysxDO <= measurementData20_2r;
    measurementReadySysxDO <= measurementReadySysxDP;
    accurateConfigAccxDO <= accurateConfig100_2r;
end architecture behavioral;
