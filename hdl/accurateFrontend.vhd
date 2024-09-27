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
        -- Bitwidth for countTimeInterval
        countTimeIntervalBitwidthG : integer := 24;
        -- If '1' smaller feature set implemented for accurateHW (no cooldown, no singly)
        lightweightG : std_logic := '1'
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

        --! Number of cycles since the start of the sample and the first activation of cp1 - 1.
        --! Maximum value if no activation.
        cp1StartIntervalxDO : out unsigned(countTimeIntervalBitwidthG - 1 downto 0);

        --! Number of cycles since the last activation of cp1 and the end of the sample - 1.
        --! Maximum value if no activation.
        cp1EndIntervalxDO : out unsigned(countTimeIntervalBitwidthG - 1 downto 0);

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
    function to_std_logic (b : boolean) return std_logic is
    begin
        if (b) then
            return '1';
        else
            return '0';
        end if;
    end function to_std_logic;

    signal cp1Activated : std_logic := '0';
    signal cp1Activated1xDP : std_logic := '0';
    signal cp1Activated2xDP : std_logic := '0';
    signal cp1Activated3xDP : std_logic := '0';
    signal cp2Activated : std_logic := '0';
    signal cp2ActivatedxDP : std_logic := '0';
    signal cp3Activated : std_logic := '0';
    signal cp3ActivatedxDP : std_logic := '0';

    signal cp1ActivationThisSamplexDN, cp1ActivationThisSamplexDP : std_logic := '0';
    signal cp1ActivationThisSamplexDP2 : std_logic := '0';

    signal cp1CountAcc : unsigned(countBitwidthG - 1 downto 0) := (others => '0');
    signal cp2CountAcc : unsigned(countBitwidthG - 1 downto 0) := (others => '0');
    signal cp3CountAcc : unsigned(countBitwidthG - 1 downto 0) := (others => '0');
    signal cp1CountSys : unsigned(countBitwidthG - 1 downto 0) := (others => '0');
    signal cp2CountSys : unsigned(countBitwidthG - 1 downto 0) := (others => '0');
    signal cp3CountSys : unsigned(countBitwidthG - 1 downto 0) := (others => '0');

    signal cp1EndIntervalAcc : unsigned(countTimeIntervalBitwidthG - 1 downto 0) := (others => '0');
    signal cp1EndIntervalSys : unsigned(countTimeIntervalBitwidthG - 1 downto 0) := (others => '0');

    signal cp1FirstPulsexDP, cp1FirstPulsexDN : std_logic := '0';

    signal cp1StartIntervalAccxDN, cp1StartIntervalAccxDP : unsigned(countTimeIntervalBitwidthG - 1 downto 0) := (others => '0');
    signal cp1StartIntervalCounter : unsigned(countTimeIntervalBitwidthG - 1 downto 0) := (others => '0');
    signal cp1StartIntervalSys : unsigned(countTimeIntervalBitwidthG - 1 downto 0) := (others => '0');

    -- As we sum three chargesum channels, we can add two bits and never have overflow
    constant channelChargeSumBitwidthC : integer := cp1CountAcc'length + configxDI.chargeQuantaCP1'length;
    constant chargeSumBitwidthC : integer := channelChargeSumBitwidthC + 2;
    signal chargeSum : signed(chargeSumBitwidthC - 1 downto 0) := (others => '0');

    signal sampleAcc : std_logic := '0';
    signal sampleAccxDP : std_logic := '0';
    signal sampleAccxDP2 : std_logic := '0';

    signal measurementReadySys : std_logic := '0';
    signal measurementReadySysxDP : std_logic_vector(1 downto 0) := (others => '0');

    constant measurementBitwidthC : integer := countBitwidthG * 3 + countTimeIntervalBitwidthG * 2;

    signal measurementDataTmpSys : std_logic_vector(measurementBitwidthC - 1 downto 0) := (others => '0');

    signal configValidatedxDP, configValidatedxDN : accurateRecordT;
    signal configAcc : accurateRecordT;

    signal previousCycleResetxDP, previousCycleResetxDN : std_logic := '0';

    -- below is a hack. This should be made cleaner.
    -- As the frontend currently cannot generate negative current, we indicate
    -- that we are in reset by outputting -1. Ideally, this should be reported
    -- to the supervision by a dedicated signal, but I do not want to break the
    -- interface now.
    constant largeVoltageSfixed : signed(chargeMeasurementxDO'range) := (others => '1');

    signal resetOTAxDP, resetOTAxDN : std_logic := '0';
begin

    mult_accumulatorE : entity work.mult_accumulator
        generic map (
            ABitwidthG => countBitwidthG,
            BBitwidthG => configxDI.chargeQuantaCP1'length,
            resultBitwidthG => chargeSumBitwidthC
        )
        port map (
            clk => clk20,
            rst => rst,
            startxDI => measurementReadySys,
            A1xDI => cp1CountSys,
            B1xDI => configValidatedxDP.chargeQuantaCP1,
            A2xDI => cp2CountSys,
            B2xDI => configValidatedxDP.chargeQuantaCP2,
            A3xDI => cp3CountSys,
            B3xDI => configValidatedxDP.chargeQuantaCP3,
            resultxDO => chargeSum,
            resultValidxDO => measurementReadyxDO
        );

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
                measurementReadySysxDP <= (others => '0');
            else
                configValidatedxDP <= configValidatedxDN;
                previousCycleResetxDP <= previousCycleResetxDN;
                resetOTAxDP <= resetOTAxDN;
                measurementReadySysxDP <= measurementReadySysxDP(measurementReadySysxDP'left-1 downto 0) &
                                          measurementReadySys;
            end if;
        end if;
    end process regP20;

    cp1ActivationThisSamplexDN <= '1' when cp1Activated else
                                  '0' when sampleAccxDP else
                                  cp1ActivationThisSamplexDP;

    regP100 : process (clk100)
    begin
        if rising_edge(clk100) then
            if (rst = '1') then
                sampleAccxDP <= '0';
                sampleAccxDP2 <= '0';
                cp1Activated1xDP <= '0';
                cp1Activated2xDP <= '0';
                cp1Activated3xDP <= '0';
                cp2ActivatedxDP <= '0';
                cp3ActivatedxDP <= '0';

                cp1FirstPulsexDP <= '0';

                cp1ActivationThisSamplexDP <= '0';
                cp1ActivationThisSamplexDP2 <= '0';

                cp1StartIntervalAccxDP <= (others => '0');
            else
                sampleAccxDP <= sampleAcc;
                sampleAccxDP2 <= sampleAccxDP;
                cp1Activated1xDP <= cp1Activated;
                cp1Activated2xDP <= cp1Activated;
                cp1Activated3xDP <= cp1Activated;
                cp2ActivatedxDP <= cp2Activated;
                cp3ActivatedxDP <= cp3Activated;

                cp1FirstPulsexDP <= cp1FirstPulsexDN;

                cp1ActivationThisSamplexDP <= cp1ActivationThisSamplexDN;
                cp1ActivationThisSamplexDP2 <= cp1ActivationThisSamplexDP;

                cp1StartIntervalAccxDP <= cp1StartIntervalAccxDN;
            end if;
        end if;
    end process regP100;


    accurateCDC_E : entity work.accurateCDC
        generic map (
            measurementWidthG => countBitwidthG * 3 + countTimeIntervalBitwidthG * 2
        )
        port map (
            clk20  => clk20,
            clk100 => clk100,
            rst    => rst,

            sampleSysxDI => samplexDI,
            sampleAccxDO => sampleAcc,

            measurementDataSysxDO => measurementDataTmpSys,
            measurementDataAccxDI => std_logic_vector(cp1StartIntervalAccxDP) &
                                     std_logic_vector(cp1EndIntervalAcc) &
                                     std_logic_vector(cp3CountAcc) &
                                     std_logic_vector(cp2CountAcc) &
                                     std_logic_vector(cp1CountAcc),

            measurementReadySysxDO => measurementReadySys,
            measurementReadyAccxDI => sampleAccxDP2,

            accurateConfigSysxDI => configValidatedxDP,
            accurateConfigAccxDO => configAcc
        );

    cp1StartIntervalSys <= unsigned(measurementDataTmpSys(countBitwidthG * 3 +
                                                          countTimeIntervalBitwidthG * 2 - 1
                                                              downto countBitwidthG * 3 + countTimeIntervalBitwidthG));

    cp1EndIntervalSys <= unsigned(measurementDataTmpSys(countBitwidthG * 3 +
                                                         countTimeIntervalBitwidthG - 1 downto countBitwidthG * 3));

    cp3CountSys <= unsigned(measurementDataTmpSys(cp1CountSys'length +
                                                  cp2CountSys'length +
                                                  cp3CountSys'length - 1 downto cp1CountSys'length + cp2CountSys'length));
    cp2CountSys <= unsigned(measurementDataTmpSys(cp1CountSys'length +
                                                  cp2CountSys'length - 1 downto cp1CountSys'length));
    cp1CountSys <= unsigned(measurementDataTmpSys(cp1CountSys'length - 1 downto 0));

    chargeMeasurementxDO <= chargeSum when previousCycleResetxDP = '0' else
                            -- this is so that it's clear from the outside that the system is in reset, without
                            -- needing to touch the ROMULUSlib (as this is just for prototype, for now...)
                            largeVoltageSfixed;

    -- The following uses the knowledge that ps2pl values only change on sample falling edge
    previousCycleResetxDN <= '1' when samplexDI = '1' and resetOTARequestxDI = '1' else
                             '0' when samplexDI = '1' and resetOTARequestxDI = '0' else
                             previousCycleResetxDP;

    ACCURATE_HW : entity work.accurateHW
        generic map (
            lightweightG => lightweightG
        )
        port map (
            clk => clk100,
            rst => rst,
            enablexDI => '1',
            cp1ActivatedxDO => cp1Activated,
            cp2ActivatedxDO => cp2Activated,
            cp3ActivatedxDO => cp3Activated,
            vTh1xDO  => open,
            configxDI => configAcc,
            vTh1NxDI => vTh1NxDI,
            vTh2NxDI => vTh2NxDI,
            vTh3NxDI => vTh3NxDI,
            vTh4NxDI => vTh4NxDI,
            capClkxDO    => capClkxDO,
            enableCP1xDO => enableCP1xDO,
            enableCP2xDO => enableCP2xDO,
            enableCP3xDO => enableCP3xDO
        );

    CP1_COUNTER : entity work.sampleResetCounter
        generic map (
            countBitwidthG => countBitwidthG,
            slowFactorG => 0
        )
        port map (
            clk => clk100,
            rst => rst,
            samplexDI => sampleAcc,
            resetxDI => sampleAcc,
            incrementxDI => cp1Activated1xDP,
            resultxDO => cp1CountAcc,
            overflowxDO => open
        );

    CP2_COUNTER : entity work.sampleResetCounter
        generic map (
            countBitwidthG => countBitwidthG,
            slowFactorG => 0
        )
        port map (
            clk => clk100,
            rst => rst,
            samplexDI => sampleAcc,
            resetxDI => sampleAcc,
            incrementxDI => cp2ActivatedxDP,
            resultxDO => cp2CountAcc,
            overflowxDO => open
        );

    CP3_COUNTER : entity work.sampleResetCounter
        generic map (
            countBitwidthG => countBitwidthG,
            slowFactorG => 0
        )
        port map (
            clk => clk100,
            rst => rst,
            samplexDI => sampleAcc,
            resetxDI => sampleAcc,
            incrementxDI => cp3ActivatedxDP,
            resultxDO => cp3CountAcc,
            overflowxDO => open
        );

    START_INTERVAL_COUNTER : entity work.sampleResetCounter
        generic map (
            countBitwidthG => countTimeIntervalBitwidthG,
            slowFactorG => 0
        )
        port map (
            clk => clk100,
            rst => rst,
            samplexDI => to_std_logic((cp1FirstPulsexDP = '0' and cp1FirstPulsexDN = '1') or (sampleAcc = '1' and cp1Activated2xDP = '1')),
            resetxDI => sampleAcc,
            incrementxDI => '1',
            resultxDO => cp1StartIntervalCounter,
            overflowxDO => open
        );

    cp1FirstPulsexDN <= '1' when sampleAcc = '1' and cp1Activated2xDP = '1' else --corner case
                        '0' when sampleAcc = '1' else
                        '1' when cp1Activated2xDP = '1' else
                        cp1FirstPulsexDP;

    -- If there was no activation during this sample, we can output the maximum
    -- value by piggy-backing off the end counter. This avoids needing to know
    -- how much time there is between samples.
    cp1StartIntervalAccxDN <= cp1StartIntervalCounter when cp1ActivationThisSamplexDP = '1' and sampleAccxDP = '1' else
                              cp1EndIntervalAcc when sampleAccxDP = '1' else
                              cp1StartIntervalAccxDP;

    END_INTERVAL_COUNTER : entity work.sampleResetCounter
        generic map (
            countBitwidthG => countTimeIntervalBitwidthG,
            slowFactorG => 0
        )
        port map (
            clk => clk100,
            rst => rst,
            samplexDI => sampleAcc,
            resetxDI => sampleAcc or cp1Activated3xDP,
            incrementxDI => '1',
            resultxDO => cp1EndIntervalAcc,
            overflowxDO => open
        );

    resetOTAxDO <= resetOTAxDP;

    cp1StartIntervalxDO <= cp1StartIntervalSys;

    cp1EndIntervalxDO <= cp1EndIntervalSys;

    cp1CountxDO <= cp1CountSys;
    cp2CountxDO <= cp2CountSys;
    cp3CountxDO <= cp3CountSys;

end architecture behavior;
