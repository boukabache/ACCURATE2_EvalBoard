--! @file accurateFrontend.vhd
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
use work.accurateConfigPkg.all;

entity accurateFrontend is
    generic (
        -- width is 24 because ceil(log2(0.1 second / 10 nano second)) = 24
        countBitwidthG : integer := 24;
        chargeQuantaBitwidthG : integer := 18;
        -- width is 37 because ceil(log2(500fC/1fA * 100MHz)) = 36 + 1 bit for error/sign bit
        countTimeIntervalBitwidthG : integer := 37
    );
    port (
        clk20  : in  std_logic; --! System clock
        clk100 : in  std_logic; --! ACCURATE clock
        rst    : in  std_logic; --! Synchronous reset

        resetOTARequestValidxDI : in  std_logic; --! If resetOTARequest value is valid.
        resetOTARequestxDI : in  std_logic; --! ps request to reset OTA
        resetOTAxDO : out std_logic; --! Actual reset signal of OTA

        --! Window high for one clock period each Interval
        samplexDI : in  std_logic;

        --! Number of activation of the charge pump1 during the last sampling interval
        cp1CountxDO : out unsigned(countBitwidthG - 1 downto 0);
        --! Number of activation of the charge pump2 during the last sampling interval
        cp2CountxDO : out unsigned(countBitwidthG - 1 downto 0);
        --! Number of activation of the charge pump3 during the last sampling interval
        cp3CountxDO : out unsigned(countBitwidthG - 1 downto 0);

        --! Number of cycles in between the last two activation of cp1 - 1
        cp1LastIntervalxDO : out signed(countTimeIntervalBitwidthG - 1 downto 0);

        --! Change in voltage over the last Interval period or MAX if OTA is reset
        chargeMeasurementxDO : out signed(countBitwidthG + chargeQuantaBitwidthG + 2 - 1 downto 0);
        --! The measurementDataxDO value is ready
        measurementReadyxDO  : out std_logic;

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
        capClkxDO : out std_logic;
        --! Enable low current charge pump. Must by synchronous with cap_clk
        enableCP1xDO : out std_logic;
        --! Enable med current charge pump. Must by synchronous with cap_clk
        enableCP2xDO : out std_logic;
        --! Enable high current charge pump. Must by synchronous with cap_clk
        enableCP3xDO : out std_logic
    );
end entity accurateFrontend;

