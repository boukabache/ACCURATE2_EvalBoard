--! @file TopLevel.vhd
--! @brief Top-level VHDL file for ACCURATE reading test
--
--! A brief explanation of the logic of the design:
--! PLL: Takes the clock coming from a pad connected to an
--! external 100MHz oscillator and generates a 20MHz clock. The input clock
--! is also forwarded to the output.
--! ACCURATE: The AccurateWrapper receive the configuration data from the register
--! file and the sampling tempo from the window generator. It drives the ASIC and
--! outputs the amount of charge counted in the last interval (in LSBs).
--! DAC: Sets the reference voltages used internally by ACCURATE. It is
--! programmed via I2C using default values at startup. The values are update
--! during operations as soon as the register file receive new values.
--! Register file: Contains the configuration registers for the DAC and ACCURATE.
--! Default values are hardcoded and utilised during startup. During operations
--! new values can be sent via UART interface.
--! UART: In charge of sending the ACCURATE output to the external world and
--! receiving new configuration data from the user.

library ieee;
use ieee.std_logic_1164.all;
use ieee.fixed_pkg.all;
use ieee.numeric_std.all;

library work;
use work.configPkg.all;
use work.IOPkg.all;
use work.accurateConfigPkg.all;


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


        -- UART interface: FPGA - USB
        rxUartUsbxDI : in  std_logic;    -- FPGA RX data input
        txUartUsbxDO : out std_logic;    -- FPGA TX data output


        -- UART interface: FPGA - MCU
        rxUartMcuxDI : in  std_logic;    -- FPGA RX data input
        txUartMcuxDO : out std_logic;    -- FPGA TX data output


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


        debug_0 : out std_logic

    );
end entity TopLevel;


architecture rtl of TopLevel is
    -- DEBUG
    signal debug : std_logic;


    -- Global clock
    signal clkGlobal : std_logic := '0';
    signal clk100    : std_logic;
    signal clk40     : std_logic;
    ----------------------


    -- I2C interface
    signal i_sdaOutxDO : std_logic;
    signal i_sdaInxDI  : std_logic;
    signal i_sclOutxDO : std_logic;
    signal i_sclInxDI  : std_logic;
    ----------------------


    -- DAC7578 I2C interface
    signal i2cDAC7578LockAcquire : std_logic;
    signal i2cDAC7578LockAck     : std_logic;
    signal i2cDAC7578Start       : std_logic;
    signal i2cDAC7578Busy        : std_logic;
    signal i2cDAC7578Ack         : std_logic;
    signal i2cDAC7578AckErr      : std_logic;

    signal i2cDAC7578TxData : std_logic_vector(7 downto 0);
    signal i2cDAC7578RxData : std_logic_vector(7 downto 0);

    signal i2cDAC7578TxDataWLength : std_logic_vector(3 downto 0);
    signal i2cDAC7578RxDataWLength : std_logic_vector(3 downto 0);
    ----------------------


    -- SHT41 I2C interface
    signal i2cShtLockAcquire : std_logic;
    signal i2cShtLockAck     : std_logic;
    signal i2cShtStart       : std_logic;
    signal i2cShtBusy        : std_logic;
    signal i2cShtAck         : std_logic;
    signal i2cShtAckErr      : std_logic;

    signal i2cShtTxData : std_logic_vector(7 downto 0);
    signal i2cShtRxData : std_logic_vector(7 downto 0);

    signal i2cShtTxDataWLength : std_logic_vector(3 downto 0);
    signal i2cShtRxDataWLength : std_logic_vector(3 downto 0);
    ----------------------


    -- I2C Master
    signal i2cMasterStart  : std_logic;
    signal i2cMasterBusy   : std_logic;
    signal i2cMasterAck    : std_logic;
    signal i2cMasterAckErr : std_logic;

    signal i2cMasterTxData : std_logic_vector(7 downto 0);
    signal i2cMasterRxData : std_logic_vector(7 downto 0);

    signal i2cMasterTxDataWLength : std_logic_vector(3 downto 0);
    signal i2cMasterRxDataWLength : std_logic_vector(3 downto 0);
    ----------------------


    -- DAC7578 configuration signals
    signal DAC7578Config : dacConfigRecordT;

    -- SHT41 signals
    signal sht41Meas : sht41RecordT;


    -- ACCURATE signals
    --! Control interface
    signal config                : accurateRecordT;
    signal configValid           : std_logic;
    signal resetOTARequestValid    : std_logic; --! If resetOTARequest value is valid.
    signal resetOTARequest         : std_logic; --! ps request to reset OTA
    --! Change in voltage over the last Interval period or MAX if OTA is reset
    signal voltageChangeInterval : std_logic_vector(voltageChangeRegLengthC - 1 downto 0);

    signal chargeMeasurementTmp : signed(44 - 1 downto 0);
    --! The voltageChangeInterval value is ready
    signal voltageChangeRdy      : std_logic;
    ----------------------
    signal cp1Count : unsigned(24 - 1 downto 0);
    signal cp2Count : unsigned(24 - 1 downto 0);
    signal cp3Count : unsigned(24 - 1 downto 0);
    signal cp1LastInterval : signed(27-1 downto 0);

    -- Window generator signals
    signal wind100ms           : std_logic; -- 100ms window


    -- RegisterFile signals
    signal registerFileAddress, registerFileAddressMcu, registerFileAddressUsb       : unsigned(registerFileAddressWidthC-1 downto 0);
    signal registerFileData, registerFileDataMcu, registerFileDataUsb                : std_logic_vector(registerFileDataWidthC-1 downto 0);
    signal registerFileDataValid, registerFileDataValidMcu, registerFileDataValidUsb : std_logic;
    ----------------------


