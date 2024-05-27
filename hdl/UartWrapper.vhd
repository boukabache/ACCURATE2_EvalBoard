--! @file UartWrapper.vhd
--! @brief UART wrapper for UART and FIFO entities
--
--! The reset is active high. Not all the submodules are active high reset
--! compatible. The reset signal is inverted for uart submodules.
--
--! Expose the read interface of the RX FIFO to the top level.
--! Expose the write interface of the TX FIFO to the top level.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UartWrapper is
    generic (
        DATA_WIDTH_G : positive := 8;  --! Width of data bus
        FIFO_DEPTH_G : positive := 16;  --! Depth of FIFO buffer
        CLK_FREQ_G   : positive := 20_000_000;  --! Clock frequency
        BAUD_RATE_G  : positive := 9_600  --! Baud rate
    );
    port (
        -- Clock and reset
        clk : in std_logic;
        rst : in std_logic; --! Active high reset

        -- UART signals
        rxUartxDI : in std_logic;
        txUartxDO : out std_logic;
        
        -- FIFO signals
        fifoDataInxDI  : in std_logic_vector(DATA_WIDTH_G-1 downto 0);
        fifoDataOutxDO : out std_logic_vector(DATA_WIDTH_G-1 downto 0);
        fifoEmptyxDO   : out std_logic;
        fifoFullxDO    : out std_logic;
        fifoReadxDI    : in std_logic;
        fifoWritexDI   : in std_logic
    );
end UartWrapper;

architecture rtl of UartWrapper is
    -- Inverted reset signal
    signal rst_n : std_logic := '1';
    -- Falling edge detection signal
    signal rxBusyUartOld : std_logic := '0';

    -- UART signals
    signal txEnaUart   : std_logic;
    signal txDataUart  : std_logic_vector(DATA_WIDTH_G-1 downto 0);
    signal txBusyUart  : std_logic;
    ---
    signal rxDataUart  : std_logic_vector(DATA_WIDTH_G-1 downto 0);
    signal rxBusyUart  : std_logic;
    signal rxErrorUart : std_logic;
    ---------------

    -- TX FIFO signals
    signal txFifoEmpty  : std_logic;
    signal txFifoRdEn : std_logic;
    ------------------

    -- RX FIFO signals
    signal rxFifoFull  : std_logic;
    signal rxFifoWrEn  : std_logic;
    ------------------

begin
    -- Invert reset signal
    rst_n <= not rst;

    -- UART entity instantiation
    uartE : entity work.uart
        generic map (
            clk_freq  => CLK_FREQ_G,
            baud_rate => BAUD_RATE_G,
            os_rate   => 16,
            d_width   => 8,
            parity    => 0,
            parity_eo => '0'
        )
        port map (
            clk      => clk,
            reset_n  => rst_n, -- The reset signal is active low

            tx       => txUartxDO,
            tx_ena   => txEnaUart,
            tx_data  => txDataUart,
            tx_busy  => txBusyUart,

            rx       => rxUartxDI,
            rx_busy  => rxBusyUart,
            rx_error => rxErrorUart,
            rx_data  => rxDataUart
            
    );
    
    -- Read RX FIFO instantiation
    rxFifoE : entity work.Fifo
        generic map (
            g_WIDTH => DATA_WIDTH_G,
            g_DEPTH => FIFO_DEPTH_G
        )
        port map (
            i_rst_sync => rst,
            i_clk      => clk,
        
            -- FIFO Write Interface (in from uart)
            i_wr_en   => rxFifoWrEn,
            i_wr_data => rxDataUart,
            o_full    => rxFifoFull,
        
            -- FIFO Read Interface (out of UartWrapper)
            i_rd_en   => fifoReadxDI,
            o_rd_data => fifoDataOutxDO,
            o_empty   => fifoEmptyxDO
    );

    -- Write TX FIFO instantiation
    txFifoE : entity work.Fifo
        generic map (
            g_WIDTH => DATA_WIDTH_G,
            g_DEPTH => FIFO_DEPTH_G
        )
        port map (
            i_rst_sync => rst,
            i_clk      => clk,
        
            -- FIFO Write Interface (in from UartWrapper)
            i_wr_en   => fifoWritexDI,
            i_wr_data => fifoDataInxDI,
            o_full    => fifoFullxDO,
        
            -- FIFO Read Interface (to uart)
            i_rd_en   => txFifoRdEn,
            o_rd_data => txDataUart,
            o_empty   => txFifoEmpty
    );

    -- Iniciate the UART transmission as soon as the TX FIFO is not empty
    -- and the UART is not busy (i.e. the previous TX transmission is done).
    txEnaUart <= '1' when txFifoEmpty = '0' and txBusyUart = '0' else '0';

    -- Update the TX FIFO pointer
    -- TODO to check if the FIFO out is updated after the uart read the current data
    txFifoRdEn <= '1' when txEnaUart = '1' else '0';

    
    -- Detect if new data was received by the UART, and store it in the RX FIFO
    -- A transition high to low of the rxBusyUart signal indicates that a new byte
    -- was received by the UART.
    rxFifoP: process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- TODO
            else
                rxBusyUartOld <= rxBusyUart;

                if rxBusyUartOld = '1' and rxBusyUart = '0' then
                    if rxFifoFull = '0' then
                        rxFifoWrEn <= '1';
                    end if;
                else
                    rxFifoWrEn <= '0';
                end if;

            end if;
        end if;
    end process;
    
end rtl;