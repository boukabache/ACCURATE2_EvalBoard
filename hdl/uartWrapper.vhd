library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uartWrapper is
    generic (
        clkFreqG : integer := 40_000_000; --! Frequency of the system clock in hertz
        baudRateG :  integer    := 9_600;      --data link baud rate in bits/second
        parityG :  integer    := 1;           --0 for no parity, 1 for parity
        parityEoG :  std_logic  := '0';        --'0' for even, '1' for odd parity
        -- The length of the message to send in words
        txMessageLengthG : integer := 28;
        -- The length of a word in bits
        txMessageWidthG : integer := 8
    );
    port (
        clk : in  std_logic;
        rst : in  std_logic;

        txSendMessagexDI : in  std_logic; -- Sample and start feeding the driver
        --! The complete content of the data to transmit, LSB are transmitted first.
        txMessagexDI : in  std_logic_vector(txMessageLengthG * 8 - 1 downto 0);
        --! If this module is currently busy feeding the driver
        feederBusyxDO : out std_logic;
        --! Transmit pin
        txxDO       :  out  std_logic

    );
end entity uartWrapper;

architecture behavioral of uartWrapper is
    signal rst_n : std_logic := '1';
    signal txBusy : std_logic := '0';
    signal txEna : std_logic := '0';
    signal txData : std_logic_vector(txMessageWidthG - 1 downto 0) := (others => '0');
begin
    rst_n <= '0' when rst = '1' else
             '1';

    uartDriverE : entity work.uartDriver
        generic map (
            clk_freq  => clkFreqG,
            baud_rate => baudRateG,
            os_rate   => 16,
            d_width   => txMessageWidthG,
            parity    => parityG,
            parity_eo => parityEoG
        )
        port map (
            clk      => clk,
            reset_n  => rst_n,
            tx_ena   => txEna,
            tx_data  => txData,
            rx       => '1',
            rx_busy  => open,
            rx_error => open,
            rx_data  => open,
            tx_busy  => txBusy,
            tx       => txxDO
        );

    uartFixedMessageFeederE: entity work.uartFixedMessageFeeder
        generic map (
            txMessageLengthG => txMessageLengthG,
            txMessageWidthG => txMessageWidthG
        )
        port map (
            clk => clk,
            rst => rst,

            txSendMessagexDI => txSendMessagexDI,
            txMessagexDI => txMessagexDI,
            feederBusyxDO => feederBusyxDO,

            txBusyxDI => txBusy,
            txEnaxDO  => txEna,
            txDataxDO => txData

        );

end architecture behavioral;