begin
    -------------------------- PHASE LOCKED LOOP ------------------------------------
    -- From: 100MHz
    -- To:   40MHz
    pllE: entity work.pll
        generic map (
            -- Values obtained from the icepll tool
            DIVR_G => "0100",
            DIVF_G => "0011111",
            DIVQ_G => "100",
            FILTER_RANGE_G => "010"
        )
        port map (
            clkInxDI        => clkInxDI,  -- 100MHz
            clkInForwardxDO => clk100,    -- 100MHz (forward of input clock)
            clkOutxDO       => clk40      -- 40MHz
    );

    -- Clock divider to generate 20MHz clock
    clockDivP: process(clk40)
    begin
        if rising_edge(clk40) then
            clkGlobal <= not clkGlobal;
        end if;
    end process;


    -------------------------- I2C MASTER ------------------------------------
    i2cMasterE : entity work.i2cMaster
        generic map (
            i2cClockPeriod => 200
        )
        port map (
            clk => clkGlobal,
            rst => '0',

            startxDI  => i2cMasterStart,
            busyxDO   => i2cMasterBusy,
            ackxDO    => i2cMasterAck,
            ackErrxDO => i2cMasterAckErr,

            txDataxDI => i2cMasterTxData,
            rxDataxDO => i2cMasterRxData,

            txDataWLengthxDI => i2cMasterTxDataWLength,
            rxDataWLengthxDI => i2cMasterRxDataWLength,

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
            lockAcquirexDO => i2cDAC7578LockAcquire,
            lockAckxDI => i2cDAC7578LockAck,

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
    -- Note: we are short on carry resources. I make sacrifices to make it fit with the generics
    accurateFrontendE : entity work.accurateFrontend
        generic map (
            -- 2^n slow down factor. Precision we'd like is ~10us @ 40MHz = ~ 512 = 2^9
            countTimeIntervalSlowFactorG => 9,
            -- width is 37 because ceil(log2(200fC/10fA * 40MHz/512)) = 26 + 1 bit for error/sign bit
            countTimeIntervalBitwidthG => 27
        )
        port map (
            clk20  => clkGlobal,
            clk100 => clk40, -- 40 MHz to respect timing constraints
            rst => '0',

            -- Sampling time, coming from window generator
            samplexDI => wind100ms,

            -- Amout of LSBs of charge counted in the last interval
            chargeMeasurementxDO => chargeMeasurementTmp,
            -- If voltageChangeInterval value is ready
            measurementReadyxDO => voltageChangeRdy,

            cp1CountxDO => cp1Count,
            cp2CountxDO => cp2Count,
            cp3CountxDO => cp3Count,

            cp1LastIntervalxDO => cp1LastInterval,

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
            resetOTARequestValidxDI => resetOTARequestValid, --! If resetOTARequest value is valid.
            resetOTARequestxDI      => resetOTARequest, --! ps request to reset OTA
            configxDI      => config, --! Configuration data from PS
            configValidxDI => configValid
    );

    voltageChangeInterval <= std_logic_vector(resize(chargeMeasurementTmp, voltageChangeInterval'length));

    resetOTARequestValid <= '0'; --! Not used in this design
    resetOTARequest <= '0';      --! Not used in this design


    -------------------------- WINDOW GENERATOR --------------------------------
    -- More windows width are supported by the window generator
    windowGeneratorE : entity work.windowGenerator
        port map (
            clk                   => clkGlobal,
            rst                   => '0',
            wind100msxDO          => wind100ms
    );


    -------------------------- UART FPGA - USB --------------------------------------
    uartWrapperUsbE : entity work.uartWrapper
        generic map (
            clkFreqG => 20_000_000,
            baudRateG => 9_600,
            parityG => 0,
            parityEoG => '0',
            txMessageLengthG => 28,
            txMessageWidthG => 8
        )
        port map (
            clk => clkGlobal,
            rst => '0',

            txxDO => txUartUsbxDO,

            txSendMessagexDI => voltageChangeRdy,
            txMessagexDI => sht41Meas.humidity &
                            sht41Meas.temperature &
                            std_logic_vector(resize(cp1LastInterval, 40)) &
                            std_logic_vector(resize(cp3Count, 32)) &
                            std_logic_vector(resize(cp2Count, 32)) &
                            std_logic_vector(resize(cp1Count, 32)) &
                            voltageChangeInterval &
                            x"DD",
            feederBusyxDO => open
    );

    -- UartLogicUsbE : entity work.UartLogic
    --     port map (
    --         clk                      => clkGlobal,
    --         rst                      => '0',
    --         rxFpgaxDI                => rxUartUsbxDI,
    --         txFpgaxDO                => txUartUsbxDO,

    --         voltageChangeIntervalxDI => voltageChangeIntervalxDO,
    --         voltageChangeRdyxDI      => voltageChangeRdyxDO,

    --         sht41MeasxDI => sht41Meas,

    --         addressxDO   => registerFileAddressUsb,
    --         dataxDO      => registerFileDataUsb,
    --         dataValidxDO => registerFileDataValidUsb
    -- );

    uartWrapperMcuE : entity work.uartWrapper
        generic map (
            clkFreqG => 20_000_000,
            baudRateG => 9_600,
            parityG => 0,
            parityEoG => '0',
            txMessageLengthG => 28,
            txMessageWidthG => 8
        )
        port map (
            clk => clkGlobal,
            rst => '0',

            txxDO => txUartMcuxDO,

            txSendMessagexDI => voltageChangeRdy,
            txMessagexDI => sht41Meas.humidity &
                            sht41Meas.temperature &
                            std_logic_vector(resize(cp1LastInterval, 40)) &
                            std_logic_vector(resize(cp3Count, 32)) &
                            std_logic_vector(resize(cp2Count, 32)) &
                            std_logic_vector(resize(cp1Count, 32)) &
                            voltageChangeInterval &
                            x"DD",
            feederBusyxDO => open
    );
    -- -------------------------- UART FPGA - MCU --------------------------------------
    -- UartLogicMcuE : entity work.UartLogic
    --     port map (
    --         clk                      => clkGlobal,
    --         rst                      => '0',
    --         rxFpgaxDI                => rxUartMcuxDI,
    --         txFpgaxDO                => txUartMcuxDO,

    --         voltageChangeIntervalxDI => voltageChangeIntervalxDO,
    --         voltageChangeRdyxDI      => voltageChangeRdyxDO,

    --         sht41MeasxDI => sht41Meas,

    --         addressxDO   => registerFileAddressMcu,
    --         dataxDO      => registerFileDataMcu,
    --         dataValidxDO => registerFileDataValidMcu
    -- );

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
            accurateConfigxDO => config,
            accurateConfigValidxDO => configValid,

            -- Input port
            addressxDI   => registerFileAddress,
            dataxDI      => registerFileData,
            dataValidxDI => registerFileDataValid
    );

    -- Arbitration logic to merge the signals coming from the UARTs
    registerFileAddress <= registerFileAddressUsb when registerFileDataValidUsb = '1' else
                           registerFileAddressMcu when registerFileDataValidMcu = '1' else
                           (others => '0');

    registerFileData <= registerFileDataUsb when registerFileDataValidUsb = '1' else
                        registerFileDataMcu when registerFileDataValidMcu = '1' else
                        (others => '0');

    registerFileDataValid <= registerFileDataValidUsb or registerFileDataValidMcu;

    ------------------------------ SHT41 ------------------------------------
    sht41ControllerE : entity work.sht41Controller
        port map (
            clk => clkGlobal,
            rst => '0',

            -- Out port
            sht41MeasxDO => sht41Meas,

            -- Arbitration signals
            lockAcquirexDO => i2cShtLockAcquire,
            lockAckxDI     => i2cShtLockAck,

            -- I2C signals
            StartxDO => i2cShtStart,
            BusyxDI => i2cShtBusy,
            AckxDI => i2cShtAck,
            AckErrxDI => i2cShtAckErr,

            TxDataxDO => i2cShtTxData,
            TxDataWLengthxDO => i2cShtTxDataWLength,
            rxDataxDI => i2cShtRxData,
            RxDataWLengthxDO => i2cShtRxDataWLength
    );

    -------------------------- I2C ARBITER ------------------------------------
    i2cArbiterE : entity work.i2cArbiter
        port map (
            clk => clkGlobal,
            rst => '0',
            -- Channel 1
            C1_lockAcquirexDI => i2cShtLockAcquire,
            C1_lockAckxDO     => i2cShtLockAck,
            C1_startxDI   => i2cShtStart,
            C1_ackxDO     => i2cShtAck,
            C1_ackErrxDO  => i2cShtAckErr,
            C1_busyxDO    => i2cShtBusy,
            C1_txDataxDI  => i2cShtTxData,
            C1_rxDataxDO  => i2cShtRxData,
            C1_txDataWLengthxDI => i2cShtTxDataWLength,
            C1_rxDataWLengthxDI => i2cShtRxDataWLength,

            C2_lockAcquirexDI => i2cDAC7578LockAcquire,
            C2_lockAckxDO     => i2cDAC7578LockAck,
            C2_startxDI   => i2cDAC7578Start,
            C2_ackxDO     => i2cDAC7578Ack,
            C2_ackErrxDO  => i2cDAC7578AckErr,
            C2_busyxDO    => i2cDAC7578Busy,
            C2_txDataxDI  => i2cDAC7578TxData,
            C2_rxDataxDO  => open,
            C2_txDataWLengthxDI => i2cDAC7578TxDataWLength,
            C2_rxDataWLengthxDI => i2cDAC7578RxDataWLength,

            master_startxDO  => i2cMasterStart,
            master_ackxDI    => i2cMasterAck,
            master_ackErrxDI => i2cMasterAckErr,
            master_busyxDI   => i2cMasterBusy,
            master_txDataxDO => i2cMasterTxData,
            master_rxDataxDI => i2cMasterRxData,
            master_txDataWLengthxDO => i2cMasterTxDataWLength,
            master_rxDataWLengthxDO => i2cMasterRxDataWLength
        );

end architecture rtl;
