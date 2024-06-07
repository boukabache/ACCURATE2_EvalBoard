--! @file accurateFrontend.vhd
--! @brief Interfaces with the Accurate ASIC. Outputs a CROME-compatible
--! charge injection amount when requested by wind100ms.
--!
--! Calculates the change in voltage between two *single* cycle pulse given by
--! windInterval by counting the number of charge pumps enable and converting
--! them to a CROME compatible value (voltage sum of old frontend), which means
--! that 1LSB of the result is equal to 39.3390656 atto coulomb.
--! This "conversion" is done through the configxDI.chargeQuantaCPX values,
--! which are the LSB representation of the charge injected per CP activation.
--! The result will be ready one clock after the windInterval pulse
--! There are a few configuration options available. Except the obvious ones,
--! there is "singlyCPActivation", that forces to have at most one charge pump
--! that can be active at any time. To ensure that higher range is not reduced,
--! the priority is given to the larger charge pumps.
--! There is also parameters pertaining to cooldowns. The behaviour is the
--! following: a charge pump may only activate after half the time there was
--! between its two last activations. This is done in an effort to reduce multi-
--! triggering. Since that time may be very long, it is capped for each CP by
--! the "configxDI.cooldownMaxCPX" value, with unit in cycle lengths.
--! Conversly, we may want to cap the rate of activation of a certain CP. This
--! is achieved through the "configxDI.cooldownMinCPX" (unit cycle length) value,
--! which will ensure the activations are limited.
--! If this behevior is not desirable, then simply set bot variables to zero.
--! The cooldown duration may be slightly longer, as if a charge pump
--! activation happens not aligned to the internal counter(so that we
--! activate as fast as we can), the internal counter is reset and the
--! cooldown counter is not updated.

-- Copyright (C) CERN CROME Project
-- FIXME: use clock cycles for cooldown instead of cycle lengths?

--! Use standard library
library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;
--! For or_reduce
use ieee.std_logic_misc.all;
--! Use for
use work.configPkg.all;
--! For overflow-protected accumulation of charge
use ieee.fixed_pkg.all;
use work.customFixedUtilsPkg.all;
use work.IOPkg.all;

entity accurateFrontend is
    generic (
        lightweightG: std_logic := '1' -- If '1', cooldown logic is disabled to improve speeds.
    );
    port (
        clk100 : in  std_logic; --! 100MHz ACCURATE clock
        rst    : in  std_logic; --! Synchronous reset

        --! Window high for one clock period each Interval
        windIntervalxDI          : in  std_logic;
        --! Legacy CROME representation of the injected charge over the last
        --! Interval period
        voltageChangeIntervalxDO : out sfixed(voltageChangeRegLengthC - 1 downto 0);
        --! The voltageChangeIntervalxDO value is ready
        voltageChangeRdyxDO      : out std_logic;
        overflowErrorxDO : out std_logic;

        --! Enable the frontend (allow it to update the voltage sums and send
        --! charge pumps enable)
        enable100xDI : in  std_logic;
        --! Whether the first voltage threshold is reached. May be useful for
        --! DSM or multi ASICs configurations.
        vTh1_100xDO  : out std_logic;

        --! Configuration for accurate
        configxDI : in  accurateRecordT;

        -- ACCURATE Interface
        --! Input signals coming from accurate
        vTh1NxDI : in  std_logic; --! Comparator 1 input, currently unused
        vTh2NxDI : in  std_logic; --! Comparator 2 input, used for low_current
        vTh3NxDI : in  std_logic; --! Comparator 3 input, used for medium_current
        vTh4NxDI : in  std_logic; --! Comparator 4 input, used for high_current

        -- Accurate output control
        --! define charge/discharge cycle of charge pumps
        capClkxDO     : out std_logic;
        --! Enable low current charge pump. Must by synchronous with cap_clk
        enableCP1xDO : out std_logic;
        --! Enable med current charge pump. Must by synchronous with cap_clk
        enableCP2xDO : out std_logic;
        --! Enable high current charge pump. Must by synchronous with cap_clk
        enableCP3xDO : out std_logic
    );

end entity accurateFrontend;

