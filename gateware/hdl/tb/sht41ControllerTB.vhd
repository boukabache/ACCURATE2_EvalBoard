library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.IOPkg.all;

-- Testbench for sht41Controller
entity sht41ControllerTB is
end entity sht41ControllerTB;

architecture test of sht41ControllerTB is
    constant CLK_PERIOD : time := 50 ns; -- 20 MHz clock
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    signal sht41Meas : sht41RecordT := sht41RecordTInit;

    -- SHT41 I2C interface
    signal i2cSHT41LockAcquire : std_logic;
    signal i2cSHT41LockAck     : std_logic;
    signal i2cSHT41Start       : std_logic;
    signal i2cSHT41Busy        : std_logic;
    signal i2cSHT41Ack         : std_logic;
    signal i2cSHT41AckErr      : std_logic;

    signal i2cSHT41TxData : std_logic_vector(7 downto 0);
    signal i2cSHT41RxData : std_logic_vector(7 downto 0);

    signal i2cSHT41TxDataWLength : std_logic_vector(3 downto 0);
    signal i2cSHT41RxDataWLength : std_logic_vector(3 downto 0);
    ----------------------

    -- Output ports
    signal i_sdaOutxDO : std_logic;
    signal i_sdaInxDI  : std_logic;
    signal i_sclOutxDO : std_logic;

    signal fpga_sdaxDIO : std_logic;
    signal fpga_sclxDIO : std_logic;

begin

    sht41ControllerE : entity work.sht41Controller
        port map (
            clk => clk,
            rst => rst,

            -- Out port
            sht41MeasxDO => sht41Meas,

            -- Arbitration signals
            lockAcquirexDO => open,
            lockAckxDI     => '1',

            -- I2C signals
            StartxDO => i2cSHT41Start,
            BusyxDI => i2cSHT41Busy,
            AckxDI => i2cSHT41Ack,
            AckErrxDI => i2cSHT41AckErr,
            
            TxDataxDO => i2cSHT41TxData,
            TxDataWLengthxDO => i2cSHT41TxDataWLength,
            rxDataxDI => i2cSHT41RxData,
            RxDataWLengthxDO => i2cSHT41RxDataWLength
    );

    i2cMasterE : entity work.i2cMaster
        generic map (
            i2cClockPeriod => 200
        )
        port map (
            clk => clk,
            rst => rst,

            startxDI  => i2cSHT41Start,
            busyxDO   => i2cSHT41Busy,
            ackxDO    => i2cSHT41Ack,
            ackErrxDO => i2cSHT41AckErr,

            txDataxDI => i2cSHT41TxData,
            rxDataxDO => i2cSHT41RxData,

            txDataWLengthxDI => i2cSHT41TxDataWLength,
            rxDataWLengthxDI => i2cSHT41RxDataWLength,

            -- To the I2C bus
            sdaOutxDO => i_sdaOutxDO,
            sdaInxDI  => i_sdaInxDI,
            sclOutxDO => i_sclOutxDO
    );

    -- Tri-state buffer for SDA and SCL lines
    fpga_sdaxDIO <= '0' when i_sdaOutxDO = '0' else 'Z';
    i_sdaInxDI <= fpga_sdaxDIO;
    fpga_sclxDIO <= '0' when i_sclOutxDO = '0' else 'Z';

    -- Clock process
    clk_process :process
    begin
        clk <= '1';
        wait for CLK_PERIOD/2;
        clk <= '0';
        wait for CLK_PERIOD/2;
    end process;


    -- Stimulus process
    stimulus : process
    begin
        report "Starting test" severity note;

        -- Reset
        wait for CLK_PERIOD;
        rst <= '1';
        wait for CLK_PERIOD;
        rst <= '0';
        wait for CLK_PERIOD;

        report "Reset done" severity note;

       

        wait;
    end process stimulus;

end architecture test;