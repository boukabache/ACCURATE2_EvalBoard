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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.IOPkg.all;
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

    dacConfigxDO <= dacConfigRecordTDefault;

    -- Not supported yet
    accurateConfigxDO <= accurateRecordTDefault; -- or accurateRecordTDefault
    

end architecture rtl;