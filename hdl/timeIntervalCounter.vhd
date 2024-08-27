--! @file timeIntervalCounter.vhd
--! @brief Tracks the time interval between activation
--!
--! Counts the number of clock cycle elapsed between the last two input high.
--! If the output number is negative, the counter has overflowed and is invalid.
-- Copyright (C) CERN CROME Project

--! Use standard library
library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;

entity timeIntervalCounter is
    generic (
        countBitwidthG : integer := 16;
        -- Slowing down the clock for counting. This avoids ending up with unreasonably large bitwidths
        slowFactorG : integer := 2
    );
    port (
        clk : in  std_logic; --! Clock
        rst : in  std_logic; --! Synchronous reset

        inxDI : in  std_logic; --! Interval signal

        -- Number of activation of cp1 in the last samplexDI interval
        lastIntervalDurationxDO : out unsigned (countBitwidthG - 1 downto 0)

    );
end entity timeIntervalCounter;

architecture behavioral of timeIntervalCounter is
    signal intervalCounterxDN, intervalCounterxDP : unsigned (countBitwidthG + slowFactorG - 1 downto 0) := (others => '0');

    signal lastIntervalDurationxDN, lastIntervalDurationxDP : unsigned (countBitwidthG - 1 downto 0) := (others => '0');
begin

    ------------------------------- Registers ---------------------------------
    regP : process (clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                intervalCounterxDP <= (others => '0');
                lastIntervalDurationxDP <= (others => '0');
            else
                intervalCounterxDP <= intervalCounterxDN;
                lastIntervalDurationxDP <= lastIntervalDurationxDN;
            end if;
        end if;
    end process regP;

    intervalCounterxDN <= (others => '0') when inxDI = '1' else
                          intervalCounterxDP + 1;

    lastIntervalDurationxDN <= intervalCounterxDP(intervalCounterxDP'left downto slowFactorG) when inxDI = '1' else
                               lastIntervalDurationxDP;

    lastIntervalDurationxDO <= lastIntervalDurationxDP;
end architecture behavioral;
