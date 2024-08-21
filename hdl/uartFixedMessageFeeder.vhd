--! @file uartFixedMessageFeeder.vhd
--! @brief Feeds the uart driver with a fixed length message on demand.
--!
--! This module is basically a FIFO that can be fully set in a single cycle.
--! If the busy signal is low, it will shift the data from LSB to MSB.
--! The sampling and start of feeding the driver are triggered by the
--! txSendMessagexDI bit. As long as feederBusyxDO is high, no new sampling
--! must be triggered.

-- Copyright (C) CERN CROME Project

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uartFixedMessageFeeder is
    generic (
        -- The length of the message to send in words
        txMessageLengthG : integer := 28;
        -- The length of a word in bits
        txMessageWidthG : integer := 8
    );
    port (
        clk : in  std_logic;
        rst : in  std_logic;

        txSendMessagexDI : in  std_logic; -- Sample and start feeding the driver
        -- The complete content of the data to transmit, LSB are transmitted first.
        txMessagexDI : in  std_logic_vector(txMessageLengthG * 8 - 1 downto 0);
        -- If this module is currently busy feeding the driver
        feederBusyxDO : out std_logic;

        txBusyxDI : in  std_logic; -- driver is busy
        txEnaxDO  : out std_logic; --initiate word transmission
        txDataxDO : out std_logic_vector(txMessageWidthG - 1 downto 0) -- Data word to transmit

    );
end entity uartFixedMessageFeeder;

architecture behavioral of uartFixedMessageFeeder is
    type txMessageWordsT is array (0 to txMessageLengthG - 1) of std_logic_vector(txMessageWidthG - 1 downto 0);
    signal txInputMessageWords : txMessageWordsT := (others => (others => '0'));
    signal txMessageWordsxDP, txMessageWordsxDN : txMessageWordsT := (others => (others => '0'));
    signal txMessageByteForwardedxDP, txMessageByteForwardedxDN : integer range 0 to txMessageLengthG := txMessageLengthG;

    signal txDataxDP, txDataxDN : std_logic_vector(txDataxDO'range) := (others => '0');
    signal txEnaxDP, txEnaxDN : std_logic := '0';

begin
    txRegp: process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                txMessageByteForwardedxDP <= txMessageLengthG;
            else
                txMessageByteForwardedxDP <= txMessageByteForwardedxDN;
                txMessageWordsxDP <= txMessageWordsxDN;
                txDataxDP <= txDataxDN;
                txEnaxDP <= txEnaxDN;
            end if;
        end if;
    end process txRegP;

    messageCast: for i in 0 to txMessageLengthG-1 generate
        txInputMessageWords(i) <= txMessagexDI((i + 1) * 8 - 1 downto i * 8);
    end generate;

    -- transmission is considered ongoing if txMessageByteForwardedxDN != txMessageLengthG
    txMessageByteForwardedxDN <= 0 when txSendMessagexDI = '1' else
                                 txMessageByteForwardedxDP + 1 when txEnaxDP = '1' else
                                 txMessageByteForwardedxDP;

    txMessageWordsxDN <= txInputMessageWords when txSendMessagexDI  = '1' else
                         txMessageWordsxDP;

    txEnaxDN <= '1' when txBusyxDI = '0' and txMessageByteForwardedxDP /= txMessageLengthG else
                '0';

    txDataxDN <= (others => '0') when txMessageByteForwardedxDP = txMessageLengthG else
                 txMessageWordsxDP(txMessageByteForwardedxDP);

    feederBusyxDO <= '0' when txMessageByteForwardedxDP = txMessageLengthG else
                     '1';

    txEnaxDO <= txEnaxDN;
    txDataxDO <= txDataxDN;


end architecture behavioral;

