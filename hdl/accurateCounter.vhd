--! @file accurateCounter.vhd
--! @brief Counts the number of activations of the charge pumps
--!
--! Counts the number of cycle each of the cpNActivated signals spend high.
--! When samplexDI is raised high, produces the number of counts since the last
--! samplexDI at the cpNCountxDO output after 2 cycles. cpCountsReadyxDO
--! indicates that the counts have been updated to their new value.
--! It is possible for the counter to overflow if the samplexDI signals are
--! too far apart in terms of number of clock cycles, in which case the
--! overflowErrorxDO signal will go high after the sampling.
--!
--! For developers, the fact that the activation signal can only be high every
--! other cycle (due to the charge/injection behavior of the ASIC) is used.
--! If the activation signals are high for more than one consecutive cycle,
--! the counting will fail.
--! For the same reason, samplexDI cannot be held high.
-- Copyright (C) CERN CROME Project

--! Use standard library
library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;
--! For or_reduce
use ieee.std_logic_misc.all;

entity accurateCounter is
    generic (
        -- width is 24 because ceil(log2(0.1 second / 10 nano second)) = 24
        countBitwidthG : integer := 24
    );
    port (
        clk : in  std_logic; --! 100MHz ACCURATE clock
        rst : in  std_logic; --! Synchronous reset

        --! Trigger the readout of the counts and resets the counting
        samplexDI : in  std_logic;

        -- Number of activation in the last samplexDI interval
        -- width is 24 because ceil(log2(0.1 second / 10 nano second)) = 24
        cp1CountxDO : out unsigned(countBitwidthG - 1 downto 0);
        -- Number of activation of cp2 in the last samplexDI interval
        cp2CountxDO : out unsigned(countBitwidthG - 1 downto 0);
        -- Number of activation of cp3 in the last samplexDI interval
        cp3CountxDO : out unsigned(countBitwidthG - 1 downto 0);

        --! The charge pump counts values are ready
        cpCountsReadyxDO : out std_logic;
        overflowErrorxDO : out std_logic;

        cp1ActivatedxDI : in  std_logic; --! High for 1 cycle when cp1 is activated
        cp2ActivatedxDI : in  std_logic; --! High for 1 cycle when cp2 is activated
        cp3ActivatedxDI : in  std_logic --! High for 1 cycle when cp3 is activated
    );

end entity accurateCounter;

architecture behavioral of accurateCounter is
    constant chargePumpNumberC : natural := 3;

    signal cpNActivatedxDN : std_logic_vector(chargePumpNumberC - 1 downto 0) := (others => '0');
    signal cpNActivatedxDP : std_logic_vector(chargePumpNumberC - 1 downto 0) := (others => '0');

    signal overflowCounter : std_logic_vector(chargePumpNumberC - 1 downto 0) := (others => '0');

    signal overflowxDN, overflowxDP : std_logic := '0';
    -- Delayed signal of samplexDI, used to produce voltageChangeRdyxDO.
    -- Its width is 1+processing delay. The processing delay comes from the pipelined addition
    -- of the partial charge sums.
    signal samplexDP : std_logic_vector(2 downto 0) := (others => '0');

    type cpCounterT is
        array (chargePumpNumberC - 1 downto 0) of
        unsigned(cp1CountxDO'range);

    signal cpCounterxDN, cpCounterxDP : cpCounterT := (others => (others => '0'));
    signal cpCountsxDN, cpCountsxDP : cpCounterT := (others => (others => '0'));
    signal chargeSumNext : cpCounterT := (others => (others => '0'));

    signal overflowSampledxDN, overflowSampledxDP : std_logic := '0';
    signal cpCounterSampledxDN, cpCounterSampledxDP : cpCounterT := (others => (others => '0'));

    signal activationWhileResetting : std_logic_vector(chargePumpNumberC - 1 downto 0) := (others => '0');

begin

    cpNActivatedxDN <= cp3ActivatedxDI & cp2ActivatedxDI & cp1ActivatedxDI;
    ------------------------------- Registers ---------------------------------
    regP : process (clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                samplexDP <= (others => '0');
                cpCounterxDP <= (others => (others => '0'));
                cpCounterSampledxDP <= (others => (others => '0'));
                cpCountsxDP <= (others => (others => '0'));
                cpNActivatedxDP <= (others => '0');
                overflowxDP <= '0';
                overflowSampledxDP <= '0';
            else
                samplexDP <= samplexDP(samplexDP'left - 1 downto 0) & samplexDI;
                cpCounterSampledxDP <= cpCounterSampledxDN;
                cpCounterxDP <= cpCounterxDN;
                cpCountsxDP <= cpCountsxDN;
                cpNActivatedxDP <= cpNActivatedxDN;
                overflowxDP <= overflowxDN;
                overflowSampledxDP <= overflowSampledxDN;
            end if;
        end if;
    end process regP;

    CP_CHANNEL : for I in 0 to chargePumpNumberC - 1 generate
        CHANNEL_INCREMENT : entity work.pipelined_increment
            generic map (
                inputBitwidthG => cpCounterxDN(I)'length,
                stageBitwidthG => cpCounterxDN(I)'length / 2,
                signedG => '0'
            )
            port map (
                clk => clk,
                rst => rst,
                axDI => cpCounterxDP(I),
                sumxDO => chargeSumNext(I),
                overflowxDO => overflowCounter(I)
            );

        cpCounterxDN(I) <= to_unsigned(1, cpCounterxDN(I)'length) when activationWhileResetting(I) else
                           to_unsigned(0, cpCounterxDN(I)'length) when samplexDP(0) = '1' else
                           chargeSumNext(I) when cpNActivatedxDP(I) = '1' else
                           cpCounterxDP(I);

        activationWhileResetting(I) <= '1' when (cpNActivatedxDP(I) = '1') and
                                                (samplexDP(1) = '1' or samplexDP(0) = '1') else
                                       '0';
    end generate CP_CHANNEL;

    cpCountsxDN <= cpCounterxDP when samplexDP(0) = '1' else
                   cpCountsxDP;

    overflowxDN <= '1' when or_reduce(overflowCounter) = '1' else
                   '0' when samplexDP(0) = '1' else
                    overflowxDP;

    cpCounterSampledxDN <= cpCounterxDP when samplexDP(0) = '1' else
                           cpCounterSampledxDP;

    overflowSampledxDN <= overflowxDP when samplexDP(0) = '1' else
                          overflowSampledxDP;

    cp1CountxDO <= cpCounterSampledxDP(0);
    cp2CountxDO <= cpCounterSampledxDP(1);
    cp3CountxDO <= cpCounterSampledxDP(2);

    cpCountsReadyxDO <= samplexDP(samplexDP'left);
    overflowErrorxDO <= overflowSampledxDP;

end architecture behavioral;
