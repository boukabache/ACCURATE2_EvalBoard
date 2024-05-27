--! @file windowGenerator.vhd
--! @brief Generates a 1 clock cycle pulse each 1ms, each 100ms and 1ms before
--! the 100ms periods. Also generates an inhibit signal to prevent the IVC from
--! being reset before a window occurs
--!
--! The voltage from the IVC is read each 1ms.  If an IVC reset were to occur
--! just before the sample window then voltage sample read would occur while the
--! IVC is resetting and the voltage would not be stable. To prevent this from
--! happening an inhibit signal is activated before the window occurs. When the
--! inhibit signal is active the IVC is prevented from resetting until after the
--! window. The inhibit reset signal falls to 0 at the same time as the window.
--! \n
--!
--! The 100ms window is also generated which sets the main cycle window for the
--! system. 1ms before the 100ms window occurs (at 99ms after the cycle started)
--! the wind1msBefore100msxDO signal goes high. This is used to read the
--! parameters from the ECC BRAM. Reading from this BRAM as late as possible
--! (1ms before the parameters are used) ensure the data is stored in the ECC
--! BRAM for as long as possible. Inside the ECC BRAM errors are corrected.
--! When a wind1msBefore100ms window occurs a 1ms window also happens, likewise
--! when a wind100ms window occurs a 1ms window also happens in the same click
--! cycle.

-- Example Outputs:
-- clk:                     ____|****|__...__|****|____|****|____|****|__......
-- wind1msxDO:             |___________________________|*********|____......
--                                                     ^ (always on rising edge of clock)
--
--                         |<----------------- 1ms --------------------->|
-- inhibRstxDO:            |____________|********************************|____......
--                                      |<------ specified period ------>|
--                                      ^ (always on rising edge of clock, ends along with 1ms falling edge)
--
-- clk:                     ____|****|__...__|****|__...__|****|____|****|__...__|****|____|****|____|****|____
--                         |<--------------100 ms ---------------------------------------->|
-- wind100msxDO:           |_____________________________________________________|*********|_____ ......
--                                                                               ^(always on rising edge of clock)
--                                                        .(always on rising edge of clock)
-- wind1msBefore100msxDO:  |______________________________|*********|___...______________________ ......
--                                                        |<-------- 1ms ------->|
--                                                        (1ms difference w.r.t. 100ms rising edge)

-- Copyright (C) CERN CROME Project

--! Use standard library
library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;
--! Required for *CLOCK_PERIOD_NS* constant
use work.configPkg.all;


entity windowGenerator is
    port (
        clk : in  std_logic; --! Clock
        rst : in  std_logic; --! Synchronous active high reset signal

        --! Window high for 1 clock cycle each 100ms
        wind100msxDO          : out std_logic;
        --! Window high for 1 clock cycle each 1ms
        wind1msxDO            : out std_logic;
        --! Window high for 1 clock cycle 1ms before the 100ms window, i.e 99ms after the start of the cycle
        wind1msBefore100msxDO : out std_logic;
        --! High for a specified period before the window to block IVC resets
        inhibRstxDO           : out std_logic
    );
end entity windowGenerator;

architecture behavioral of windowGenerator is

    --*************************************************************************
    -------------------------------- Constants --------------------------------
    --*************************************************************************

    --! The time for which to block an IVC reset before the window occurs
    constant inhibitIvcRstTimeC : natural := integer(30_000 / clkPeriodNsC); -- 30us

    --! Convert 1ms to nano seconds and divide by clock freq
    constant oneMsPeriodC        : natural := (1 * 1_000_000) / clkPeriodNsC;
    constant num1MsCyclesIn100Ms : natural := 100;

    --*************************************************************************
    --------------------------------- Signals ---------------------------------
    --*************************************************************************

    signal cnt1msxDP, cnt1msxDN                         : natural range 0 to oneMsPeriodC - 1;
    signal cnt100msxDP, cnt100msxDN                     : natural range 0 to num1MsCyclesIn100Ms - 1;
    signal wind1msxDP, wind1msxDN                       : std_logic;
    signal inhibRstxDP, inhibRstxDN                     : std_logic;
    signal wind1msBefore100msxDP, wind1msBefore100msxDN : std_logic;
    signal wind100msxDP, wind100msxDN                   : std_logic;

begin

    --*************************************************************************
    --------------------------- Register Process  -----------------------------
    --*************************************************************************

    regP : process (clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                cnt1msxDP             <= 0;
                wind1msxDP            <= '0';
                inhibRstxDP           <= '0';
                cnt100msxDP           <= 0;
                wind100msxDP          <= '0';
                wind1msBefore100msxDP <= '0';
            else
                cnt1msxDP             <= cnt1msxDN;
                wind1msxDP            <= wind1msxDN;
                inhibRstxDP           <= inhibRstxDN;
                cnt100msxDP           <= cnt100msxDN;
                wind100msxDP          <= wind100msxDN;
                wind1msBefore100msxDP <= wind1msBefore100msxDN;

            end if;
        end if;
    end process regP;

    --*************************************************************************
    ------------------------ Window Generator Logic ---------------------------
    --*************************************************************************

    cnt1msxDN  <= 0 when cnt1msxDP = oneMsPeriodC - 1 else cnt1msxDP + 1;
    wind1msxDN <= '1' when cnt1msxDN = oneMsPeriodC - 1 else '0';

    cnt100msxDN <= 0 when (cnt100msxDP = num1MsCyclesIn100Ms - 1 and wind1msxDN = '1') else
                   cnt100msxDP + 1 when wind1msxDN = '1' else
                   cnt100msxDP;

    wind100msxDN          <= '1' when (wind1msxDN = '1' and cnt100msxDN = num1MsCyclesIn100Ms - 1) else
                             '0';
    wind1msBefore100msxDN <= '1' when (wind1msxDN = '1' and cnt100msxDN = num1MsCyclesIn100Ms - 2) else
                             '0';

    inhibRstxDN <= '1' when cnt1msxDN > ((oneMsPeriodC - 1) - inhibitIvcRstTimeC) else '0';

    --*************************************************************************
    ------------------------------- Set Outputs -------------------------------
    --*************************************************************************

    wind1msxDO            <= wind1msxDP;
    wind100msxDO          <= wind100msxDP;
    wind1msBefore100msxDO <= wind1msBefore100msxDP;
    inhibRstxDO           <= inhibRstxDP;

end architecture behavioral;
