--! @file accurateHW.vhd
--! @brief Interfaces with the Accurate ASIC.
--!
--! Physical interface to ACCURATE ASIC. Activates the corresponding charge pump
--! when a threshold is detected. It also has a few extra features:
--! * Cooldown: limits the activation rate of a charge pump to half the time
--!   since the last activation. Capped between cooldownMax cooldownMin (unit
--!   in cap clock periods)
--! * SinglyActivation: prevents activating multiple charge pump at the same
--!   time by only allowing the largest triggered charge pump to activated.
--!
--! The generic lightweightG disables the above features to allow for higher
--! clock speeds.
--! Each time a charge pump activates, the corresponding cpNActivatedxDO goes
--! high for a single cycle.

-- Copyright (C) CERN CROME Project

--! Use standard library
library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;
--! For or_reduce
use ieee.std_logic_misc.all;
use work.accurateConfigPkg.all;

entity accurateHW is
    generic (
        lightweightG : std_logic := '0' -- If '1', cooldown logic is disabled to improve speeds.
    );
    port (
        clk : in  std_logic; --! Input clock, typically 100MHz
        rst : in  std_logic; --! Synchronous reset

        --! Enable the frontend (allow it to update the voltage sums and send
        --! charge pumps enable)
        enablexDI : in  std_logic;

        cp1ActivatedxDO : out std_logic; --! High for 1 cycle when cp1 is activated
        cp2ActivatedxDO : out std_logic; --! High for 1 cycle when cp2 is activated
        cp3ActivatedxDO : out std_logic; --! High for 1 cycle when cp3 is activated

        --! Whether the first voltage threshold is reached. May be useful for
        --! DSM or multi ASICs configurations.
        vTh1xDO  : out std_logic;

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

end entity accurateHW;

architecture behavioral of accurateHW is
    constant chargePumpNumberC : natural := 3;

    constant cooldownMaxWidthC : natural := 8;
    constant cooldownDurationWidthC : natural := 16;

    -- Holds the accurate's comparator values
    signal compN_r, compN_2r : std_logic_vector(3 downto 0);

    -- config with invalid values filtered out, updates only at a start of a new cycle.
    signal configCurrentxDN, configCurrentxDP : accurateRecordT;
    signal configSafexDN, configSafexDP : accurateRecordT;

    signal cycleLengthxDN, cycleLengthxDP : unsigned(maximum(configxDI.tCharge'left, configxDI.tInjection'left) + 1 downto 0);

    signal cycleLengthCurrentxDP : unsigned(cycleLengthxDN'range);
    signal cycleLengthCurrentxDN : unsigned(cycleLengthxDN'range);

    signal cycleCounterxDP : unsigned(cycleLengthxDN'range);
    signal cycleCounterxDN : unsigned(cycleLengthxDN'range);

    signal cooldown : std_logic_vector(chargePumpNumberC - 1 downto 0);

    type cooldownDurationArrayT is
        array (chargePumpNumberC - 1 downto 0) of
        unsigned(cooldownDurationWidthC - 1 downto 0);

    signal cooldownMaxCurrentArray : cooldownDurationArrayT;
    signal cooldownMinCurrentArray : cooldownDurationArrayT;

    signal compVthN : std_logic_vector(chargePumpNumberC - 1 downto 0);

    type cooldownCounterT is
        array (chargePumpNumberC - 1 downto 0) of
        -- Note that the counter is one more bit than the maxmum cooldown, this
        -- is to ensure that it can hold 2x the maximum value.
        unsigned(cooldownDurationWidthC downto 0);

    signal cooldownCounterxDN, cooldownCounterxDP : cooldownCounterT;
    signal cooldownCurrentDurationxDN, cooldownCurrentDurationxDP : cooldownCounterT;

    signal startPulseNextCycle : std_logic_vector(chargePumpNumberC - 1 downto 0);
    signal inPulsexDN, inPulsexDP : std_logic_vector(chargePumpNumberC - 1 downto 0);
    signal anyInPulsexDP : std_logic;
    signal endCyclexDN, endCyclexDP : std_logic;

    signal capClkxDP, capClkxDN : std_logic;
    signal enableCPxDP, enableCPxDN : std_logic_vector(chargePumpNumberC - 1 downto 0);
    signal startPulseNextCyclexDP : std_logic_vector(chargePumpNumberC - 1 downto 0);

    signal endTChargexDP, endTChargexDN : unsigned(configxDI.tCharge'range) := (others => '0');
    signal endTChargeCurrentxDP, endTChargeCurrentxDN : unsigned(configxDI.tCharge'range) := (others => '0');
begin

    safeCycleP : process (all)
    begin
        configSafexDN <= configxDI;

        configSafexDN.tInjection <= to_unsigned(1, configSafexDN.tInjection'length) when configxDI.tInjection = 0 else
                                    configxDI.tInjection;

        configSafexDN.tCharge <= to_unsigned(1, configSafexDN.tCharge'length) when configxDI.tCharge = 0 else
                                 configxDI.tCharge;

        configSafexDN.disableCP1 <= '0' when configxDI.disableCP2 = '1' and configxDI.disableCP3 = '1' else
                                    configxDI.disableCP1;

        configSafexDN.cooldownMaxCP1 <= maximum(configxDI.cooldownMaxCP1, configxDI.cooldownMinCP1);
        configSafexDN.cooldownMaxCP2 <= maximum(configxDI.cooldownMaxCP2, configxDI.cooldownMinCP2);
        configSafexDN.cooldownMaxCP3 <= maximum(configxDI.cooldownMaxCP3, configxDI.cooldownMinCP3);
    end process safeCycleP;

    endTChargexDN <= configSafexDP.tCharge - 1;

    endTChargeCurrentxDN <= endTChargeCurrentxDP when anyInPulsexDP else
                            endTChargexDP;

    cycleLengthxDN <= resize(configxDI.tCharge, cycleLengthxDN'length) + resize(configxDI.tInjection, cycleLengthxDN'length);

    cycleLengthCurrentxDN <= cycleLengthxDP when (or_reduce(startPulseNextCycle)) else
                             cycleLengthCurrentxDP;

    configCurrentxDN <= configCurrentxDP when anyInPulsexDP else
                        configSafexDP;

    LIGHT2 : if lightweightG = '0' generate
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
    else generate
        cooldownMaxCurrentArray <= (others => (others => '0'));
        cooldownMinCurrentArray <= (others => (others => '0'));
    end generate LIGHT2;

    compVthN(0) <= compN_2r(1); -- vTh2N
    compVthN(1) <= compN_2r(2); -- vTh3N
    compVthN(2) <= compN_2r(3); -- vTh4N

    ------------------------------- Registers ---------------------------------
    regP : process (clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                -- 2 FF Synchronizer
                compN_r  <= (others => '1');
                compN_2r <= (others => '1');

                cycleCounterxDP <= (others => '0');

                inPulsexDP <= (others => '0');
                anyInPulsexDP <= '0';

                cooldownCounterxDP <= (others => (others => '0'));
                cooldownCurrentDurationxDP <= (others => (others => '0'));

                configCurrentxDP <= accurateRecordTInit;
                configSafexDP <= accurateRecordTInit;
                cycleLengthxDP <= (others => '0');

                cycleLengthCurrentxDP <= (others => '0');

                capClkxDP <= '0';
                enableCPxDP <= (others => '0');

                startPulseNextCyclexDP <= (others => '0');
                endCyclexDP <= '0';

            else
                -- 2 FF Synchronizer
                compN_r <= vTh4NxDI & vTh3NxDI & vTh2NxDI & vTh1NxDI;
                compN_2r <= compN_r;

                cooldownCounterxDP <= cooldownCounterxDN;
                cooldownCurrentDurationxDP <= cooldownCurrentDurationxDN;

                cycleCounterxDP <= cycleCounterxDN;

                inPulsexDP <= inPulsexDN;
                anyInPulsexDP <= or_reduce(inPulsexDN);

                configCurrentxDP <= configCurrentxDN;
                configSafexDP <= configSafexDN;
                cycleLengthxDP <= cycleLengthxDN;
                endTChargexDP <= endTChargexDN;
                endTChargeCurrentxDP <= endTChargeCurrentxDN;
                cycleLengthCurrentxDP <= cycleLengthCurrentxDN;

                capClkxDP <= capClkxDN;
                enableCPxDP <= enableCPxDN;

                startPulseNextCyclexDP <= startPulseNextCycle;

                endCyclexDP <= endCyclexDN;
            end if;
        end if;
    end process regP;

    -- Avoid mix activation of different CP
    -- Certain rules are "soft" (may be changed to improve or not performance),
    -- whereas other are hard (necessary for proper function). Hard rules are:
    -- * Do not enable if the module is disabled (enablexDI = '0')
    -- * Do not enable if a full injection/charge cycle is not completed
    --   /!\ startPulseNextCycle is combinatorial -> no - 1 when comparing with
    --   cycleCounter.
    -- The rest are soft rules that can be played with.
    -- Currently, a charge pump is allowed to discharge only if higher value
    -- cp are not working (i.e: in cooldown).
    startPulseNextCycle(0) <= '1' when enablexDI = '1' and configCurrentxDP.disableCP1= '0' and
                                        -- Allow activation if not in pulse, or pulse available next cycle
                                        ((anyInPulsexDP = '0') or (endCyclexDP = '1')) and
                                        -- Do not activate if bigger charge pump is in cooldown
                                        (lightweightG = '1' or (
                                          cooldown(2) = '0' and cooldown(1) = '0' and cooldown(0) = '0' and
                                          -- Activate if no bigger charge pump can activate
                                          (configCurrentxDP.singlyCPActivation = '0' or configCurrentxDP.disableCP3 = '1' or compVthN(2) = '1') and
                                          (configCurrentxDP.singlyCPActivation = '0' or configCurrentxDP.disableCP2 = '1' or compVthN(1) = '1')
                                        )) and
                                        -- Activate if threshold is reached
                                        compVthN(0) = '0' else
                     '0';

    startPulseNextCycle(1) <= '1' when enablexDI = '1' and configCurrentxDP.disableCP2 = '0' and
                                        ((anyInPulsexDP = '0') or (endCyclexDP = '1')) and
                                        (lightweightG = '1' or (
                                          -- Do not activate if bigger charge pump is in cooldown
                                          cooldown(2) = '0' and cooldown(1) = '0' and
                                          -- Do not activate if bigger charge pump could activate
                                          (configCurrentxDP.singlyCPActivation = '0' or configCurrentxDP.disableCP3 = '1' or compVthN(2) = '1')
                                        )) and
                              -- Activate if threshold is reached
                              compVthN(1) = '0' else
                     '0';

    startPulseNextCycle(2) <= '1' when enablexDI = '1' and configCurrentxDP.disableCP3 = '0' and
                                        ((anyInPulsexDP = '0') or (endCyclexDP = '1')) and
                                        (lightweightG = '1' or (cooldown(2) = '0')) and
                                        compVthN(2) = '0' else
                     '0';

    enableCPxDN <= inPulsexDN;

    cycleCounterxDN <= (others => '0') when endCyclexDP = '1' else
                       cycleCounterxDP + 1 when anyInPulsexDP else
                       cycleCounterxDP;

    endCyclexDN <= '1' when (cycleCounterxDP = unsigned(cycleLengthCurrentxDP - 2)) and anyInPulsexDP = '1' else
                   '0';

    CP_CHANNEL : for I in 0 to chargePumpNumberC - 1 generate
        inPulsexDN(I) <= '1' when startPulseNextCycle(I) = '1' else
                         '0' when endCyclexDP = '1' else
                         inPulsexDP(I);

        -- Allow activation only if counter bigger than half the previous activation time (capped at cooldownMax)
        -- Second condition is here to ensure proper alignement
        cooldown(I) <= '0' when lightweightG = '1' else
                       '1' when cooldownCounterxDP(I) < cooldownCurrentDurationxDP(I) else
                       '0';

        -- Count number of injection/charge cycles since last activation, capped at cooldownMax
        cooldownCounterxDN(I) <= (others => '0') when lightweightG = '1' else
                                 to_unsigned(1, cooldownCounterxDN(I)) when startPulseNextCycle(I) = '1' else
                                 cooldownCounterxDP(I) + 1;

        -- When starting an activation, save the counter value
        cooldownCurrentDurationxDN(I) <= (others => '0') when lightweightG = '1' else
                                         maximum(minimum(cooldownCounterxDP(I) / 2, cooldownMaxCurrentArray(I)),
                                                 cooldownMinCurrentArray(I)) when startPulseNextCycle(I) = '1' else
                                         cooldownCurrentDurationxDP(I);

    end generate CP_CHANNEL;

    capClkxDN <= '1' when or_reduce(startPulseNextCycle) else
                 '0' when cycleCounterxDP = endTChargeCurrentxDP else
                 capClkxDP;

    vTh1xDO <= not compN_2r(0); -- vTh1N

    cp1ActivatedxDO <= startPulseNextCyclexDP(0);
    cp2ActivatedxDO <= startPulseNextCyclexDP(1);
    cp3ActivatedxDO <= startPulseNextCyclexDP(2);


    enableCP1xDO <= enableCPxDP(0);
    enableCP2xDO <= enableCPxDP(1);
    enableCP3xDO <= enableCPxDP(2);
    capClkxDO <= capClkxDP;

end architecture behavioral;