architecture behavioral of accurateFrontend is
    -- The following should not be necessary, but nesting if generate if for generate statement does not seem supported by GHDL
    constant lightweightC : std_logic := lightweightG;
    signal lightweight : std_logic;

    constant chargePumpNumberC : natural := 3;

    constant cooldownMaxWidthC : natural := 8;
    constant cooldownDurationWidthC : natural := 16;

    -- Holds the accurate's comparator values
    signal compN_r, compN_2r : std_logic_vector(3 downto 0);

    -- config with invalid values filtered out, updates only at a start of a new cycle.
    signal configCurrentxDN, configCurrentxDP : accurateRecordT;
    signal configSafe : accurateRecordT;

    signal cycleLength : ufixed(maximum(configxDI.tCharge'left, configxDI.tInjection'left) + 1 downto 0);

    signal cycleLengthCurrentxDP : ufixed(cycleLength'left downto 0);
    signal cycleLengthCurrentxDN : ufixed(cycleLength'left downto 0);

    signal cycleCounterxDP : unsigned(cycleLength'left downto 0);
    signal cycleCounterxDN : unsigned(cycleLength'left downto 0);
    signal windIntervalxDP : std_logic;

    -- We substract 2 from voltageChangeIntervalxDO to ensure that no overflow
    -- can occur during the addtion of each of the channels
    type chargeSumCPT is
        array (chargePumpNumberC - 1 downto 0) of
        sfixed(voltageChangeIntervalxDO'left - 2 downto voltageChangeIntervalxDO'right);

    signal chargeSumCPxDN, chargeSumCPxDP : chargeSumCPT;
    signal chargeSumNext : chargeSumCPT;

    type chargeQuantaCPT is
        array (chargePumpNumberC - 1 downto 0) of
        sfixed(configxDI.chargeQuantaCP1'range);

    signal chargeQuantaCP : chargeQuantaCPT;

    signal cooldown : std_logic_vector(chargePumpNumberC - 1 downto 0);

    type cooldownDurationArrayT is
        array (chargePumpNumberC - 1 downto 0) of
        unsigned(cooldownDurationWidthC - 1 downto 0);

    signal cooldownMaxCurrentArray : cooldownDurationArrayT;
    signal cooldownMinCurrentArray : cooldownDurationArrayT;

    signal compVthN : std_logic_vector(chargePumpNumberC - 1 downto 0);
    signal overflow_res : std_logic_vector(chargePumpNumberC - 1 downto 0);
    signal overflow_effectivexDN, overflow_effectivexDP : std_logic_vector(chargePumpNumberC - 1 downto 0);

    type cooldownCounterT is
        array (chargePumpNumberC - 1 downto 0) of
        -- Note that the counter is one more bit than the maxmum cooldown, this
        -- is to ensure that it can hold 2x the maximum value.
        unsigned(cooldownDurationWidthC downto 0);

    signal cooldownCounterxDN, cooldownCounterxDP : cooldownCounterT;
    signal cooldownCurrentDurationxDN, cooldownCurrentDurationxDP : cooldownCounterT;

    signal voltageChangeIntervalxDN : sfixed(voltageChangeRegLengthC - 1 downto 0);
    signal voltageChangeIntervalxDP : sfixed(voltageChangeRegLengthC - 1 downto 0);

    signal startPulse : std_logic_vector(chargePumpNumberC - 1 downto 0);
    signal inPulsexDN, inPulsexDP : std_logic_vector(chargePumpNumberC - 1 downto 0);
    signal endCycle : std_logic;

    signal capClkxDP, capClkxDN : std_logic;
    signal enableCPxDP, enableCPxDN : std_logic_vector(chargePumpNumberC - 1 downto 0);
    signal startPulsexDP : std_logic_vector(chargePumpNumberC - 1 downto 0);

begin

    safeCycleP : process (all)
    begin
        configSafe <= configxDI;

        configSafe.tInjection <= to_unsigned(1, configSafe.tInjection'length) when configxDI.tInjection = 0 else
                                 configxDI.tInjection;

        configSafe.tCharge <= to_unsigned(1, configSafe.tCharge'length) when configxDI.tCharge = 0 else
                              configxDI.tCharge;

        configSafe.disableCP1 <= '0' when configxDI.disableCP2 = '1' and configxDI.disableCP3 = '1' else
                                 configxDI.disableCP1;

        LIGTH1: if lightweightG = '0' then
            configSafe.cooldownMaxCP1 <= maximum(configxDI.cooldownMaxCP1, configxDI.cooldownMinCP1);
            configSafe.cooldownMaxCP2 <= maximum(configxDI.cooldownMaxCP2, configxDI.cooldownMinCP2);
            configSafe.cooldownMaxCP3 <= maximum(configxDI.cooldownMaxCP3, configxDI.cooldownMinCP3);
        end if;
    end process safeCycleP;

    cycleLength <= ufixed(configSafe.tCharge) + ufixed(configSafe.tInjection);

    cycleLengthCurrentxDN <= cycleLength when (or_reduce(startPulse)) else
                             cycleLengthCurrentxDP;

    configCurrentxDN <= configCurrentxDP when (or_reduce(inPulsexDP)) else
                        configSafe;

    LIGHT2: if lightweightG = '0' generate
        cooldownMaxCurrentArray <= (
            configCurrentxDP.cooldownMaxCP1,
            configCurrentxDP.cooldownMaxCP2,
            configCurrentxDP.cooldownMaxCP3
        );

        cooldownMinCurrentArray <= (
            configCurrentxDP.cooldownMinCP1,
            configCurrentxDP.cooldownMinCP2,
            configCurrentxDP.cooldownMinCP3
        );
    end generate;

    compVthN(0) <= compN_2r(1); -- vTh2N
    compVthN(1) <= compN_2r(2); -- vTh3N
    compVthN(2) <= compN_2r(3); -- vTh4N

    chargeQuantaCP(0) <= sfixed(configCurrentxDP.chargeQuantaCP1);
    chargeQuantaCP(1) <= sfixed(configCurrentxDP.chargeQuantaCP2);
    chargeQuantaCP(2) <= sfixed(configCurrentxDP.chargeQuantaCP3);

    ------------------------------- Registers ---------------------------------
    regP : process (clk100)
    begin
        if rising_edge(clk100) then
            if (rst = '1') then
                windIntervalxDP <= '0';

                -- 2 FF Synchronizer
                compN_r  <= (others => '1');
                compN_2r <= (others => '1');

                chargeSumCPxDP <= (others => (others => '0'));

                voltageChangeIntervalxDP <= (others => '0');

                cycleCounterxDP <= (others => '0');

                inPulsexDP <= (others => '0');

                cooldownCounterxDP <= (others => (others => '0'));
                cooldownCurrentDurationxDP <= (others => (others => '0'));
                overflow_effectivexDP <= (others => '0');

                inPulsexDP <= (others => '0');

                configCurrentxDP <= accurateRecordTInit;
                cycleLengthCurrentxDP <= (others => '0');

                capClkxDP <= '0';
                enableCPxDP <= (others => '0');

                startPulsexDP <= (others => '0');

            else
                windIntervalxDP <= windIntervalxDI;
                -- 2 FF Synchronizer
                compN_r <= vTh4NxDI & vTh3NxDI & vTh2NxDI & vTh1NxDI;
                compN_2r <= compN_r;

                cooldownCounterxDP <= cooldownCounterxDN;
                cooldownCurrentDurationxDP <= cooldownCurrentDurationxDN;

                chargeSumCPxDP <= chargeSumCPxDN;

                cycleCounterxDP <= cycleCounterxDN;

                inPulsexDP <= inPulsexDN;

                voltageChangeIntervalxDP <= voltageChangeIntervalxDN;
                overflow_effectivexDP <= overflow_effectivexDN;

                inPulsexDP <= inPulsexDN;

                configCurrentxDP <= configCurrentxDN;
                cycleLengthCurrentxDP <= cycleLengthCurrentxDN;

                capClkxDP <= capClkxDN;
                enableCPxDP <= enableCPxDN;

                startPulsexDP <= startPulse;

            end if;
        end if;
    end process regP;

    -- Avoid mix activation of different CP
    -- Certain rules are "soft" (may be changed to improve or not performance),
    -- whereas other are hard (necessary for proper function). Hard rules are:
    -- * Do not enable if the module is disabled (enable100xDI = '0')
    -- * Do not enable if a full injection/charge cycle is not completed
    --   /!\ startPulse is combinatorial -> no - 1 when comparing with
    --   cycleCounter.
    -- The rest are soft rules that can be played with.
    -- Currently, a charge pump is allowed to discharge only if higher value
    -- cp are not working (i.e: in cooldown).
    startPulse(0) <= '1' when enable100xDI = '1' and configCurrentxDP.disableCP1= '0' and
                              -- Allow activation if not in pulse, or pulse available next cycle
                              ((or_reduce(inPulsexDP) = '0') or (endCycle = '1')) and
                              -- Do not activate if bigger charge pump is in cooldown
                              cooldown(2) = '0' and cooldown(1) = '0' and cooldown(0) = '0' and
                              -- Activate if no bigger charge pump can activate
                              (configCurrentxDP.singlyCPActivation = '0' or configCurrentxDP.disableCP3 = '1' or compVthN(2) = '1') and
                              (configCurrentxDP.singlyCPActivation = '0' or configCurrentxDP.disableCP2 = '1' or compVthN(1) = '1') and
                              -- Activate if threshold is reached
                              compVthN(0) = '0' else
                     '0';

    startPulse(1) <= '1' when enable100xDI = '1' and configCurrentxDP.disableCP2 = '0' and
                              ((or_reduce(inPulsexDP) = '0') or (endCycle = '1')) and
                              -- Do not activate if bigger charge pump is in cooldown
                              cooldown(2) = '0' and cooldown(1) = '0' and
                              -- Do not activate if bigger charge pump could activate
                              (configCurrentxDP.singlyCPActivation = '0' or configCurrentxDP.disableCP3 = '1' or compVthN(2) = '1') and
                              -- Activate if threshold is reached
                              compVthN(1) = '0' else
                     '0';

    startPulse(2) <= '1' when enable100xDI = '1' and configCurrentxDP.disableCP3 = '0' and
                              ((or_reduce(inPulsexDP) = '0') or (endCycle = '1')) and
                              cooldown(2) = '0' and compVthN(2) = '0' else
                     '0';

    enableCPxDN <= inPulsexDP;

    cycleCounterxDN <= (others => '0') when or_reduce(startPulse) = '1' else
                       (others => '0') when endCycle = '1' else
                       cycleCounterxDP + 1;

    endCycle <= '1' when cycleCounterxDP = unsigned(cycleLengthCurrentxDP - 1) else
                '0';

    CP_CHANNEL : for I in 0 to chargePumpNumberC - 1 generate
        inPulsexDN(I) <= '1' when startPulse(I) = '1' else
                         '0' when endCycle = '1' else
                         inPulsexDP(I);

        -- Allow activation only if counter bigger than half the previous activation time (capped at cooldownMax)
        -- Second condition is here to ensure proper alignement
        cooldown(I) <= '0' when lightweightG = '1' else
                       '0' when cooldownCurrentDurationxDP(I) = 0 else
                       '0' when cooldownCounterxDP(I) = cooldownCurrentDurationxDP(I) and
                                endCycle = '1' else
                       '1' when cooldownCounterxDP(I) <= cooldownCurrentDurationxDP(I) else
                       '0';
        -- Count number of injection/charge cycles since last activation, capped at cooldownMax
        cooldownCounterxDN(I) <= (others => '0') when lightweightG = '1' else
                                 to_unsigned(1, cooldownCounterxDN(I)) when startPulse(I) = '1' else
                                 -- Count when cycleCounter is wrapping up to keep activations aligned
                                 cooldownCounterxDP(I) + 1 when endCycle = '1' else
                                 cooldownCounterxDP(I);

        -- When starting an activation, save the counter value
        cooldownCurrentDurationxDN(I) <= (others => '0') when lightweightG = '1' else
                                         maximum(minimum(cooldownCounterxDP(I) / 2, cooldownMaxCurrentArray(I)),
                                                 cooldownMinCurrentArray(I)) when startPulse(I) = '1' else
                                         cooldownCurrentDurationxDP(I);

        accumulate(L => chargeSumCPxDP(I),
                   R => chargeQuantaCP(I),
                   Result => chargeSumNext(I),
                   overflow => overflow_res(I));

        -- Compute voltage sums. They are reset every time new data is pushed to
        -- the processing blocks. Corner case: a cp activation happens at the same
        -- time data is requested.
        -- It is possible to achieve the same result by counting the number of cp
        -- activation and then multiplying, but meeting timing requirements then
        -- would be harder.
        chargeSumCPxDN(I) <= resize(chargeQuantaCP(I), chargeSumCPxDN(I)'left, chargeSumCPxDN(I)'right)
                                 when windIntervalxDI = '1' and startPulsexDP(I) = '1' else
                             (others => '0') when windIntervalxDI = '1' else
                             chargeSumNext(I) when startPulsexDP(I) = '1' else
                             chargeSumCPxDP(I);

        overflow_effectivexDN(I) <= '0' when windIntervalxDI = '1' else
                                    '1' when overflow_effectivexDP(I) = '0' else
                                    overflow_res(I);

    end generate CP_CHANNEL;

    voltageChangeIntervalxDN <= resize(chargeSumCPxDP(0) + chargeSumCPxDP(1) + chargeSumCPxDP(2),
                                       voltageChangeIntervalxDN'left,
                                       voltageChangeIntervalxDN'right) when windIntervalxDI = '1' else
                                voltageChangeIntervalxDP;

    capClkxDN <= '1' when (or_reduce(inPulsexDP) = '1' and cycleCounterxDP < unsigned(configCurrentxDP.tInjection)) else
                 '0';

    vTh1_100xDO <= not compN_2r(0); -- vTh1N

    voltageChangeIntervalxDO <= voltageChangeIntervalxDP;
    voltageChangeRdyxDO      <= windIntervalxDP;
    overflowErrorxDO <= or_reduce(overflow_effectivexDP);

    enableCP1xDO <= enableCPxDP(0);
    enableCP2xDO <= enableCPxDP(1);
    enableCP3xDO <= enableCPxDP(2);
    capClkxDO <= capClkxDP;

end architecture behavioral;
