--! @file UartLogic.vhd
--! @brief UART logic module, the actual protocol is handled by the uart.vhd module
--!
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
    -- Register where the data is sampled
    signal voltageChangeIntervalxDP : std_logic_vector(voltageChangeRegLengthC - 1 downto 0) := (others => '0');

    -- UART signals
    signal i_rx_busy  : std_logic;
    signal i_rx_error : std_logic;
    signal i_rx_data  : std_logic_vector(7 downto 0);
    signal i_tx_busy  : std_logic;

    -- Registered signals
    signal txEnablexDP, txEnablexDN : std_logic := '0';
    signal txDataxDP, txDataxDN     : std_logic_vector(7 downto 0) := (others => '0');

    -- State machine
    type StateType is (IDLE_S, SEND_S, RECEIVE_S);
    signal state : StateType := IDLE_S;

    -- Window signals
    signal RightBoundxDP, RightBoundxDN : integer range 0 to voltageChangeRegLengthC := 0;
    signal LeftBoundxDP, LeftBoundxDN   : integer range 0 to voltageChangeRegLengthC := 7;

    -- Signals to keep track of falling edge of i_tx_busy
    -- xDP and xDN are used to store the PREVIOUS and current (present)
    -- value of the signal respectively.
    signal txBusyxDP, txBusyxDN : std_logic := '0';

    -- Constants used to pad data when voltageChangeIntervalxDI has a width
    -- not multiple of 8
    constant paddingNumber : natural := voltageChangeRegLengthC mod 8;
    constant paddingVector : std_logic_vector(7 - paddingNumber downto 0) := (others => '0');
    constant RightBoundEdgeCase : integer := voltageChangeRegLengthC - paddingNumber;
    

begin
    -- Instantiate uart module
    -- TODO to be replaced with new UartWrapper (uart + fifos)
    uartE : entity work.uart
        generic map (
            clk_freq  => 25_000_000,
            baud_rate => 9_600,
            os_rate   => 16,
            d_width   => 8,
            parity    => 0,
            parity_eo => '0'
        )
        port map (
            clk      => clk,
            reset_n  => '1',
            tx_ena   => txEnablexDP,
            tx_data  => txDataxDP,
            rx       => rxFpgaxDI,
            rx_busy  => i_rx_busy,
            rx_error => i_rx_error,
            rx_data  => i_rx_data,
            tx_busy  => i_tx_busy,
            tx       => txFpgaxDO
    );
    
    -- Enable the UART when the state is SEND_S and the UART is not busy.
    -- This initiate the transmission of a new byte. The pulse is 1 clock cycle long.
    txEnablexDN <= '1' when state = SEND_S and i_tx_busy = '0' and LeftBoundxDP /= voltageChangeRegLengthC else '0';
    
    -- The data window to be sent.
    -- The window is slinding from right to left (LSB to MSB) and is 8 bits wide.
    -- Special case when the window is not 8 bits wide -> the window is padded with 0s.
    txDataxDN <= paddingVector & voltageChangeIntervalxDP(voltageChangeIntervalxDP'left downto RightBoundEdgeCase)
                when (RightBoundxDP) >= RightBoundEdgeCase else 
                voltageChangeIntervalxDP(RightBoundxDP+7 downto RightBoundxDP);

    -- Increment the right bound of the window when falling edge is detected.
    -- Falling edge signify the end of the transmission of a byte.
    -- When the last window is transmitted, no increment is done.
    RightBoundxDN <= (RightBoundxDP + 8) when txBusyxDN = '0' and txBusyxDP = '1'
                        and LeftBoundxDP /= voltageChangeRegLengthC
                        else RightBoundxDP;

    -- Increment the left bound of the window when falling edge is detected.
    -- Falling edge signify the end of the transmission of a byte.
    -- The length of the data can be not 8 bits aligned, extra care must be taken.
    -- When the last window is transmitted, no increment is done.
    LeftBoundxDN <= (LeftBoundxDP + 8) when txBusyxDN = '0' and txBusyxDP = '1'
                        and (LeftBoundxDP + 8) <= voltageChangeRegLengthC
                        else voltageChangeRegLengthC when txBusyxDN = '0' and txBusyxDP = '1'
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
                txEnablexDP <= txEnablexDN;
                txDataxDP <= txDataxDN;

                -- Falling edge detection - update signals
                txBusyxDN <= i_tx_busy;
                txBusyxDP <= txBusyxDN;

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
                        if (i_rx_busy = '1') then
                            state <= RECEIVE_S;
                        end if;

                    when SEND_S =>
                        -- Check if the full data has been sent
                        if (LeftBoundxDP = voltageChangeRegLengthC and i_tx_busy = '0') then
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