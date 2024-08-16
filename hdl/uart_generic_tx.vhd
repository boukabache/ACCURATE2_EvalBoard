--! @file UartLogic.vhd
--! @brief UART logic module, the actual protocol is handled by the uart.vhd module
--
--! This module is instantiating the UartWrapper module and is responsible for
--! the data transmission and reception logic.
--
--! TX: The data to be sent is sampled when the data ready signal is high.
--! Then the data is sent byte by byte, using a sliding window from right to left.
--! Temperature and humidityh data are attached and sent after the charge pump data.
--! As the sht41 data width is not expected to change, the values are hardcoded.
--! Format: 1 byte header - 6 bytes charge pump data - 2 bytes temperature - 2 bytes humidity data
--
--! RX: The data received is sampled when the FIFO is not empty. The expected
--! format is: address(8bit) - 4xdata(8bit). The data is then assembled in 32bit
--! words to obtain: address(8bit) - data(32bit). Address and data is then forwarded
--! to the RegisterFile module.



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.configPkg.all;
use work.IOPkg.all;

entity uart_generic_tx is
    generic (
        txMessageLengthBytesG : integer := 28
    );
    port (
        clk   : in std_logic;
        rst : in std_logic;

        txSendMessagexDI : in std_logic;
        txMessagexDI : in std_logic_vector(txMessageLengthBytesG * 8 - 1 downto 0);

        -- UART port
        rxFpgaxDI : in  std_logic;   -- FPGA RX data input
        txFpgaxDO : out std_logic;    -- FPGA TX data output

        -- Output port to the RegisterFile module
        addressxDO   : out unsigned(registerFileAddressWidthC-1 downto 0); -- Address input
        dataxDO      : out std_logic_vector(registerFileDataWidthC-1 downto 0); -- Data input
        dataValidxDO : out std_logic -- Data valid input

    );
end entity uart_generic_tx;



architecture rtl of uart_generic_tx is
    -- Sample the data once ready
    type txMessageBytesT is array (0 to txMessageLengthBytesG - 1) of std_logic_vector(8 - 1 downto 0);
    signal txInputMessageBytes : txMessageBytesT := (others => (others => '0'));
    signal txMessageBytesxDP, txMessageBytesxDN : txMessageBytesT := (others => (others => '0'));
    signal txMessageByteForwardedxDP, txMessageByteForwardedxDN : integer range 0 to txMessageLengthBytesG := txMessageLengthBytesG;
    -- Counter used in the RX FSM
    -- Used to receive and "assemble" the data before forwarding it to
    -- the RegisterFile module
    signal cnt : integer range 0 to 4 := 0;

    -- UartWrapper signals
    signal fifoFull    : std_logic := '0';
    signal fifoEmpty   : std_logic := '0';
    signal fifoRead    : std_logic := '0';
    signal fifoDataOut : std_logic_vector(7 downto 0) := (others => '0');
    ----------------------

    -- Registered signals
    signal txDataxDP, txDataxDN : std_logic_vector(7 downto 0) := (others => '0');
    signal fifoWriteEnxDP, fifoWriteEnxDN : std_logic := '0';
    ----------------------

    -- State machine
    type StateType is (IDLE_S, SEND_HEADER_S, SEND_S, SEND_TEMP_HUM_S, RECEIVE_S, DONE_S);
    signal state, rxState : StateType := IDLE_S;
    ----------------------

    -- Window signals
    signal RightBoundxDP, RightBoundxDN : integer range 0 to voltageChangeRegLengthC - 1 := 0;
    -- Left bound is calculated as RightBound + 7
    ----------------------

    -- Constants used to pad data when voltageChangeIntervalxDI has a width
    -- not multiple of 8
    constant paddingNumber : natural := voltageChangeRegLengthC mod 8;
    constant paddingVector : std_logic_vector(7 - paddingNumber downto 0) := (others => '0');
    constant RightBoundEdgeCase : integer := voltageChangeRegLengthC - paddingNumber;
    ----------------------

