--! @file i2cDAC7578.vhd
--! @brief DAC7578 i2c controller. Needs to be combined with i2cMaster to function.

-- Copyright (C) CERN CROME Project

--! Use standard library
library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;
--! Required for safe state keyword
use work.configPkg.all;

--! The controller drives the *i2cMaster* which controls the DAC.
-- TODO: what happens if i2cBusy goes low without nack?

entity i2cDAC7578 is
    generic (
        i2cAddress : std_logic_vector(7 - 1 downto 0) := "1001000"
    );
    port (
        clk             : in  std_logic; --! System Clock
        rst             : in  std_logic; --! Synchronous reset

        -- i2cMaster
        lockAcquirexDO : out std_logic; --! Acquire master lock (no collision with sht21)
        lockAckxDI     : in  std_logic; --! i2c arbiter acknowledges the transmission

        i2cStartxDO         : out std_logic; --! Enable i2c transmission
        i2cTxDataxDO        : out std_logic_vector(7 downto 0); --! Write command for the i2c Master
        i2cAckxDI           : in  std_logic; --! i2c Master acknoledges the command, we can forward the next one
        i2cAckErrxDI        : in  std_logic; --! i2c Master received a NACK
        i2cBusyxDI          : in  std_logic; --! i2c Master busy
        i2cTxDataWLengthxDO : out std_logic_vector(3 downto 0);
        i2cRxDataWLengthxDO : out std_logic_vector(3 downto 0);

        AxDI : in  unsigned(11 downto 0);
        BxDI : in  unsigned(11 downto 0);
        CxDI : in  unsigned(11 downto 0);
        DxDI : in  unsigned(11 downto 0);
        ExDI : in  unsigned(11 downto 0);
        FxDI : in  unsigned(11 downto 0);
        GxDI : in  unsigned(11 downto 0);
        HxDI : in  unsigned(11 downto 0)

    );
end entity i2cDAC7578;

