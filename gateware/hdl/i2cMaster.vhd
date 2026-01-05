--! @file i2cMaster.vhd
--! @brief Simple i2c master core for single master bus
--!
--! An i2c transaction starts when startxDI is set, at which point it will register all initial transmission parameters:
--! * txDataWLengthxDI, the number of bytes to write, minus 1.
--! * rxDataWLengthxDI, the number of bytes to read.
--! * txDataxDI, the first byte to write (usually the address and RW bit).
--!
--! The core will then write
--! the number of bytes specified by txDataWLengthxDI. Each transmitted by is
--! read on txDataxDI, and acknowledged via ackxDO. After that, if it is a
--! write transaction, it stops (i.e: busy goes low).
--! If it is a read, then the core will read the
--! number of bytes specified by rxDataWLengthxDI.
--! Warning: make sure that the commands sent to the slave actually match with
--! the xxDataWLength.
--! The busy signal is high for the entire duration of the transaction.
--!
--! Be wary if ever using i2c memories on this core (or any new device for that
--! matter), as they may expect a read transaction to finish with the master
--! sending NACK, which is not quite complient with the official specs and this
--! core.
--!
--! As the outputs of 3 triplicated cores are voted on, it is necessary to
--! separate the normal inout signals into their primitive values. \n
--! The xilinx IOBuf sets the output to high impedance ('Z') when the tristate
--! enable signal is one. Therefore the out signals (*sdaOutxDO* and
--! *sclOutxDO*) are connected to both the input and tristate buffer of the
--! corresponding IOBuf.  If the output is set to 1 then the tristate signal is
--! set to 1, which sets the IOBuf output to 'Z', if the output is set to 0 the
--! tristate signal is set to 0 and the output signal is activated the output is
--! therefore also 0;
--! @dotfile i2cMaster.dot "Finite State Machine"

-- Copyright (C) CERN CROME Project

--! Use standard library
library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;
--! For using clkFreqC and clkPeriodNsC
use work.configPkg.all;

