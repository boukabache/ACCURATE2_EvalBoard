--! @file UartLogic.vhd
--! @brief UART logic module, the actual protocol is handled by the uart.vhd module
--
--! This module is instantiating the UartWrapper module and is responsible for
--! the data transmission and reception logic.
--
--! TX: The data to be sent is sampled when the data ready signal is high.
--! Then the data is sent byte by byte, using a sliding window from left to right.
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

entity UartLogic is
    port (
        clk   : in std_logic;
        rst : in std_logic;

        -- Data to send
        voltageChangeIntervalxDI : in std_logic_vector(voltageChangeRegLengthC - 1 downto 0);
        -- Data ready to be sent
        voltageChangeRdyxDI      : in std_logic;

        -- UART port
        rxFpgaxDI : in  std_logic;   -- FPGA RX data input
        txFpgaxDO : out std_logic;    -- FPGA TX data output

        -- Output port to the RegisterFile module
        addressxDO   : out unsigned(registerFileAddressWidthC-1 downto 0); -- Address input
        dataxDO      : out std_logic_vector(registerFileDataWidthC-1 downto 0); -- Data input
        dataValidxDO : out std_logic; -- Data valid input

        -- DEBUG
        led_g : out std_logic := '0'
        
    );
end entity UartLogic;



architecture rtl of UartLogic is
    -- Sample the data once ready
    signal voltageChangeIntervalxDP : std_logic_vector(voltageChangeRegLengthC - 1 downto 0) := (others => '0');

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
    type StateType is (IDLE_S, SEND_S, RECEIVE_S, DONE_S);
    signal state, rxState : StateType := IDLE_S;
    ----------------------

    -- Window signals
    signal RightBoundxDP, RightBoundxDN : integer range 0 to voltageChangeRegLengthC := 0;
    signal LeftBoundxDP, LeftBoundxDN   : integer range 0 to voltageChangeRegLengthC := 7;
    ----------------------

    -- Constants used to pad data when voltageChangeIntervalxDI has a width
    -- not multiple of 8
    constant paddingNumber : natural := voltageChangeRegLengthC mod 8;
    constant paddingVector : std_logic_vector(7 - paddingNumber downto 0) := (others => '0');
    constant RightBoundEdgeCase : integer := voltageChangeRegLengthC - paddingNumber;
    ----------------------

    -- DEBUG
    signal flag : std_logic := '0';

begin
    -- Instantiate UartWrapper module
    UartWrapperE : entity work.UartWrapper
        generic map (
            DATA_WIDTH_G => 8,
            FIFO_DEPTH_G => 16,
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
    logicP: process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE_S;
            else
                -- Registers update
                LeftBoundxDP <= LeftBoundxDN;
                RightBoundxDP <= RightBoundxDN;
                txDataxDP <= txDataxDN;
                fifoWriteEnxDP <= fifoWriteEnxDN;

                -- FSM
                case state is
                    when IDLE_S =>
                        -- Data ready to be sent
                        if (voltageChangeRdyxDI = '1') then
                            state <= SEND_S;
                            -- Reset the window when starting a new transmission
                            LeftBoundxDP <= 7;
                            RightBoundxDP <= 0;
                            -- Sample the data to send
                            voltageChangeIntervalxDP <= voltageChangeIntervalxDI;
                        end if;
                        
                    when SEND_S =>
                        -- Check if the full data has been sent
                        if (LeftBoundxDP = voltageChangeRegLengthC) then
                            state <= IDLE_S;
                        end if;

                    when others =>
                        state <= IDLE_S;
                end case;
            end if;
        end if;
    end process logicP;

    -- Write enable signal for the UART's TX FIFO
    fifoWriteEnxDN <= '1' when state = SEND_S and fifoFull = '0'
                    else '0';
    
    -- The data window to be sent.
    -- The window is slinding from right to left (LSB to MSB) and is 8 bits wide.
    -- Special case when the window is not 8 bits wide -> the window is padded with 0s.
    txDataxDN <= paddingVector & voltageChangeIntervalxDP(voltageChangeIntervalxDP'left downto RightBoundEdgeCase)
                when (RightBoundxDP) >= RightBoundEdgeCase else 
                voltageChangeIntervalxDP(RightBoundxDP+7 downto RightBoundxDP);

    -- Increment the right bound of the window when falling edge is detected.
    -- Falling edge signify the end of the transmission of a byte.
    -- When the last window is transmitted, no increment is done.
    RightBoundxDN <= (RightBoundxDP + 8) when state = SEND_S
                        and LeftBoundxDP /= voltageChangeRegLengthC
                        else RightBoundxDP;

    -- Increment the left bound of the window when falling edge is detected.
    -- Falling edge signify the end of the transmission of a byte.
    -- The length of the data can be not 8 bits aligned, extra care must be taken.
    -- When the last window is transmitted, no increment is done.
    LeftBoundxDN <= (LeftBoundxDP + 8) when state = SEND_S
                        and (LeftBoundxDP + 8) <= voltageChangeRegLengthC
                        else voltageChangeRegLengthC when state = SEND_S
                        else LeftBoundxDP;



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
                        -- Assemble the data
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
                        -- Data received
                        rxState <= IDLE_S;
                        cnt <= 0;
                        flag <= not flag;


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
    fifoRead <= '1' when rxState = RECEIVE_S else '0';

    -- When reception is done, signalise the RegisterFile module that the data is valid
    dataValidxDO <= '1' when rxState = DONE_S else '0';

    led_g <= '0' when flag = '0' else '1';
                
end architecture rtl;