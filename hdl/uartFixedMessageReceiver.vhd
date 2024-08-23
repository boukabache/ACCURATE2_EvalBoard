--! @file uartFixedMessageReceiver.vhd
--! @brief Receives a fixed length uart message, with a timer
--!
--! This module is basically a FIFO that can be fully read in a single cycle.

-- Copyright (C) CERN CROME Project

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uartFixedMessageReceiver is
    generic (
        -- The length of the message to send in words
        rxMessageLengthG : integer := 5;
        -- The length of a word in bits
        rxMessageWidthG : integer := 8;
        clkFreqHzG : integer := 50000000;
        timeoutUsG : integer := 100
    );
    port (
        clk : in  std_logic;
        rst : in  std_logic;

        --! The complete content of the data read, first byte received is at bits 7 through 0.
        rxMessagexDO : out std_logic_vector(rxMessageLengthG * rxMessageWidthG - 1 downto 0);
        --! if rxMessagexDO is valid
        rxMessageValidxDO : out std_logic;
        -- Single cycle '1' if the current transaction has timed out
        receiverTimeoutxDO : out std_logic;

        --! High to low transistion indicates new data available
        rxBusyxDI : in  std_logic;
        rxDataxDI : in  std_logic_vector(rxMessageWidthG - 1 downto 0)

    );
end entity uartFixedMessageReceiver;

architecture behavioral of uartFixedMessageReceiver is
    type rxMessageWordsT is array (0 to rxMessageLengthG - 1) of std_logic_vector(rxMessageWidthG - 1 downto 0);
    signal rxInputMessageWords : rxMessageWordsT := (others => (others => '0'));
    signal rxMessageWordsxDP, rxMessageWordsxDN : rxMessageWordsT := (others => (others => '0'));
    signal rxMessageWordReadxDP, rxMessageWordReadxDN : integer range 0 to rxMessageLengthG := rxMessageLengthG;

    signal rxBusyXDP : std_logic := '0';
    signal newWordAvailable : std_logic := '0';

    constant counterTimeoutValC : integer := (timeoutUsG) * (clkFreqHzG/10000000) + 1;
    signal counterTimeoutxDP, counterTimeoutxDN : integer range 0 to counterTimeoutValC := 0;

begin
    regp: process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rxMessageWordReadxDP <= 0;
                rxBusyxDP <= '0';
            else
                rxMessageWordReadxDP <= rxMessageWordReadxDN;
                rxMessageWordsxDP <= rxMessageWordsxDN;
                rxBusyxDP <= rxBusyxDI;

                counterTimeoutxDP <= counterTimeoutxDN;
            end if;
        end if;
    end process regP;

    counterTimeoutxDN <= 0 when counterTimeoutxDP = counterTimeoutValC else
                         0 when rxMessageWordReadxDP = rxMessageLengthG else
                         1 when rxMessageWordReadxDP = 0 and newWordAvailable = '1' else
                         0 when counterTimeoutxDP = 0 else
                         counterTimeoutxDP + 1;

    newWordAvailable <= '1' when rxBusyxDI = '0' and rxBusyxDP = '1' else
                        '0';

    -- transmission is considered ongoing if txMessageWordReadxDN != txMessageLengthG
    rxMessageWordReadxDN <= 0 when rxMessageWordReadxDP = rxMessageLengthG else
                            rxMessageWordReadxDP + 1 when newWordAvailable = '1' else
                            0 when counterTimeoutxDP = counterTimeoutValC else
                            rxMessageWordReadxDP;

    rxMessageWordsxDN <= rxDataxDI & rxMessageWordsxDP(0 to rxMessageLengthG - 2) when newWordAvailable  = '1' else
                         rxMessageWordsxDP;

    rxMessageValidxDO <= '1' when rxMessageWordReadxDP = rxMessageLengthG else
                         '0';

    messageCast: for i in 0 to rxMessageLengthG-1 generate
        rxMessagexDO((i + 1) * rxMessageWidthG - 1 downto i * rxMessageWidthG) <= rxMessageWordsxDP(i);
    end generate;

    receiverTimeoutxDO <= '1' when counterTimeoutxDP = counterTimeoutValC else
                          '0';

end architecture behavioral;

