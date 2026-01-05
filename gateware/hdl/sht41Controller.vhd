library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.IOPkg.all;

entity sht41Controller is
    generic (
        i2cAddress     : std_logic_vector(6 downto 0) := "1000100"; --! 1000100 I2C address of the SHT41
        samplingPeriod : integer := 1000; --! Sampling period in ms
        clkFreq        : integer := 20000000 --! Clock frequency in Hz
    );
    port (
        clk : in  std_logic;     --! Input system clock
        rst : in  std_logic;     --! Reset signal


        -- Out port
        sht41MeasxDO     : out sht41RecordT;


        -- i2cMaster
        lockAcquirexDO   : out std_logic; --! Acquire master lock (no collision with DAC)
        lockAckxDI       : in  std_logic; --! i2c arbiter acknowledges the transmission     
        startxDO         : out std_logic; --! Start transaction
        busyxDI          : in std_logic; --! Transaction in process
        ackxDI           : in std_logic; --! pulsed signal used both to ackowledge when txDataxDI has been read and when rxDataxDO is valid
        ackErrxDI        : in std_logic; --! flag if something nasty happenend (nack from slave, value written is not the one read, etc..)
        txDataxDO        : out std_logic_vector(7 downto 0); --! Data to write on the bus
        rxDataxDI        : in std_logic_vector(7 downto 0); --! Received data from slave
        txDataWLengthxDO : out std_logic_vector(3 downto 0); --! Number of bytes to write on the bus
        rxDataWLengthxDO : out std_logic_vector(3 downto 0) --! Number of bytes to read on the bus
    );
end entity sht41Controller;


architecture behavioral of sht41Controller is
    -- How many clock cycles are needed to wait for the sampling period
    constant samplingPeriodCycles : integer := clkFreq * (samplingPeriod / 1000);
    signal clkCounter : integer := 0;

    -- State machine
    type stateT is (IDLE_S, LOCK_ACQUIRE_WRITE_S, WRITE_S, LOCK_ACQUIRE_READ_S, READ_S);
    signal state : stateT := IDLE_S;

    -- I2C communication consants
    constant i2cTxDataWLength : natural := 2; -- Sending (address + W) + command
    constant i2cTxaddressW    : std_logic_vector(7 downto 0) := i2cAddress & "0"; -- 7-bit address + W
    constant i2cTxDataRLength : natural := 1; -- Sending (address + R) + command
    constant i2cTxaddressR    : std_logic_vector(7 downto 0) := i2cAddress & "1"; -- 7-bit address + R
    constant i2cTxCommand     : std_logic_vector(7 downto 0) := x"FD"; -- Read temperature and humidity with high precition
    constant i2cRxDataWLength : natural := 6; -- 6 Bytes

    -- I2C communication signals
    signal txByteCount : integer := 0;
    signal rxByteCount : integer := 0;

    -- Vector of bytes where to store the data
    type vectorOfBytesT is array (0 to i2cRxDataWLength - 1) of std_logic_vector(7 downto 0);
    signal rxData : vectorOfBytesT;

    -- Data valid signal
    signal dataValid : std_logic := '0';

begin

    logicP : process(clk, rst)
    begin
        if rising_edge(clk) then 
            if rst = '1' then
                state <= IDLE_S;
                clkCounter <= 0;
                txByteCount <= 0;
                rxByteCount <= 0;
            else

                case state is
                    when IDLE_S =>
                        -- Wait for the sampling period
                        if clkCounter = samplingPeriodCycles then
                            clkCounter <= 0;
                            state <= LOCK_ACQUIRE_WRITE_S;
                        else
                            clkCounter <= clkCounter + 1;
                        end if;
                        lockAcquirexDO <= '0';
                        dataValid <= '0';
                        txDataWLengthxDO <= (others => '0');
                        rxDataWLengthxDO <= (others => '0');

                    when LOCK_ACQUIRE_WRITE_S =>
                        -- Wait for the lock to be acquired
                        lockAcquirexDO <= '1';
                        txDataWLengthxDO <= std_logic_vector(to_unsigned(i2cTxDataWLength, txDataWLengthxDO'length)); -- 2 bytes to write
                        rxDataWLengthxDO <= (others => '0'); -- No read back at this stage
                        txDataxDO <= i2cTxaddressW; -- write mode

                        if (ackxDI = '1') then
                            state <= WRITE_S;
                        elsif (ackErrxDI = '1') then
                            state <= IDLE_S;
                        end if;

                    when WRITE_S =>
                        -- Send the read command
                        txDataxDO <= i2cTxCommand;
                        if (ackxDI = '1') then
                            lockAcquirexDO <= '0';
                            state <= LOCK_ACQUIRE_READ_S; -- LOCK_ACQUIRE_READ_S
                        elsif (ackErrxDI = '1') then
                            state <= IDLE_S;
                        end if;

                    when LOCK_ACQUIRE_READ_S =>
                        -- Wait for the lock to be acquired
                        lockAcquirexDO <= '1';
                        txDataWLengthxDO <= std_logic_vector(to_unsigned(i2cTxDataRLength, txDataWLengthxDO'length));
                        rxDataWLengthxDO <= std_logic_vector(to_unsigned(i2cRxDataWLength, rxDataWLengthxDO'length));
                        txDataxDO <= i2cTxaddressR; -- read mode

                        if (ackxDI = '1') then
                            state <= READ_S;
                        end if;

                    when READ_S =>
                        -- Read the data
                        if (ackxDI = '1') then
                            if (rxByteCount < i2cRxDataWLength - 1) then
                                rxData(rxByteCount) <= rxDataxDI;
                                rxByteCount <= rxByteCount + 1;                                
                            else
                                rxByteCount <= 0;
                                lockAcquirexDO <= '0';
                                state <= IDLE_S;
                                -- Acknowledge the data
                                dataValid <= '1';
                            end if;
                        elsif (ackErrxDI = '1') then
                            state <= LOCK_ACQUIRE_READ_S;
                        end if;

                end case;
            end if;
        end if;
    end process logicP;


    -- Start I2C communication when:
    -- 1. Current state is lock acquire
    -- 2. The lock has been acquired
    -- 3. The bus is not busy
    startxDO <= '1' when ((state = LOCK_ACQUIRE_WRITE_S or state = LOCK_ACQUIRE_READ_S)
                    and (lockAcquirexDO = '1' and lockAckxDI = '1' and busyxDI = '0'))
                    else '0';


    -- Assign the received values to the output record
    sht41MeasxDO.temperature <= rxData(0) & rxData(1);
    sht41MeasxDO.humidity    <= rxData(3) & rxData(4);
    sht41MeasxDO.dataValid   <= dataValid;
    

end architecture behavioral;