begin
    -- Instantiate UartWrapper module
    UartWrapperE : entity work.UartWrapper
        generic map (
            DATA_WIDTH_G => 8,
            FIFO_DEPTH_G => 1,
            CLK_FREQ_G   => 20_000_000,
            BAUD_RATE_G  => 9_600
        )
        port map (
            clk      => clk,
            rst      => rst,

            -- UART signals
            rxUartxDI => rxFpgaxDI,
            txUartxDO => txFpgaxDO,

            -- FIFO signals
            fifoDataInxDI  => txDataxDP,
            fifoDataOutxDO => fifoDataOut,
            fifoEmptyxDO   => fifoEmpty,
            fifoFullxDO    => fifoFull,
            fifoReadxDI    => fifoRead,
            fifoWritexDI   => fifoWriteEnxDP
    );

    --------------------
    -- TX LOGIC
    --------------------
    txRegP: process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                txMessageByteForwardedxDP <= txMessageLengthBytesG;
            else
                txMessageByteForwardedxDP <= txMessageByteForwardedxDN;
                txMessageBytesxDP <= txMessageBytesxDN;
                txDataxDP <= txDataxDN;
                fifoWriteEnxDP <= fifoWriteEnxDN;
            end if;
        end if;
    end process txRegP;

    messageCast: for i in 0 to txMessageLengthBytesG-1 generate
        txInputMessageBytes(i) <= txMessagexDI((i+1)*8-1 downto i*8);
    end generate;

    -- Transmission is considered ongoing if txMessageByteForwardedxDN != txMessageLengthBytesG
    txMessageByteForwardedxDN <= 0 when txSendMessagexDI else
                                 txMessageByteForwardedxDP + 1 when fifoWriteEnxDP = '1' else
                                 txMessageByteForwardedxDP;

    txMessageBytesxDN <= txInputMessageBytes when txSendMessagexDI else
                         txMessageBytesxDP;

    fifoWriteEnxDN <= '1' when fifoFull = '0' and txMessageByteForwardedxDP /= txMessageLengthBytesG else
                      '0';

    txDataxDN <= txMessageBytesxDP(txMessageByteForwardedxDP);

    --------------------
    -- RX LOGIC
    --------------------
    rxLogicP: process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rxState <= IDLE_S;
                cnt <= 0;
            else
                -- FSM
                case rxState is
                    when IDLE_S =>
                        -- Data received -> fifo not empty
                        if (fifoEmpty = '0') then
                            rxState <= RECEIVE_S;
                        end if;

                    when RECEIVE_S =>
                        case cnt is
                            when 0 =>
                                -- Address
                                addressxDO <= unsigned(fifoDataOut);
                                rxState <= IDLE_S;
                                cnt <= cnt + 1;
                            when 1 =>
                                -- Data
                                dataxDO(7 downto 0) <= fifoDataOut;
                                rxState <= IDLE_S;
                                cnt <= cnt + 1;
                            when 2 =>
                                -- Data
                                dataxDO(15 downto 8) <= fifoDataOut;
                                rxState <= IDLE_S;
                                cnt <= cnt + 1;
                            when 3 =>
                                -- Data
                                dataxDO(23 downto 16) <= fifoDataOut;
                                rxState <= IDLE_S;
                                cnt <= cnt + 1;
                            when 4 =>
                                -- Data
                                dataxDO(31 downto 24) <= fifoDataOut;
                                rxState <= DONE_S;
                        end case;

                    when DONE_S =>
                        rxState <= IDLE_S;
                        cnt <= 0;


                    when others =>
                        rxState <= IDLE_S;
                end case;
            end if;
        end if;
    end process rxLogicP;

    -- Write enable signal for the UART's RX FIFO
    -- As the FIFO is FWFT, the read signal is asserted immediately: the byte
    -- is already available (no need to wait a clock cycle for the data to be available
    -- after fifoRead is asserted).
    fifoRead <= '1' when rxState = RECEIVE_S else
                '0';

    -- When reception is done, signalise the RegisterFile module that the data is valid
    dataValidxDO <= '1' when rxState = DONE_S else
                    '0';

end architecture rtl;
