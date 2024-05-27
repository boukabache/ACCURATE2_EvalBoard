--! @file UartLogic.vhd
--! @brief UART logic module, the actual protocol is handled by the uart.vhd module
--
--! For now, is only in charge of sending the voltageChangeIntervalxDI data 
--! out of the UART port.
--! Next steps are to also implement the reception of the data from the UART port
--! so that default values of DAC and ACCURATE can be set from the PC. 

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
        txFpgaxDO : out std_logic    -- FPGA TX data output
        
    );
end entity UartLogic;



architecture rtl of UartLogic is
    -- Sample the data once ready
    signal voltageChangeIntervalxDP : std_logic_vector(voltageChangeRegLengthC - 1 downto 0) := (others => '0');

    -- UartWrapper signals
    signal fifoFull    : std_logic := '0';
    signal fifoEmpty   : std_logic := '0';
    signal fifoRead    : std_logic := '0';
    signal fifoDataOut : std_logic_vector(7 downto 0) := (others => '0');
    ----------------------


    -- Registered signals
    signal txDataxDP, txDataxDN : std_logic_vector(7 downto 0) := (others => '0');
    signal fifoWriteEnxDP, fifoWriteEnxDN : std_logic := '0';

    -- State machine
    type StateType is (IDLE_S, SEND_S, RECEIVE_S);
    signal state : StateType := IDLE_S;

    -- Window signals
    signal RightBoundxDP, RightBoundxDN : integer range 0 to voltageChangeRegLengthC := 0;
    signal LeftBoundxDP, LeftBoundxDN   : integer range 0 to voltageChangeRegLengthC := 7;

    -- Constants used to pad data when voltageChangeIntervalxDI has a width
    -- not multiple of 8
    constant paddingNumber : natural := voltageChangeRegLengthC mod 8;
    constant paddingVector : std_logic_vector(7 - paddingNumber downto 0) := (others => '0');
    constant RightBoundEdgeCase : integer := voltageChangeRegLengthC - paddingNumber;
    

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

            rxUartxDI => rxFpgaxDI,
            txUartxDO => txFpgaxDO,

            fifoDataInxDI  => txDataxDP,
            fifoDataOutxDO => fifoDataOut,
            fifoEmptyxDO   => fifoEmpty,
            fifoFullxDO    => fifoFull,
            fifoReadxDI    => fifoRead,
            fifoWritexDI   => fifoWriteEnxDP
    );

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

    logicP: process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE_S;
                LeftBoundxDP <= 7;
                RightBoundxDP <= 0;
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
                        -- Data received
                        -- if (something) then
                        --     state <= RECEIVE_S;
                        -- end if;

                    when SEND_S =>
                        -- Check if the full data has been sent
                        if (LeftBoundxDP = voltageChangeRegLengthC) then
                            state <= IDLE_S;
                        end if;

                    when RECEIVE_S =>
                        -- TODO

                    when others =>
                        state <= IDLE_S;
                end case;
            end if;
        end if;
    end process logicP;


    
end architecture rtl;


-- process (clk)
-- begin
--     if rising_edge(clk) then
--         rx_busy_present <= i_rx_busy;
--         rx_busy_old     <= rx_busy_present;

--         -- Falling edge detection
--         if rx_busy_old = '1' and rx_busy_present = '0' then
--             -- New receive data is available
--             case state is
--             when idle =>
--                 if i_rx_data(7 downto 4) = x"D" then -- DAC
--                     bytes_left <= 2;
--                     state <= receive_data;
--                     -- Pick the voltage line
--                     if i_rx_data(3 downto 0) = x"0" then
--                         voltage_line <= VthA;
--                     elsif i_rx_data(3 downto 0) = x"1" then
--                         voltage_line <= VthB;
--                     elsif i_rx_data(3 downto 0) = x"2" then
--                         voltage_line <= VthC;
--                     elsif i_rx_data(3 downto 0) = x"3" then
--                         voltage_line <= VthD;
--                     elsif i_rx_data(3 downto 0) = x"4" then
--                         voltage_line <= VthE;
--                     elsif i_rx_data(3 downto 0) = x"5" then
--                         voltage_line <= VthF;
--                     elsif i_rx_data(3 downto 0) = x"6" then
--                         voltage_line <= VthG;
--                     elsif i_rx_data(3 downto 0) = x"7" then
--                         voltage_line <= VthH;
--                     end if;
--                 end if;
--             when receive_data =>
--                 case voltage_line is
--                 when VthA =>
--                     if bytes_left = 2 then
--                         VthA(7 downto 0) <= i_rx_data(7 downto 0);
--                         bytes_left <= bytes_left - 1;
--                     elsif bytes_left = 1 then
--                         VthA(11 downto 8) <= i_rx_data(3 downto 0);
--                         state <= idle;
--                     end if;
--                 end case;
--             end case;
                    

--         end if;

--     end if;
-- end process;