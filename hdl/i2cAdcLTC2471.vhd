--! @file i2cAdcLTC2471.vhd
--! @brief I2C logic for the LTC2471 ADC
--
--! This module constantly read the ADC convertion result and forward it
--! to the UartLogic in order to be sent outside.
--! The module send the 7-bit address of the ADC followed by a read request
--! (R) bit. The bit R is 1 for a read request. The ADC acknowledge and,
--! immediately after, send the 16-bit result of the conversion (MSB to LSB).
--! Once all 16-bits are read or an abort is initiated, the DAC begins
--! a new conversion.


entity i2cAdcLTC2471 is
    generic(
        i2cAddress : std_logic_vector(7 - 1 downto 0) := "0010100" -- 0x14
    );
    port(
        clk : in  std_logic;     --! Input system clock
        rst : in  std_logic;     --! Reset signal


        -- Out port
        adcDataOutxDO      : out std_logic_vector(15 downto 0); --! ADC data output
        adcDataOutValidxDO : out std_logic; --! ADC data output valid


        -- i2cMaster
        lockAcquirexDO : out std_logic; --! Acquire master lock (no collision with DAC)
        lockAckxDI     : in  std_logic; --! i2c arbiter acknowledges the transmission     


        startxDO : out  std_logic;   --! Start transaction
        busyxDI  : in std_logic;     --! Transaction in process
        --! pulsed signal used both to ackowledge when txDataxDI has been read and when rxDataxDO is valid
        ackxDI   : in std_logic;

        --! flag if something nasty happenend (nack from slave, value written is not the one read, etc..)
        ackErrxDI : in std_logic;

        txDataxDO : out  std_logic_vector(7 downto 0); --! Data to write on the bus
        rxDataxDI : in std_logic_vector(7 downto 0);   --! Received data from slave

        txDataWLengthxDO : out  std_logic_vector(3 downto 0); --! Number of bytes to write on the bus
        rxDataWLengthxDO : out  std_logic_vector(3 downto 0) --! Number of bytes to read on the bus

    );
end entity i2cAdcLTC2471;


architecture rtl of i2cADCLTC2471 is

    constant i2cTxDataWLength : natural := 1; -- Sending address + R
    constant i2cTxData        : std_logic_vector(7 downto 0) := i2cAddress & "1"; -- 7-bit address + R
    constant i2cRxDataWLength : natural := 2; -- 16-bit result

    type i2cByteArrayT is
        array (0 to i2cRxDataWLength - 1) of
        std_logic_vector(i2cTxDataxDO'range)
    ;

    type stateT is (IDLE_S, WRITE_S, READ_1_S, READ_2_S);


    signal state     : stateT;
    signal i2cRxData : i2cByteArrayT;

begin


    logicP: process (clk, rst)
    begin
        if rising_edge(clk) then
            if (rst = '1')
                -- TODO
            else

                case state is
                    when IDLE_S =>
                        lockAcquirexDO <= '1';
                        if (lockAckxDI = '1' and busyxDI = '0') then
                            startxDO <= '1';
                            txDataxDO <= i2cTxData;
                            state <= WRITE_S;
                        end if;

                    when WRITE_S =>
                        if (ackxDI = '1') then
                            state <= READ_1_S;
                        end if;

                    when READ_1_S =>
                        if (ackxDI = '1') then
                            i2cRxData(0) <= rxDataxDI;
                            state <= READ_2_S;
                        end if;

                    when READ_2_S =>
                        if (busyxDI = '0') then
                            i2cRxData(1) <= rxDataxDI;
                            lockAcquire <= '0';
                            state <= IDLE_S;
                        end if;

                    when others =>
                        state <= IDLE_S;
                end case;


            end if;
        end if;
    end process logicP;

    -- Always sending 1 Byte: the address + R
    txDataWLengthxDO <= std_logic_vector(to_unsigned(i2cTxDataWLength, txDataWLengthxDO'length));
    -- Always reading 2 Bytes: the 16-bit result
    rxDataWLengthxDO <= std_logic_vector(to_unsigned(i2cRxDataWLength, rxDataWLengthxDO'length));

    -- Output the 16-bit result
    adcDataOutxDO <= i2cRxData;
    adcDataOutValidxDO <= '1' when state = READ_2_S else '0';

end architecture;