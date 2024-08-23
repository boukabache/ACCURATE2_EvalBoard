--! @brief sends and receives uart messages, with timeout and ack/nack

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
        uartBusWidthG : integer := 8;
        -- The length of the recieving message, including header
        rxMessageLengthG : integer := 4;
        -- The expected header at the start of the uart transaction.
        -- Its bitwidth must be a multiple of uartBusWidth).
        rxMessageHeaderG : std_logic_vector := x"DD";
        rxTimeoutUsG : integer := 500
    );
    port (
        clk : in  std_logic;
        rst : in  std_logic;


        --! If 0, no attempt at sending (n)ack after a rx command will be done.
        --! If 1, txSendMessagexDI will be ignored, allowing only (n)ack to be send.
        allowRespondToRxxDI : in  std_logic;
        txSendMessagexDI : in  std_logic; -- Sample and start feeding the driver
        --! The complete content of the data to transmit, LSB are transmitted first.
        txMessagexDI : in  std_logic_vector(txMessageLengthG * uartBusWidthG - 1 downto 0);
        --! If this module is currently busy feeding the driver
        feederBusyxDO : out std_logic;

        --! The received message
        rxMessagexDO : out std_logic_vector(rxMessageLengthG * uartBusWidthG - rxMessageHeaderG'length - 1 downto 0);

        --! '1' if rxMessagexDO can be read.
        rxMessageValidxDO : out std_logic;
        --! Single cycle '1' if the rx message recipient cannot make sense of the message
        rxMessageInvalidxDI : in  std_logic;

        --! Transmit pin
        txxDO : out std_logic;
        rxxDI : in  std_logic

    );
end entity uartWrapper;

architecture behavioral of uartWrapper is
    signal rst_n : std_logic := '1';
    signal txBusy : std_logic := '0';
    signal txEna : std_logic := '0';
    signal txData : std_logic_vector(uartBusWidthG - 1 downto 0) := (others => '0');
    signal txMessageLength : integer range 1 to txMessageLengthG := 1;

    signal rxBusy : std_logic := '0';
    signal rxData : std_logic_vector(uartBusWidthG - 1 downto 0) := (others => '0');
    signal rxError : std_logic := '0';
    signal rxTransactionTimeout : std_logic := '0';
    signal rxHeaderError : std_logic := '0';
    signal rxMessage : std_logic_vector(rxMessageLengthG * uartBusWidthG - 1 downto 0);
    signal rxMessageValid : std_logic := '0';

    signal txMessage : std_logic_vector(txMessageLengthG * uartBusWidthG - 1 downto 0) := (others => '0');
    signal txSendMessage : std_logic := '0';
    signal rxStatusVector : std_logic_vector(3 downto 0);

begin
    rst_n <= '0' when rst = '1' else
             '1';

    txMessageLength <= 1 when allowRespondToRxxDI = '1' else
                       txMessageLengthG;

    rxStatusVector <= rxMessageInvalidxDI & rxHeaderError & rxTransactionTimeout & rxError;
    -- If we can respond to rx request, set the lowest word to current status.
    txMessage <= txMessagexDI when allowRespondToRxxDI = '0' else
                 txMessagexDI(txMessageLengthG * uartBusWidthG - 1 downto uartBusWidthG) &
                 std_logic_vector(resize(unsigned(rxStatusVector),
                                         uartBusWidthG));

    txSendMessage <= txSendMessagexDI when allowRespondToRxxDI = '0' else
                     '1' when ((rxMessageInvalidxDI = '1') or
                               (rxHeaderError = '1') or
                               (rxTransactionTimeout = '1') or
                               (rxError = '1') or
                               (rxMessageValid = '1')) else
                     '0';

    uartDriverE : entity work.uartDriver
        generic map (
            clk_freq  => clkFreqG,
            baud_rate => baudRateG,
            os_rate   => 16,
            d_width   => uartBusWidthG,
            parity    => parityG,
            parity_eo => parityEoG
        )
        port map (
            clk      => clk,
            reset_n  => rst_n,
            tx_ena   => txEna,
            tx_data  => txData,
            rx       => rxxDI,
            rx_busy  => rxBusy,
            rx_error => rxError,
            rx_data  => rxData,
            tx_busy  => txBusy,
            tx       => txxDO
        );

    uartFixedMessageFeederE: entity work.uartFixedMessageFeeder
        generic map (
            txMessageMaxLengthG => txMessageLengthG,
            txMessageWidthG => uartBusWidthG
        )
        port map (
            clk => clk,
            rst => rst,

            txSendMessagexDI => txSendMessagexDI,
            txMessageLengthxDI => txMessageLengthG,
            txMessagexDI => txMessagexDI,
            feederBusyxDO => feederBusyxDO,

            txBusyxDI => txBusy,
            txEnaxDO  => txEna,
            txDataxDO => txData
        );

    uartFixedMessageReceiverE: entity work.uartFixedMessageReceiver
        generic map(
            rxMessageLengthG => rxMessageLengthG,
            rxMessageWidthG => uartBusWidthG,
            clkFreqHzG => clkFreqG,
            timeoutUsG => rxTimeoutUsG
        )
        port map(
            clk => clk,
            rst => rst,

            rxMessagexDO => rxMessage,
            rxMessageValidxDO => rxMessageValid,
            receiverTimeoutxDO => rxTransactionTimeout,

            rxBusyxDI => rxBusy,
            rxDataxDI => rxData
        );

        rxHeaderError <= '0' when rxMessageHeaderG'length = 0 else
                         '1' when ((rxMessage(rxMessageHeaderG'length - 1 downto 0) /= rxMessageHeaderG) and
                                   (rxMessageValid = '1')) else
                         '0';

        rxMessageValidxDO <= '0' when rxHeaderError = '1' else
                             '1' when rxMessageValid = '1' else
                             '0';

        rxMessagexDO <= rxMessage(rxMessageLengthG * uartBusWidthG - 1 downto rxMessageHeaderG'length);

end architecture behavioral;