architecture behavior of accurateFrontend is

    signal cp1Activated : std_logic := '0';
    signal cp2Activated : std_logic := '0';
    signal cp3Activated : std_logic := '0';

    signal cp1CountAcc : unsigned(countBitwidthG - 1 downto 0) := (others => '0');
    signal cp2CountAcc : unsigned(countBitwidthG - 1 downto 0) := (others => '0');
    signal cp3CountAcc : unsigned(countBitwidthG - 1 downto 0) := (others => '0');
    signal cp1CountSys : unsigned(countBitwidthG - 1 downto 0) := (others => '0');
    signal cp2CountSys : unsigned(countBitwidthG - 1 downto 0) := (others => '0');
    signal cp3CountSys : unsigned(countBitwidthG - 1 downto 0) := (others => '0');

    signal cp1LastIntervalAcc : signed(countTimeIntervalBitwidthG - 1 downto 0) := ('1', others => '0');
    signal cp1LastIntervalSampledAccxDN, cp1LastIntervalSampledAccxDP : signed(countTimeIntervalBitwidthG - 1 downto 0) := ('1', others => '0');
    signal cp1LastIntervalSys : signed(countTimeIntervalBitwidthG - 1 downto 0) := ('1', others => '0');

    -- As we multiply the counts by the charge quanta, the resulting bitwidth will be the sum of the multiplied vectors
    constant channelChargeSumBitwidthC : integer := cp1CountAcc'length + configxDI.chargeQuantaCP1'length;
    signal chargeCP1xDN, chargeCP1xDP : signed(channelChargeSumBitwidthC - 1 downto 0) := (others => '0');
    signal chargeCP2xDN, chargeCP2xDP : signed(channelChargeSumBitwidthC - 1 downto 0) := (others => '0');
    signal chargeCP3xDN, chargeCP3xDP : signed(channelChargeSumBitwidthC - 1 downto 0) := (others => '0');

    -- As we sum three chargesum channels, we can add two bits and never have overflow
    constant chargeSumBitwidthC : integer := channelChargeSumBitwidthC + 2;
    signal chargeSumxDN, chargeSumxDP : signed(chargeSumBitwidthC - 1 downto 0) := (others => '0');

    signal sampleAcc : std_logic;

    signal measurementReadyAcc : std_logic;
    signal measurementReadySys : std_logic;
    signal measurementReadySysxDP : std_logic_vector(1 downto 0) := (others => '0');

    signal measurementDataTmpSys : std_logic_vector(cp1CountSys'length * 3 + countTimeIntervalBitwidthG - 1 downto 0);

    signal configValidatedxDP, configValidatedxDN : accurateRecordT;
    signal configAcc : accurateRecordT;

    signal previousCycleResetxDP, previousCycleResetxDN : std_logic;

    -- below is a hack. This should be made cleaner.
    -- As the frontend currently cannot generate negative current, we indicate
    -- that we are in reset by outputting -1. Ideally, this should be reported
    -- to the supervision by a dedicated signal, but I do not want to break the
    -- interface now.
    constant largeVoltageSfixed : signed(chargeMeasurementxDO'range) := (others => '1');

    signal resetOTAxDP, resetOTAxDN : std_logic;
begin

    chargeCP1xDN <= configValidatedxDP.chargeQuantaCP1 * signed(cp1CountSys) when measurementReadySys = '1' else
                    chargeCP1xDP;
    chargeCP2xDN <= configValidatedxDP.chargeQuantaCP2 * signed(cp2CountSys) when measurementReadySys = '1' else
                    chargeCP2xDP;
    chargeCP3xDN <= configValidatedxDP.chargeQuantaCP3 * signed(cp3CountSys) when measurementReadySys = '1' else
                    chargeCP3xDP;

    chargeSumxDN <= resize(chargeCP1xDP, chargeSumxDN'length) +
                    resize(chargeCP2xDP, chargeSumxDN'length) +
                    resize(chargeCP3xDP, chargeSumxDN'length);

    configValidatedxDN <= configxDI when configValidxDI else
                          configValidatedxDP;

    resetOTAxDN <= resetOTARequestxDI when resetOTARequestValidxDI = '1' else
                   resetOTAxDP;

    regP20 : process (clk20)
    begin
        if rising_edge(clk20) then
            if (rst = '1') then
                configValidatedxDP <= accurateRecordTInit;
                previousCycleResetxDP <= '0';
                resetOTAxDP <= '1';
                chargeCP1xDP <= (others => '0');
                chargeCP2xDP <= (others => '0');
                chargeCP3xDP <= (others => '0');
                chargeSumxDP <= (others => '0');
                measurementReadySysxDP <= (others => '0');
            else
                configValidatedxDP <= configValidatedxDN;
                previousCycleResetxDP <= previousCycleResetxDN;
                resetOTAxDP <= resetOTAxDN;
                chargeCP1xDP <= chargeCP1xDN;
                chargeCP2xDP <= chargeCP2xDN;
                chargeCP3xDP <= chargeCP3xDN;
                chargeSumxDP <= chargeSumxDN;
                measurementReadySysxDP <= measurementReadySysxDP(measurementReadySysxDP'left-1 downto 0) &
                                          measurementReadySys;
            end if;
        end if;
    end process regP20;

    regP100 : process (clk100)
    begin
        if rising_edge(clk20) then
            if (rst = '1') then
                cp1LastIntervalSampledAccxDP <= ('1', others => '0');
            else
                cp1LastIntervalSampledAccxDP <= cp1LastIntervalSampledAccxDN;
            end if;
        end if;
    end process regP100;

    accurateCDC_E : entity work.accurateCDC
        generic map (
            measurementWidthG => countBitwidthG * 3 + countTimeIntervalBitwidthG
        )
        port map (
            clk20  => clk20,
            clk100 => clk100,
            rst    => rst,

            sampleSysxDI => samplexDI,
            sampleAccxDO => sampleAcc,

            measurementDataSysxDO => measurementDataTmpSys,
            measurementDataAccxDI => std_logic_vector(cp1LastIntervalSampledAccxDP) &
                                     std_logic_vector(cp3CountAcc) &
                                     std_logic_vector(cp2CountAcc) &
                                     std_logic_vector(cp1CountAcc),

            measurementReadySysxDO => measurementReadySys,
            measurementReadyAccxDI => measurementReadyAcc,

            accurateConfigSysxDI => configValidatedxDP,
            accurateConfigAccxDO => configAcc
        );

    cp1LastIntervalSys <= signed(measurementDataTmpSys(countBitwidthG * 3 +
                                                       countTimeIntervalBitwidthG - 1 downto countBitwidthG * 3));

    cp3CountSys <= unsigned(measurementDataTmpSys(cp1CountSys'length +
                                                  cp2CountSys'length +
                                                  cp3CountSys'length - 1 downto cp1CountSys'length + cp2CountSys'length));
    cp2CountSys <= unsigned(measurementDataTmpSys(cp1CountSys'length +
                                                  cp2CountSys'length - 1 downto cp1CountSys'length));
    cp1CountSys <= unsigned(measurementDataTmpSys(cp1CountSys'length - 1 downto 0));

    measurementReadyxDO <= measurementReadySysxDP(measurementReadySysxDP'left);
    chargeMeasurementxDO <= chargeSumxDP when previousCycleResetxDP = '0' else
                            -- this is so that it's clear from the outside that the system is in reset, without
                            -- needing to touch the ROMULUSlib (as this is just for prototype, for now...)
                            largeVoltageSfixed;

    -- The following uses the knowledge that ps2pl values only change on sample falling edge
    previousCycleResetxDN <= '1' when samplexDI = '1' and resetOTARequestxDI = '1' else
                             '0' when samplexDI = '1' and resetOTARequestxDI = '0' else
                             previousCycleResetxDP;

    ACCURATE_HW : entity work.accurateHW
        generic map (
            lightweightG => '1'
        )
        port map (
            clk => clk100,
            rst => rst,
            enablexDI => '1',
            cp1ActivatedxDO => cp1Activated,
            cp2ActivatedxDO => cp2Activated,
            cp3ActivatedxDO => cp3Activated,
            vTh1xDO  => open,
            configxDI => configxDI,
            vTh1NxDI => vTh1NxDI,
            vTh2NxDI => vTh2NxDI,
            vTh3NxDI => vTh3NxDI,
            vTh4NxDI => vTh4NxDI,
            capClkxDO    => capClkxDO,
            enableCP1xDO => enableCP1xDO,
            enableCP2xDO => enableCP2xDO,
            enableCP3xDO => enableCP3xDO
        );

    ACCURATE_COUNTER : entity work.accurateCounter
        generic map (
            countBitwidthG => countBitwidthG
        )
        port map (
            clk => clk100,
            rst => rst,
            samplexDI => sampleAcc,
            cp1CountxDO => cp1CountAcc,
            cp2CountxDO => cp2CountAcc,
            cp3CountxDO => cp3CountAcc,
            cpCountsReadyxDO => measurementReadyAcc,
            overflowErrorxDO => open,
            cp1ActivatedxDI => cp1Activated,
            cp2ActivatedxDI => cp2Activated,
            cp3ActivatedxDI => cp3Activated
        );


    TIME_INTERVAL_COUNTER: entity work.timeIntervalCounter
        generic map(
            countBitwidthG => countTimeIntervalBitwidthG
        )
        port map(
            clk => clk100,
            rst => rst,
            inxDI => cp1Activated,
            lastIntervalDurationxDO => cp1LastIntervalAcc
        );

    cp1LastIntervalSampledAccxDN <= cp1LastIntervalAcc when sampleAcc = '1' else
                                    cp1LastIntervalSampledAccxDP;

    resetOTAxDO <= resetOTAxDP;

    cp1LastIntervalxDO <= cp1LastIntervalSys;

    cp1CountxDO <= cp1CountSys;
    cp2CountxDO <= cp2CountSys;
    cp3CountxDO <= cp3CountSys;

end architecture behavior;