architecture behavioral of i2cDAC7578 is

    constant DACOutputNumber : natural := 8;
    constant DACBinaryIndex_bw : natural := 4;

    constant dac7578Command : std_logic_vector(3 downto 0) := "0011"; -- Write to DAC reg and update Output

    constant i2cTxDataWLength : natural := 4;

    type stateT is (
        idle, setVoltage
    );

    type vDacArrayT is
        array (0 to DACOutputNumber - 1) of
        unsigned(AxDI'range);

    type i2cByteArrayT is
        array (0 to i2cTxDataWLength - 1) of
        std_logic_vector(i2cTxDataxDO'range);

    function oneHotToBinary (
        oneHot : std_logic_vector;
        size    : natural)
    return std_logic_vector is
        variable binVar : std_logic_vector(size - 1 downto 0);
    begin
        binVar := (others => '0');

        for I in oneHot'range loop
            if (oneHot(I) = '1') then
                binVar := binVar or std_logic_vector(to_unsigned(I, size));
            end if;
        end loop;
        return binVar;
    end function;

    signal state : stateT;

    signal i2cByteArray : i2cByteArrayT;
    signal bytesTransmitted : natural range 0 to i2cTxDataWLength;
    signal i2cStart : std_logic;
    signal i2cTxData : std_logic_vector(i2cTxDataxDO'range);

    -- voltages given by ps
    signal psVDacArray : vDacArrayT;
    -- volages currently programmed
    signal vDacArray : vDacArrayT;
    -- voltage

    signal mismatchArray : std_logic_vector(DACOutputNumber - 1 downto 0);
    signal mismatchIndice, mismatchIndiceCurrent : integer range 0 to DACOutputNumber;
    signal lockAcquire : std_logic;
    signal currentVoltageToSet : unsigned(AxDI'range);
    signal mismatchOneHot : std_logic_vector(DACOutputNumber - 1 downto 0);

    attribute fsm_safe_state : string;
    attribute fsm_safe_state of state : signal is fsmSafeStateStringC;

begin

    psVDacArray(0) <= AxDI;
    psVDacArray(1) <= BxDI;
    psVDacArray(2) <= CxDI;
    psVDacArray(3) <= DxDI;
    psVDacArray(4) <= ExDI;
    psVDacArray(5) <= FxDI;
    psVDacArray(6) <= GxDI;
    psVDacArray(7) <= HxDI;

    regP : process (clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                state <= idle;

                lockAcquire <= '0';

                i2cStart <= '0';
                i2cTxData <= (others => '0');

                vDacArray <= (others => (others => '0'));
                mismatchIndiceCurrent <= 0;
                currentVoltageToSet <= (others => '0');
                bytesTransmitted <= 0;

            else
                i2cStart <= '0';

                case (state) is
                    when idle =>
                        bytesTransmitted <= 0;

                        if (unsigned(mismatchArray) /= 0) then
                            lockAcquire <= '1';
                            mismatchIndiceCurrent <= mismatchIndice;
                            currentVoltageToSet <= psVDacArray(mismatchIndice);

                        end if;

                        if (lockAcquire = '1' and lockAckxDI = '1' and i2cBusyxDI = '0') then
                            i2cStart <= '1';

                            i2cTxData <= i2cByteArray(bytesTransmitted);

                            state <= setVoltage;
                        end if;

                    when setVoltage =>
                        if (i2cAckErrxDI = '1' or
                            (i2cStart = '0' and i2cBusyxDI = '0' and bytesTransmitted < i2cTxDataWLength - 1)) then
                            -- Release the bus in case of error
                            -- The busy low case is serious, because it means there is an error
                            -- in the i2cMaster logic.
                            assert (i2cBusyxDI = '0' and bytesTransmitted < i2cTxDataWLength - 1)
                                report "i2cBusyxDI should never go low during a transmission!"
                                severity failure;

                            lockAcquire <= '0';
                            i2cTxData <= (others => '0');
                            bytesTransmitted <= 0;

                            state <= idle;

                        elsif (i2cAckxDI = '1') then
                            if (bytesTransmitted < i2cTxDataWLength - 1) then
                                i2cTxData <= i2cByteArray(bytesTransmitted + 1);
                                bytesTransmitted <= bytesTransmitted + 1;
                            elsif (bytesTransmitted = i2cTxDataWLength - 1) then
                                i2cTxData <= (others => '0');
                                bytesTransmitted <= bytesTransmitted + 1;
                            end if;

                            assert bytesTransmitted < i2cTxDataWLength
                                report "Too many ACKs in transaction!"
                                severity error;

                        elsif (i2cStart = '0' and i2cBusyxDI = '0') then
                            vDacArray(mismatchIndiceCurrent) <= currentVoltageToSet;

                            lockAcquire <= '0';
                            i2cTxData <= (others => '0');
                            bytesTransmitted <= 0;

                            state <= idle;
                        end if;
                end case;
            end if;
        end if;
    end process regP;

    i2cByteArray(0) <= i2cAddress & "0"; -- "0" for write transaction
    i2cByteArray(1) <= dac7578Command & "0" & std_logic_vector(to_unsigned(mismatchIndiceCurrent, 3));
    i2cByteArray(2) <= std_logic_vector(psVDacArray(mismatchIndiceCurrent)(11 downto 4));
    i2cByteArray(3) <= std_logic_vector(psVDacArray(mismatchIndiceCurrent)(3 downto 0)) & "1111";

    MISMATCH_GEN : for I in 0 to DACOutputNumber - 1 generate
        mismatchArray(I) <= '0' when (psVDacArray(I) = vDacArray(I)) else
                            '1';
    end generate MISMATCH_GEN;

    -- Converts the mismatch array to one hot, favoring the lowest bit set
    mismatchOneHot(0) <= mismatchArray(0);
    MISMATCH2ONEHOT : for I in 1 to DACOutputNumber - 1 generate
        mismatchOneHot(I) <= '1' when mismatchArray(I) = '1' and unsigned(mismatchArray(I - 1 downto 0)) = 0 else
                             '0';
    end generate MISMATCH2ONEHOT;

    -- The indice of the lowest mismatch in the mismatch array
    mismatchIndice <= to_integer(unsigned(oneHotToBinary(mismatchOneHot, DACBinaryIndex_bw)));

  --*************************************************************************
  ------------------------------- Set Outputs -------------------------------
  --*************************************************************************

    lockAcquirexDO  <= lockAcquire;

    i2cStartxDO <= i2cStart;
    i2cTxDataxDO <= i2cTxData;
    -- We are always sending 3 packets: addr, MSB, LSB
    i2cTxDataWLengthxDO <= std_logic_vector(to_unsigned(i2cTxDataWLength, i2cTxDataWLengthxDO'length));
    -- We never read back anything
    i2cRxDataWLengthxDO <= (others => '0');

end architecture behavioral;