entity i2cMaster is
    generic (
        --! Clock period to use for the i2c bus in number of clock cycles ( = freqI2c/freClk)
        i2cClockPeriod : integer range 2 to integer'high := 200
    );
    port (
        clk : in  std_logic;     --! Input system clock
        rst : in  std_logic;     --! Asynchronous reset signal

        startxDI : in  std_logic;     --! Start transaction
        busyxDO  : out std_logic;     --! Transaction in process
        --! pulsed signal used both to ackowledge when txDataxDI has been read and when rxDataxDO is valid
        ackxDO   : out std_logic;

        --! flag if something nasty happenend (nack from slave, value written is not the one read, etc..)
        ackErrxDO : out std_logic;

        txDataxDI : in  std_logic_vector(7 downto 0); --! Data to write on the bus
        rxDataxDO : out std_logic_vector(7 downto 0); --! Received data from slave

        txDataWLengthxDI : in  std_logic_vector(3 downto 0); --! Number of bytes to write on the bus
        rxDataWLengthxDI : in  std_logic_vector(3 downto 0); --! Number of bytes to read on the bus

        sdaOutxDO : out std_logic;     --! SDA output data
        sdaInxDI  : in  std_logic;     --! SDA input data
        --! SCL output data (master always drives clock so we don't read and require an input clock)
        sclOutxDO : out std_logic
    );
end entity i2cMaster;

architecture behavioural of i2cMaster is

    --*************************************************************************
    -------------------------------- Types ------------------------------------
    --*************************************************************************

    type statesT is (
        idle, sendStart, sendByte, readByte, setupStop, sendStop
    );

    --*************************************************************************
    ------------------------------- Constants ---------------------------------
    --*************************************************************************

    constant ackC : std_logic := '0'; --! ACK
    constant nackC : std_logic := '1'; --! NACK

    --*************************************************************************
    ------------------------------- Signals -----------------------------------
    --*************************************************************************

    signal statexDP, statexDN : statesT;

    signal sclCntxDP, sclCntxDN : natural range 0 to i2cClockPeriod;
    signal sclOutxDP, sclOutxDN : std_logic;
    signal sclRe : std_logic; -- Scl rising edge
    signal sclFe : std_logic; -- Scl falling edge

    signal sdaOutxDP, sdaOutxDN : std_logic; -- Output sda signal

    signal busyxDP, busyxDN : std_logic;
    signal ackxDP, ackxDN : std_logic;
    signal ackErrxDP, ackErrxDN : std_logic;

    -- is high during all byte write, read, ACK and setup STOP, low during idle,
    -- START and STOP. (allows scl to be outputted)
    signal transactionActivexDP, transactionActivexDN : std_logic;

    -- Number of bits left to process (write or read and recieve/send ACK/NACK)
    signal bitCountxDP, bitCountxDN : natural range 0 to 8;

    signal txDataxDP, txDataxDN : std_logic_vector(7 downto 0);
    signal txDataWCountxDP, txDataWCountxDN : unsigned(txDataWLengthxDI'range);

    signal rxDataxDP, rxDataxDN : std_logic_vector(7 downto 0);
    signal rxDataWCountxDP, rxDataWCountxDN : unsigned(rxDataWLengthxDI'range);

    --*************************************************************************
    ------------------------------- Attributes --------------------------------
    --*************************************************************************

    attribute fsm_safe_state : string;
    attribute fsm_safe_state of statexDP : signal is fsmSafeStateStringC;

begin

    --*************************************************************************
    ------------------------------- I2C Clock ---------------------------------
    --*************************************************************************

    sclRe <= '1' when sclCntxDP >= i2cClockPeriod - 1 else '0';
    sclFe <= '1' when sclCntxDP = i2cClockPeriod / 2 - 1 else '0';

    -- Restart counter at start of new transaction to have easy alignment
    sclCntxDN <= 0 when statexDP = idle and startxDI = '1' else
                 sclCntxDP + 1 when sclCntxDP < i2cClockPeriod - 1 else
                 0 when sclCntxDP >= i2cClockPeriod - 1 else
                 sclCntxDP;

    --*************************************************************************
    ------------------------------- Processes ---------------------------------
    --*************************************************************************

    regP : process (clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                statexDP <= idle;

                busyxDP <= '0';
                ackErrxDP <= '0';
                ackxDP <= '0';

                transactionActivexDP <= '0';
                bitCountxDP <= 0;

                sclCntxDP <= 0;
                sclOutxDP <= '1';
                sdaOutxDP <= '1';

                rxDataxDP <= (others => '0');
                rxDataWCountxDP <= (others => '0');

                txDataxDP <= (others => '0');
                txDataWCountxDP <= (others => '0');

            else
                statexDP <= statexDN;

                busyxDP <= busyxDN;
                ackErrxDP <= ackErrxDN;
                ackxDP <= ackxDN;

                transactionActivexDP <= transactionActivexDN;
                bitCountxDP <= bitCountxDN;

                sclCntxDP <= sclCntxDN;
                sclOutxDP <= sclOutxDN;
                sdaOutxDP <= sdaOutxDN;

                rxDataxDP <= rxDataxDN;
                rxDataWCountxDP <= rxDataWCountxDN;

                txDataxDP <= txDataxDN;
                txDataWCountxDP <= txDataWCountxDN;
            end if;
        end if;
    end process regP;

    fsmP : process (statexDP, sclFe, sclRe, bitCountxDP, sdaInxDI,
                    txDataWCountxDP, rxDataWCountxDP, startxDI)
    begin
        statexDN <= statexDP;

        ackErrxDN <= '0';
        ackxDN <= '0';
        busyxDN <= busyxDP;
        sdaOutxDN <= sdaOutxDP;

        bitCountxDN <= bitCountxDP;
        transactionActivexDN <= transactionActivexDP;

        rxDataxDN <= rxDataxDP;
        rxDataWCountxDN <= rxDataWCountxDP;

        txDataxDN <= txDataxDP;
        txDataWCountxDN <= txDataWCountxDP;

        case statexDP is

            when idle =>
                if (startxDI = '1') then
                    assert sdaInxDI = '1' or sdaInxDI = 'H'
                        report "i2c bus is not free when starting transaction"
                        severity error;

                    assert unsigned(txDataWLengthxDI) > 0
                        report "A transaction with 0 bytes to write makes no sense"
                        severity error;

                    if (unsigned(txDataWLengthxDI) = 0) then
                        ackErrxDN <= nackC;
                        statexDN <= idle;
                    else
                        ackxDN <= '1';
                        busyxDN <= '1';

                        txDataxDN <= txDataxDI;
                        txDataWCountxDN <= unsigned(txDataWLengthxDI);

                        rxDataWCountxDN <= unsigned(rxDataWLengthxDI);

                        bitCountxDN <= 8;
                        -- Set sda low while scl is high -> start condition
                        sdaOutxDN <= '0';

                        statexDN <= sendStart;
                    end if;
                end if;

            -- Wait until i2c start condition finishes
            when sendStart =>
                if (sclFe = '1') then
                    if (sdaInxDI /= sdaOutxDP) then
                        ackErrxDN <= '1';
                        statexDN <= idle;
                    end if;

                    transactionActivexDN <= '1';
                    sdaOutxDN <= txDataxDP(7);

                    statexDN <= sendByte;
                end if;

            -- Transmit the byte
            when sendByte =>
                if (sclFe = '1') then
                    if (bitCountxDP > 1) then
                        if (sdaInxDI /= sdaOutxDP) then
                            ackErrxDN <= '1';
                            sdaOutxDN <= '0';
                            statexDN <= setupStop;
                        end if;

                        sdaOutxDN <= txDataxDP(bitCountxDP - 2);
                        bitCountxDN <= bitCountxDP - 1;
                    elsif (bitCountxDP = 1) then
                        if (sdaInxDI /= sdaOutxDP) then
                            ackErrxDN <= '1';
                            sdaOutxDN <= '0';
                            statexDN <= setupStop;
                        end if;

                        sdaOutxDN <= '1'; -- set sda to high impedance
                        bitCountxDN <= bitCountxDP - 1;

                    -- Check for ACK
                    elsif (bitCountxDP = 0) then
                        if (sdaInxDI = nackC) then
                            ackErrxDN <= nackC;

                            sdaOutxDN <= '0';
                            statexDN <= setupStop;

                        -- Check for 1, because we check before subtracting
                        elsif (txDataWCountxDP = 1) then
                            if (rxDataWCountxDP = 0) then
                                -- If writing, transaction finished once all bytes
                                -- are transmitted
                                sdaOutxDN <= '0';

                                -- we need to do setupStop to let a chance to the
                                -- slave to deassert its ACK
                                statexDN <= setupStop;
                            else
                                -- If reading, listen to incoming data
                                statexDN <= readByte;
                                bitCountxDN <= 8;
                            end if;

                        else
                            bitCountxDN <= 8;
                            txDataWCountxDN <= txDataWCountxDP - 1;
                            txDataxDN <= txDataxDI;
                            ackxDN <= '1';
                            sdaOutxDN <= txDataxDI(7);
                        end if;
                    end if;
                end if;

            -- Read 8 bits of data
            when readByte =>
                -- read on rising edge
                if (sclFe = '1') then
                    if (bitCountxDP > 1) then
                        rxDataxDN <= rxDataxDP(6 downto 0) & sdaInxDI;
                        bitCountxDN <= bitCountxDP - 1;
                    elsif (bitCountxDP = 1) then
                        rxDataxDN <= rxDataxDP(6 downto 0) & sdaInxDI;
                        ackxDN <= '1';
                        bitCountxDN <= bitCountxDP - 1;

                        if (rxDataWCountxDP = 1) then
                            -- If this looks wrong to you, check 3.1.6 of UM10204 (i2c spec)
                            sdaOutxDN <= nackC;
                        else
                            sdaOutxDN <= ackC;
                        end if;

                    -- Send ACK if more bytes to read or NACK if last one
                    elsif (bitCountxDP = 0) then
                        if (sdaInxDI /= sdaOutxDP) then
                            ackErrxDN <= '1';
                            sdaOutxDN <= '0';
                            statexDN <= setupStop;
                        end if;

                        if (rxDataWCountxDP = 1) then
                            sdaOutxDN <= '0';
                            statexDN <= setupStop;
                        else
                            rxDataWCountxDN <= rxDataWCountxDP - 1;
                            sdaOutxDN <= '1'; -- Disable output to read input
                            bitCountxDN <= 8;
                        end if;
                    end if;
                end if;

            -- Run one more cycle of sdl to set SDA low (STOP cond is rising
            -- edge of SDA when SCL is high) -> if SDA is low, SCL must go low
            -- before sending stop to avoid noisy start condition
            when setupStop =>
                if (sclFe = '1') then
                    transactionActivexDN <= '0';

                    statexDN <= sendStop;
                end if;

            -- Send stop signal (sda 0 -> 1 when scl 1) and wait for hold time
            when sendStop =>
                if (sclRe = '1') then
                    sdaOutxDN <= '1';
                elsif (sclFe = '1') then
                    busyxDN <= '0';

                    statexDN <= idle;
                end if;
        end case;
    end process fsmP;

    -- /!\ depends on next state of transactionActive.
    sclOutxDN <= '1' when transactionActivexDN = '0' else
                 '1' when transactionActivexDN = '1' and sclRe = '1' else
                 '0' when transactionActivexDN = '1' and sclFe = '1' else
                 sclOutxDP;

    --*************************************************************************
    ------------------------------- Set Outputs -------------------------------
    --*************************************************************************

    ackErrxDO <= ackErrxDP;
    busyxDO <= busyxDP;
    rxDataxDO <= rxDataxDP;
    sdaOutxDO <= sdaOutxDP;
    sclOutxDO <= sclOutxDP;

    ackxDO <= ackxDP;
end architecture behavioural;
