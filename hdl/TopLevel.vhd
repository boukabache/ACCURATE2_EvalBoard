--! @file TopLevel.vhd
--! @brief Top-level VHDL file for ACCURATE reading test
--! 

library ieee;
use ieee.std_logic_1164.all;
use ieee.fixed_pkg.all;

library work;
use work.configPkg.all;
use work.IOPkg.all;

library poc;

-- Top-level entity declaration
entity TopLevel is
    port (
        --! System clock (100 MHz)
        clkInxDI     : in std_logic;
        --! Reset signal (NOT PRESENT IN THIS DESIGN)
        -- reset_n : in std_logic;


        -- I2C interface
        fpga_sdaxDIO : inout std_logic;
        fpga_sclxDIO : inout std_logic;


        -- UART port
        rx_fpgaxDI : in  std_logic;   -- FPGA RX data input
        tx_fpgaxDO : out std_logic;    -- FPGA TX data output


        -- ACCURATE interface
        resetOTAxDO : out std_logic; --! Actual reset signal of OTA

        --! Input signals coming from accurate
        vTh1NxDI : in  std_logic; --! Comparator 1 input, currently unused
        vTh2NxDI : in  std_logic; --! Comparator 2 input, used for low_current
        vTh3NxDI : in  std_logic; --! Comparator 3 input, used for medium_current
        vTh4NxDI : in  std_logic; --! Comparator 4 input, used for high_current

        --! define charge/discharge cycle of charge pumps
        capClkxDO    : out std_logic;
        --! Enable low current charge pump. Must by synchronous with cap_clk
        enableCP1xDO : out std_logic;
        --! Enable med current charge pump. Must by synchronous with cap_clk
        enableCP2xDO : out std_logic;
        --! Enable high current charge pump. Must by synchronous with cap_clk
        enableCP3xDO : out std_logic;
        -- END ACCURATE interface

        -- LEDs
        led_g : out std_logic;
        led_r : out std_logic;
        led_b : out std_logic

        -- DEBUG
        -- debug_0 : out std_logic

    );
end entity TopLevel;


architecture rtl of TopLevel is
    -- DEBUG
    signal debug : std_logic;


    -- Global clock
    signal clkGlobal : std_logic;
    signal clk100    : std_logic;
    

    -- I2C interface
    signal i_sdaOutxDO : std_logic;
    signal i_sdaInxDI  : std_logic;
    signal i_sclOutxDO : std_logic;
    signal i_sclInxDI  : std_logic;


    -- DAC7578 I2C interface
    signal i2cDAC7578LockAcquire : std_logic;
    signal i2cDAC7578LockAck     : std_logic;
    signal i2cDAC7578Start       : std_logic;
    signal i2cDAC7578Busy        : std_logic;
    signal i2cDAC7578Ack         : std_logic;
    signal i2cDAC7578AckErr      : std_logic;

    signal i2cDAC7578TxData : std_logic_vector(7 downto 0);

    signal i2cDAC7578TxDataWLength : std_logic_vector(3 downto 0);
    signal i2cDAC7578RxDataWLength : std_logic_vector(3 downto 0);

    -- DAC7578 configuration signals
    signal DAC7578Config : dacConfigRecordT;


    -- ACCURATE signals
    --! Window high for one clock period each Interval
    signal windIntervalxDI : std_logic;
    --! Control interface
    signal configxDI                : accurateRecordT;
    signal configValidxDI           : std_logic;
    signal ps2plResetOTAValidxDI    : std_logic; --! If ps2plResetOTA value is valid.
    signal ps2plResetOTAxDI         : std_logic; --! ps request to reset OTA
    --! Change in voltage over the last Interval period or MAX if OTA is reset
    signal voltageChangeIntervalxDO : std_logic_vector(voltageChangeRegLengthC - 1 downto 0);
    --! The voltageChangeIntervalxDO value is ready
    signal voltageChangeRdyxDO      : std_logic;


    -- Window generator signals
    signal wind100ms           : std_logic; -- 100ms window


