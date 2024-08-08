--! @file i2cArbiter.vhd
--! @brief 2 to 1 channel arbiter between the controllers and i2cMaster,
--!        combinational

--! Use standard library
library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;
--! Required for safe state keyword
use work.configPkg.all;

--! Decides who can talk to the i2cMaster between C1 and C2.
--! Priority is given to C1. In order to not affect the communication by adding
--! a 1-cycle delay, this module is fully combinatorial, except for 1 register
--! to know if a transaction is ongoing on channel 2. 2 additional registers are
--! used for the locking mechanism (mainly for ease of understanding the
--! module).

entity i2cArbiter is
    port (
        clk : in  std_logic;
        rst : in  std_logic;

        -- Channel 1
        C1_lockAcquirexDI : in  std_logic;
        C1_lockAckxDO     : out std_logic;

        C1_startxDI         : in  std_logic;
        C1_ackxDO           : out std_logic;
        C1_ackErrxDO        : out std_logic;
        C1_busyxDO          : out std_logic;
        C1_txDataxDI        : in  std_logic_vector(7 downto 0);
        C1_txDataWLengthxDI : in  std_logic_vector(3 downto 0);
        C1_rxDataxDO        : out std_logic_vector(7 downto 0);
        C1_rxDataWLengthxDI : in  std_logic_vector(3 downto 0);

        -- Channel 2
        C2_lockAcquirexDI : in  std_logic;
        C2_lockAckxDO     : out std_logic;

        C2_startxDI         : in  std_logic;
        C2_ackxDO           : out std_logic;
        C2_ackErrxDO        : out std_logic;
        C2_busyxDO          : out std_logic;
        C2_txDataxDI        : in  std_logic_vector(7 downto 0);
        C2_txDataWLengthxDI : in  std_logic_vector(3 downto 0);
        C2_rxDataxDO        : out std_logic_vector(7 downto 0);
        C2_rxDataWLengthxDI : in  std_logic_vector(3 downto 0);

        -- i2cMaster
        master_startxDO         : out std_logic;
        master_ackxDI           : in  std_logic;
        master_ackErrxDI        : in  std_logic;
        master_busyxDI          : in  std_logic;
        master_txDataxDO        : out std_logic_vector(7 downto 0);
        master_txDataWLengthxDO : out std_logic_vector(3 downto 0);
        master_rxDataxDI        : in  std_logic_vector(7 downto 0);
        master_rxDataWLengthxDO : out std_logic_vector(3 downto 0)

    );
end entity i2cArbiter;

architecture behavioural of i2cArbiter is
    signal C1_selected : std_logic;
    signal C1_lockAckxDN, C1_lockAckxDP : std_logic;
    signal C2_lockAckxDN, C2_lockAckxDP : std_logic;
begin

    regP : process (clk)
    begin
        if (rising_edge(clk)) then
            if (rst = '1') then
                C1_lockAckxDP <= '0';
                C2_lockAckxDP <= '0';
            else
                C1_lockAckxDP <= C1_lockAckxDN;
                C2_lockAckxDP <= C2_lockAckxDN;
            end if;
        end if;
    end process regP;

    -- C1 always selected, except when C2 starts or is in transaction
    C1_selected <= '0' when C2_lockAcquirexDI = '1' and C2_lockAckxDP = '1' else
                   '0' when C2_lockAcquirexDI = '1' and C1_lockAcquirexDI = '0' else
                   '1';

    C1_lockAckxDN <= '1' when C1_selected = '1' and C1_lockAcquirexDI = '1' else
                     '0';

    C2_lockAckxDN <= '1' when C1_selected = '0' and C2_lockAcquirexDI = '1' else
                     '0';

    MUX : process (C1_lockAckxDP, C2_lockAckxDP,
                   C1_startxDI, C1_txDataxDI, C1_txDataWLengthxDI, C1_rxDataWLengthxDI,
                   C2_startxDI, C2_txDataxDI, C2_txDataWLengthxDI, C2_rxDataWLengthxDI
    )

    begin
        if (C1_lockAckxDP = '1') then
            master_startxDO <= C1_startxDI;
            master_txDataxDO <= C1_txDataxDI;
            master_txDataWLengthxDO <= C1_txDataWLengthxDI;
            master_rxDataWLengthxDO <= C1_rxDataWLengthxDI;

            C1_ackxDO <= master_ackxDI;
            C1_ackErrxDO <= master_ackErrxDI;
            C1_busyxDO <= master_busyxDI;
            C1_rxDataxDO <= master_rxDataxDI;

            C2_ackxDO <= '0';
            C2_ackErrxDO <= '0';
            C2_busyxDO <= '0';
            C2_rxDataxDO <= (others => '0');

        elsif (C2_lockAckxDP = '1') then
            master_startxDO <= C2_startxDI;
            master_txDataxDO <= C2_txDataxDI;
            master_txDataWLengthxDO <= C2_txDataWLengthxDI;
            master_rxDataWLengthxDO <= C2_rxDataWLengthxDI;

            C2_ackxDO <= master_ackxDI;
            C2_ackErrxDO <= master_ackErrxDI;
            C2_busyxDO <= master_busyxDI;
            C2_rxDataxDO <= master_rxDataxDI;

            C1_ackxDO <= '0';
            C1_ackErrxDO <= '0';
            C1_busyxDO <= '0';
            C1_rxDataxDO <= (others => '0');
        else
            master_startxDO <= '0';
            master_txDataxDO <= (others => '0');
            master_txDataWLengthxDO <= (others => '0');
            master_rxDataWLengthxDO <= (others => '0');

            C1_ackxDO <= '0';
            C1_ackErrxDO <= '0';
            C1_busyxDO <= '0';
            C1_rxDataxDO <= (others => '0');

            C2_ackxDO <= '0';
            C2_ackErrxDO <= '0';
            C2_busyxDO <= '0';
            C2_rxDataxDO <= (others => '0');
        end if;
    end process MUX;

    C1_lockAckxDO <= C1_lockAckxDP;
    C2_lockAckxDO <= C2_lockAckxDP;

end architecture behavioural;
