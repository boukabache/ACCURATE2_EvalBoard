--! @file RegisterFile.vhd
--! @brief Translation level for the BRAM. Default variables are stored here.

library ieee;
use ieee.std_logic_1164.all;

use work.IOPkg.all;

entity RegisterFile is
    port (
        clk     : in  std_logic;     -- Clock input
        rst     : in  std_logic;     -- Reset input

        -- DAC configuration signals
        dacConfigxDO : out dacConfigRecordT;

        -- ACCURATE configuration signals
        accurateConfigxDO      : out accurateRecordT;
        accurateConfigValidxDO : out std_logic

    );
end entity RegisterFile;



architecture rtl of RegisterFile is
    
begin
    -- Values generated with the Din_calculator.py script
    dacConfigxDO.vOutA <= "100010001000"; -- A1_Vbias1   = 1.6V 
    dacConfigxDO.vOutB <= "100000000000"; -- Vcm         = 1.5V 
    dacConfigxDO.vOutC <= "110101010101"; -- A1_Vth1     = 1.55V
    dacConfigxDO.vOutD <= "110101010101"; -- A1_Vcharge+ = 2.5V 
    dacConfigxDO.vOutE <= "100010001000"; -- A1_Vth2     = 1.6V 
    dacConfigxDO.vOutF <= "110101010101"; -- A1_Vth4     = 2.5V 
    dacConfigxDO.vOutG <= "100111000010"; -- A1_Vth3     = 1.83V
    dacConfigxDO.vOutH <= "011001001011"; -- A1_Vbias3  = 1.18V


    -- Default values for the ACCURATE configuration
    accurateConfigxDO.chargeQuantaCP1     <= (others => '0');
    accurateConfigxDO.chargeQuantaCP2     <= (others => '0');
    accurateConfigxDO.chargeQuantaCP3     <= (others => '0');
    accurateConfigxDO.cooldownMinCP1      <= (others => '0');
    accurateConfigxDO.cooldownMaxCP1      <= (others => '0');
    accurateConfigxDO.cooldownMinCP2      <= (others => '0');
    accurateConfigxDO.cooldownMaxCP2      <= (others => '0');
    accurateConfigxDO.cooldownMinCP3      <= (others => '0');
    accurateConfigxDO.cooldownMaxCP3      <= (others => '0');
    accurateConfigxDO.resetOTA            <= '0'; -- NOT FOUND in local_parameters.dat.blank
    accurateConfigxDO.tCharge             <= x"07";
    accurateConfigxDO.tInjection          <= x"08";
    accurateConfigxDO.disableCP1          <= '0';
    accurateConfigxDO.disableCP2          <= '0';
    accurateConfigxDO.disableCP3          <= '0';
    accurateConfigxDO.singlyCPActivation  <= '0';
    

end architecture rtl;