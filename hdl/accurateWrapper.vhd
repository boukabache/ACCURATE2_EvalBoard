--! @file accurateWrapper.vhd
--! @brief Wraps all components needed for the accurate frontend in a single
--! file.

-- Copyright (C) CERN CROME Project

--! Use standard library
library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;
--! Use for
use work.configPkg.all;
--! For saturating (un)signed type
use ieee.fixed_pkg.all;
use work.customFixedUtilsPkg.all;

use work.IOPkg.all;


entity accurateWrapper is
    port (
        clk20  : in  std_logic; --! System clock
        clk100 : in  std_logic; --! ACCURATE clock
        rst    : in  std_logic; --! Synchronous reset

        ps2plResetOTAValidxDI: in std_logic; --! If ps2plResetOTA value is valid.
        ps2plResetOTAxDI : in  std_logic; --! ps request to reset OTA
        resetOTAxDO : out std_logic; --! Actual reset signal of OTA

        --! Window high for one clock period each Interval
        windIntervalxDI : in  std_logic;

        --! Change in voltage over the last Interval period or MAX if OTA is reset
        voltageChangeIntervalxDO : out sfixed(voltageChangeRegLengthC - 1 downto 0);
        --! The voltageChangeIntervalxDO value is ready
        voltageChangeRdyxDO      : out std_logic;

        -- PS Interface
        configxDI : in  accurateRecordT;
        configValidxDI : in  std_logic;

        -- ACCURATE interface
        --! Input signals coming from accurate
        vTh1NxDI : in  std_logic; --! Comparator 1 input, currently unused
        vTh2NxDI : in  std_logic; --! Comparator 2 input, used for low_current
        vTh3NxDI : in  std_logic; --! Comparator 3 input, used for medium_current
        vTh4NxDI : in  std_logic; --! Comparator 4 input, used for high_current

        --! define charge/discharge cycle of charge pumps
        capClkxDO     : out std_logic;
        --! Enable low current charge pump. Must by synchronous with cap_clk
        enableCP1xDO : out std_logic;
        --! Enable med current charge pump. Must by synchronous with cap_clk
        enableCP2xDO : out std_logic;
        --! Enable high current charge pump. Must by synchronous with cap_clk
        enableCP3xDO : out std_logic
    );
end entity accurateWrapper;

architecture behavior of accurateWrapper is
    signal windIntervalAcc : std_logic;
    signal voltageChangeIntervalSys : sfixed(voltageChangeIntervalxDO'range);
    signal voltageChangeIntervalAcc : sfixed(voltageChangeIntervalxDO'range);
    signal voltageChangeRdyAcc : std_logic;

    signal configValidatedxDP, configValidatedxDN : accurateRecordT;
    signal configAcc : accurateRecordT;

    signal previousCycleResetxDP, previousCycleResetxDN : std_logic;

    -- below is a hack. This should be made cleaner and there shoulnd not be risk of overflow later down the line.
    -- 10mA is much larger than what the frontend can produce, but low enough so that overflow is not encountered on a typical usecase.
    -- On top of everything else, vhdl does not support integer bigger than 32 bits, which is why the voltage code is of type real..
    constant largeVoltageSfixed : sfixed(voltageChangeIntervalxDO'range) := to_sfixed (12376126335647124.0, voltageChangeIntervalxDO'left, voltageChangeIntervalxDO'right);

    signal resetOTAxDP, resetOTAxDN : std_logic;
begin

    configValidatedxDN <= configxDI when configValidxDI else
                          configValidatedxDP;

    resetOTAxDN <= ps2plResetOTAxDI when ps2plResetOTAValidxDI = '1' else
                   resetOTAxDP;

    regP20 : process (clk20)
    begin
        if rising_edge(clk20) then
            if (rst = '1') then
                configValidatedxDP <= accurateRecordTInit;
                previousCycleResetxDP <= '0';
                resetOTAxDP <= '1';
            else
                configValidatedxDP <= configValidatedxDN;
                previousCycleResetxDP <= previousCycleResetxDN;
                resetOTAxDP <= resetOTAxDN;
            end if;
        end if;
    end process regP20;

    -- accurateCDC_E : entity work.accurateCDC
    --     port map (
    --         clk20  => clk20,
    --         clk100 => clk100,
    --         rst    => rst,

    --         windIntervalSysxDI => windIntervalxDI,
    --         windIntervalAccxDO => windIntervalAcc,

    --         voltageChangeIntervalSysxDO => voltageChangeIntervalSys,
    --         voltageChangeIntervalAccxDI => voltageChangeIntervalAcc,

    --         voltageChangeRdySysxDO => voltageChangeRdyxDO,
    --         voltageChangeRdyAccxDI => voltageChangeRdyAcc,

    --         accurateConfigSysxDI => configValidatedxDP,
    --         accurateConfigAccxDO => configAcc
    --     );

    -- voltageChangeIntervalxDO <= voltageChangeIntervalSys when previousCycleResetxDP = '0' else
    --                             -- this is so that it's clear from the outside that the system is in reset, without
    --                             -- needing to touch the ROMULUSlib (as this is just for prototype, for now...)
    --                             largeVoltageSfixed;

    -- -- The following uses the knowledge that ps2pl values only change on windInterval falling edge
    -- previousCycleResetxDN <= '1' when windIntervalxDI = '1' and ps2plResetOTAxDI = '1' else
    --                          '0' when windIntervalxDI = '1' and ps2plResetOTAxDI = '0' else
    --                          previousCycleResetxDP;

    accurateFrontend_E : entity work.accurateFrontend
        port map (
            clk100 => clk100,
            rst => rst,

            windIntervalxDI => windIntervalxDI,
            voltageChangeIntervalxDO => voltageChangeIntervalxDO,
            voltageChangeRdyxDO => voltageChangeRdyxDO,

            enable100xDI => '1',
            vTh1_100xDO => open,

            configxDI => configAcc,

            vTh1NxDI => vTh1NxDI,
            vTh2NxDI => vTh2NxDI,
            vTh3NxDI => vTh3NxDI,
            vTh4NxDI => vTh4NxDI,

            capClkxDO => capClkxDO,
            enableCP1xDO => enableCP1xDO,
            enableCP2xDO => enableCP2xDO,
            enableCP3xDO => enableCP3xDO
        );


    resetOTAxDO <= resetOTAxDP;

end architecture behavior;
