--! @file RegisterFile.vhd
--! @brief Module to store the temporary configuration of the DAC and ACCURATE
--! coming from the UART interface. It also drives the configuration signals.
--
--! Reset can be configured to either reset the configuration to default values
--! or to all zeros.
--
--! The address map is as follows:
--! 0x00 - 0x07: DAC configuration voltages
--! |-> 0x00: vOutA
--! |-> 0x01: vOutB
--! |-> 0x02: vOutC
--! |-> 0x03: vOutD
--! |-> 0x04: vOutE
--! |-> 0x05: vOutF
--! |-> 0x06: vOutG
--! |-> 0x07: vOutH
--! 0x08 - 0x17: ACCURATE configuration
--! |-> 0x08: chargeQuantaCP1
--! |-> 0x09: chargeQuantaCP2
--! |-> 0x0A: chargeQuantaCP3
--! |-> 0x0B: cooldownMinCP1
--! |-> 0x0C: cooldownMaxCP1
--! |-> 0x0D: cooldownMinCP2
--! |-> 0x0E: cooldownMaxCP2
--! |-> 0x0F: cooldownMinCP3
--! |-> 0x10: cooldownMaxCP3
--! |-> 0x11: resetOTA
--! |-> 0x12: tCharge
--! |-> 0x13: tInjection
--! |-> 0x14: disableCP1
--! |-> 0x15: disableCP2
--! |-> 0x16: disableCP3
--! |-> 0x17: singlyCPActivation

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.IOPkg.all;
use work.accurateConfigPkg.all;
use work.configPkg.all;

entity RegisterFile is
    port (
        clk     : in  std_logic;     -- Clock input
        rst     : in  std_logic;     -- Reset input

        -- DAC configuration signals
        dacConfigxDO : out dacConfigRecordT;

        -- ACCURATE configuration signals
        accurateConfigxDO      : out accurateRecordT;
        accurateConfigValidxDO : out std_logic;

        -- Input port
        addressxDI   : in unsigned(registerFileAddressWidthC-1 downto 0); -- Address input
        dataxDI      : in std_logic_vector(registerFileDataWidthC-1 downto 0); -- Data input
        dataValidxDI : in std_logic -- Data valid input

    );
end entity RegisterFile;


architecture rtl of RegisterFile is
    type memoryT is
        array ( 0 to ((2 ** registerFileAddressWidthC) - 1)) of
        std_logic_vector(registerFileDataWidthC - 1 downto 0);

    signal regFile : memoryT;

begin

    -----------------
    -- INPUT
    -----------------
    inputP: process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- dacConfigxDO <= dacConfigRecordTInit; -- or dacConfigRecordTDefault
                -- accurateConfigxDO <= accurateRecordTInit; -- or accurateRecordTDefault
            else
                if dataValidxDI = '1' then
                    regFile(to_integer(addressxDI)) <= dataxDI;
                end if;

            end if;
        end if;
    end process inputP;


    -----------------
    -- OUTPUT
    -----------------
    -- dacConfigxDO.vOutA <= unsigned(regFile(0)(11 downto 0));
    -- dacConfigxDO.vOutB <= unsigned(regFile(1)(11 downto 0));
    -- dacConfigxDO.vOutC <= unsigned(regFile(2)(11 downto 0));
    -- dacConfigxDO.vOutD <= unsigned(regFile(3)(11 downto 0));
    -- dacConfigxDO.vOutE <= unsigned(regFile(4)(11 downto 0));
    -- dacConfigxDO.vOutF <= unsigned(regFile(5)(11 downto 0));
    -- dacConfigxDO.vOutG <= unsigned(regFile(6)(11 downto 0));
    -- dacConfigxDO.vOutH <= unsigned(regFile(7)(11 downto 0));

    -- Required as without reset the configuration is not initialized
    dacConfigxDO <= dacConfigRecordTDefault;


    -- accurateConfigxDO.chargeQuantaCP1    <= signed(regFile(8)(23 downto 0));
    -- accurateConfigxDO.chargeQuantaCP2    <= signed(regFile(9)(23 downto 0));
    -- accurateConfigxDO.chargeQuantaCP3    <= signed(regFile(10)(23 downto 0));
    -- accurateConfigxDO.cooldownMinCP1     <= unsigned(regFile(11)(15 downto 0));
    -- accurateConfigxDO.cooldownMaxCP1     <= unsigned(regFile(12)(15 downto 0));
    -- accurateConfigxDO.cooldownMinCP2     <= unsigned(regFile(13)(15 downto 0));
    -- accurateConfigxDO.cooldownMaxCP2     <= unsigned(regFile(14)(15 downto 0));
    -- accurateConfigxDO.cooldownMinCP3     <= unsigned(regFile(15)(15 downto 0));
    -- accurateConfigxDO.cooldownMaxCP3     <= unsigned(regFile(16)(15 downto 0));
    -- accurateConfigxDO.resetOTA           <= regFile(17)(0);
    -- accurateConfigxDO.tCharge            <= unsigned(regFile(18)(7 downto 0));
    -- accurateConfigxDO.tInjection         <= unsigned(regFile(19)(7 downto 0));
    -- accurateConfigxDO.disableCP1         <= regFile(20)(0);
    -- accurateConfigxDO.disableCP2         <= regFile(21)(0);
    -- accurateConfigxDO.disableCP3         <= regFile(22)(0);
    -- accurateConfigxDO.singlyCPActivation <= regFile(23)(0);

    -- Required as without reset the configuration is not initialized
    accurateConfigxDO <= accurateRecordTDefault;
    accurateConfigValidxDO <= '1';


end architecture rtl;
