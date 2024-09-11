--! @file sampleResetCounter.vhd
--! @brief Tracks the time interval between activation
--!
--! Generic, multi-purpose counter. The internal counter's value is exposed to
--! resultxDO after samplexDI is high. It increments every cycle incrementxDI is
--! high, and can be reset through resetxDI, which takes precedence over
--! everything else. If reset and increment are both high, the counter is reset
--! to 1, so that any cycle with increment is accounted for.
-- Copyright (C) CERN CROME Project

--! Use standard library
library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;

entity sampleResetCounter is
    generic (
        --! The bitwidth of the counter (and hence resultxDO)
        countBitwidthG : integer := 16;
        --! Slowing down the clock by factor of 2^n for counting. This avoids ending up with unreasonably large bitwidths.
        slowFactorG : integer := 0
    );
    port (
        clk : in  std_logic; --! Clock
        rst : in  std_logic; --! Synchronous reset

        --! Samples the current value of the counter and ouputs it next cycle
        samplexDI : in std_logic;
        --! Reset the counter to zero
        resetxDI : in std_logic;
        --! Increments the counter
        incrementxDI : in std_logic;

        --! Number of activation of cp1 in the last samplexDI interval
        resultxDO : out unsigned (countBitwidthG - 1 downto 0);
        --! Overflow occured in the counter
        overflowxDO : out std_logic

    );
end entity sampleResetCounter;

architecture behavioral of sampleResetCounter is
    constant stageNumberC : integer := (slowFactorG + 1);

    signal counterxDN, counterxDP : unsigned(countBitwidthG + slowFactorG - 1 downto 0) := (others => '0');
    signal nextCount : unsigned(countBitwidthG + slowFactorG - 1 downto 0) := (others => '0');
    signal stageNumberxDN, stageNumberxDP : integer range 0 to slowFactorG + 1 := slowFactorG + 1;

    signal resultxDN, resultxDP : unsigned(countBitwidthG - 1 downto 0) := (others => '0');

    constant counterMaxValC : unsigned(counterxDP'range) := (others => '1');

    signal overflowIncrement : std_logic := '0';
    signal overflowxDN, overflowxDP : std_logic := '0';
    signal overflowResultxDN, overflowResultxDP : std_logic := '0';
begin

    ------------------------------- Registers ---------------------------------
    regP : process (clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                counterxDP <= (others => '0');
                resultxDP <= (others => '0');
                overflowxDP <= '0';
                overflowResultxDP <= '0';

                stageNumberxDP <= slowFactorG + 1;
            else
                counterxDP <= counterxDN;
                resultxDP <= resultxDN;
                overflowxDP <= overflowxDN;
                overflowResultxDP <= overflowResultxDN;

                stageNumberxDP <= stageNumberxDN;
            end if;
        end if;
    end process regP;

    pip_incE : entity work.pipelined_increment
        generic map (
            inputBitwidthG => countBitwidthG + slowFactorG,
            stageBitwidthG => (countBitwidthG + slowFactorG) / (slowFactorG + 1)
        )
        port map (
            clk  => clk,
            rst  => rst,
            axDI   => counterxDP,
            sumxDO => nextCount,
            overflowxDO => overflowIncrement
    );

    stageNumberxDN <= 0 when incrementxDI = '1' and (counterxDP >= slowFactorG) else
                      stageNumberxDP + 1 when stageNumberxDP /= slowFactorG + 1 else
                      slowFactorG + 1;

    counterxDN <= to_unsigned(1, counterxDN'length) when resetxDI = '1' and stageNumberxDN = slowFactorG else
                  (others => '0') when resetxDI = '1' else
                  nextCount when stageNumberxDN = slowFactorG else
                  counterxDP;

    overflowxDN <= '0' when resetxDI = '1' else
                   '1' when overflowIncrement = '1' else
                   overflowxDP;

    resultxDN <= counterxDP(counterxDP'left downto slowFactorG) when samplexDI = '1' else
                 resultxDP;

    overflowResultxDN <= overflowxDP when samplexDI = '1' else
                         overflowResultxDP;

    resultxDO <= resultxDP;
    overflowxDO <= overflowxDP;

    default clock is rising_edge(clk);
    INITIAL_RESET : restrict {not rst[+]};

    -- pIncrement : assert always (incrementxDI and not resetxDI) |=> ((counterxDP = prev(counterxDP) + 1));
    -- pReset0 : assert always (resetxDI and not incrementxDI) |=> (counterxDP = 0);
    -- pReset1 : assert always (resetxDI and incrementxDI) |=> (counterxDP = 1);
    -- pOverflow : assert always (counterxDP = counterMaxValC and incrementxDI and not resetxDI) |=> overflowxDP;

end architecture behavioral;