begin
    -------------------------- PHASE LOCKED LOOP ------------------------------------
    -- From: 100MHz
    -- To:   20MHz
    pllE: entity work.pll
        generic map (
            -- Values obtained from the icepll tool
            DIVR_G => "0100",
            DIVF_G => "0011111",
            DIVQ_G => "101",
            FILTER_RANGE_G => "010"
        )
        port map (
            clkInxDI        => clkInxDI,  -- 100MHz
            clkInForwardxDO => clk100,    -- 100MHz (forward of input clock)
            clkOutxDO       => clkGlobal  -- 20MHz
    );

    -- debug_0 <= clkGlobal; -- TODO check the new values from the icepll tool


    -------------------------- I2C MASTER ------------------------------------
    i2cMasterE : entity work.i2cMaster
        generic map (
            i2cClockPeriod => 200
        )
        port map (
            clk => clkGlobal,
            rst => '0',

            startxDI  => i2cDAC7578Start,
            busyxDO   => i2cDAC7578Busy,
            ackxDO    => i2cDAC7578Ack,
            ackErrxDO => i2cDAC7578AckErr,

            txDataxDI => i2cDAC7578TxData,

            txDataWLengthxDI => i2cDAC7578TxDataWLength,
            rxDataWLengthxDI => i2cDAC7578RxDataWLength,

            -- To the I2C bus
            sdaOutxDO => i_sdaOutxDO,
            sdaInxDI  => i_sdaInxDI,
            sclOutxDO => i_sclOutxDO
    );

    -- Tri-state buffer for SDA and SCL lines
    fpga_sdaxDIO <= '0' when i_sdaOutxDO = '0' else 'Z';
    i_sdaInxDI <= fpga_sdaxDIO;
    fpga_sclxDIO <= '0' when i_sclOutxDO = '0' else 'Z';

    
    -------------------------- ACCURATE DAC------------------------------------
    DAC7578E : entity work.i2cDAC7578
        port map (
            clk => clkGlobal,
            rst => '0',

            -- I2C arbitration signals
            -- Arbitration is not used in this design
            lockAcquirexDO => open,
            lockAckxDI => '1',

            -- I2C signals
            i2cStartxDO => i2cDAC7578Start,
            i2cTxDataxDO => i2cDAC7578TxData,
            i2cAckxDI => i2cDAC7578Ack,
            i2cAckErrxDI => i2cDAC7578AckErr,
            i2cBusyxDI => i2cDAC7578Busy,
            i2cTxDataWLengthxDO => i2cDAC7578TxDataWLength,
            i2cRxDataWLengthxDO => i2cDAC7578RxDataWLength,

            -- Voltge level ports (12bit width)
            AxDI => DAC7578Config.vOutA, -- A1_Vbias1  
            BxDI => DAC7578Config.vOutB, -- Vcm        
            CxDI => DAC7578Config.vOutC, -- A1_Vth1    
            DxDI => DAC7578Config.vOutD, -- A1_Vcharge+
            ExDI => DAC7578Config.vOutE, -- A1_Vth2    
            FxDI => DAC7578Config.vOutF, -- A1_Vth4    
            GxDI => DAC7578Config.vOutG, -- A1_Vth3    
            HxDI => DAC7578Config.vOutH  -- A1_Vbias3  
    );


    -------------------------- ACCURATE ---------------------------------------
    accurateWrapperE : entity work.accurateWrapper
        port map (
            clk20  => clkGlobal,
            clk100 => clk100,
            rst => '0',

            -- Sampling time, coming from window generator
            windIntervalxDI => wind100ms,

            -- Amout of LSBs of charge counted in the last interval
            std_logic_vector(voltageChangeIntervalxDO) => voltageChangeIntervalxDO,
            -- If voltageChangeIntervalxDO value is ready
            voltageChangeRdyxDO => voltageChangeRdyxDO,

            -- ACCURATE physical I/Os
            -- Comparators inputs
            vTh1NxDI  => vTh1NxDI,
            vTh2NxDI  => vTh2NxDI,
            vTh3NxDI  => vTh3NxDI,
            vTh4NxDI  => vTh4NxDI,
            -- Charge/discharge cycle of charge pumps
            capClkxDO => capClkxDO,
            -- Charge pump enables
            enableCP1xDO => enableCP1xDO,
            enableCP2xDO => enableCP2xDO,
            enableCP3xDO => enableCP3xDO,
            -- Reset OTA
            resetOTAxDO => resetOTAxDO,

            -- Control interface
            ps2plResetOTAValidxDI => ps2plResetOTAValidxDI, --! If ps2plResetOTA value is valid.
            ps2plResetOTAxDI      => ps2plResetOTAxDI, --! ps request to reset OTA
            configxDI             => configxDI, --! Configuration data from PS
            configValidxDI        => configValidxDI
    );

    ps2plResetOTAValidxDI <= '0'; --! Not used in this design
    ps2plResetOTAxDI <= '0';      --! Not used in this design


    -------------------------- WINDOW GENERATOR --------------------------------
    -- More windows width are supported by the window generator
    windowGeneratorE : entity work.windowGenerator
        port map (
            clk                   => clkGlobal,
            rst                   => '0',
            wind100msxDO          => wind100ms
    );


    -------------------------- UART LOGIC --------------------------------------
    UartLogicE : entity work.UartLogic
        port map (
            clk                      => clkGlobal,
            rst                      => '0',
            rxFpgaxDI                => rx_fpgaxDI,
            txFpgaxDO                => tx_fpgaxDO,
            -- voltageChangeIntervalxDI => voltageChangeIntervalxDO,
            -- voltageChangeRdyxDI      => voltageChangeRdyxDO

            -- FOR DEBUG ON REAL HARDWARE
            voltageChangeIntervalxDI => x"C123456789abc",
            voltageChangeRdyxDI      => debug,

            led_g => led_g
    );

    ------------------------- CONFIG REGISTER FILE -----------------------------
    -- Contains the configuration registers for the DAC7578 and ACCURATE
    -- For now default values are hardcoded and utilised
    RegisterFileE : entity work.RegisterFile
        port map (
            clk => clkGlobal,
            rst => '0',

            -- DAC7578 config registers
            dacConfigxDO => DAC7578Config,

            -- ACCURATE config registers
            accurateConfigxDO => configxDI,
            accurateConfigValidxDO => configValidxDI
    );



    -------------------------- DEBUG -------------------------------------------
    process(clkGlobal)
        variable cnt : integer := 0;
    begin
        if rising_edge(clkGlobal) then
            cnt := cnt + 1;
            if cnt = 100000000 then
                debug <= '1';
                cnt := 0;
            else 
                debug <= '0';
            end if; 
        end if;
    end process;

    led_b <= '1';
    led_r <= '1';

end architecture rtl;