library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;

--! Defines record holding configuration for the accurateFrontend

package accurateConfigPkg is
    type accurateRecordT is record
        --! Charge injected by one activation of CP1, with LSB=39.3390656 atto coulomb
        chargeQuantaCP1 : signed(18 - 1 downto 0);
        --! Charge injected by one activation of CP2, with LSB=39.3390656 atto coulomb
        chargeQuantaCP2 : signed(18 - 1 downto 0);
        --! Charge injected by one activation of CP3, with LSB=39.3390656 atto coulomb
        chargeQuantaCP3 : signed(18 - 1 downto 0);
        --! Minimum interval between two activation of the corresponding charge pump, in number of charge/discharge cycles.
        cooldownMinCP1 : unsigned(16 - 1 downto 0);
        --! Maximum interval between two activation of the corresponding charge pump, in number of charge/discharge cycles.
        cooldownMaxCP1 : unsigned(16 - 1 downto 0);
        --! Minimum interval between two activation of the corresponding charge pump, in number of charge/discharge cycles.
        cooldownMinCP2 : unsigned(16 - 1 downto 0);
        --! Maximum interval between two activation of the corresponding charge pump, in number of charge/discharge cycles.
        cooldownMaxCP2 : unsigned(16 - 1 downto 0);
        --! Minimum interval between two activation of the corresponding charge pump, in number of charge/discharge cycles.
        cooldownMinCP3 : unsigned(16 - 1 downto 0);
        --! Maximum interval between two activation of the corresponding charge pump, in number of charge/discharge cycles.
        cooldownMaxCP3 : unsigned(16 - 1 downto 0);
        --! As long as it is one, the switch short circuiting the output to the input of the OTA is closed
        resetOTA : std_logic;
        --! Time duration in clock cycles for recharge of the charge pump. 0 is automatically corrected to 1
        tCharge : unsigned(8 - 1 downto 0);
        --! Time duration in clock cycles for activation (injection) of the charge pump. 0 is automatically corrected to 1
        tInjection : unsigned(8 - 1 downto 0);
        --! Do not use first charge pump
        disableCP1 : std_logic;
        --! Do not use second charge pump
        disableCP2 : std_logic;
        --! Do not use third charge pump
        disableCP3 : std_logic;
        --! If high and multiple charge pumps would activate at the same time, only the largest one activates.
        singlyCPActivation : std_logic;
    end record accurateRecordT;

    constant accurateRecordTInit : accurateRecordT := (
        chargeQuantaCP1 => (others => '0'),
        chargeQuantaCP2 => (others => '0'),
        chargeQuantaCP3 => (others => '0'),
        cooldownMinCP1 => (others => '0'),
        cooldownMaxCP1 => (others => '0'),
        cooldownMinCP2 => (others => '0'),
        cooldownMaxCP2 => (others => '0'),
        cooldownMinCP3 => (others => '0'),
        cooldownMaxCP3 => (others => '0'),
        resetOTA => '0',
        tCharge => (others => '0'),
        tInjection => (others => '0'),
        disableCP1 => '0',
        disableCP2 => '0',
        disableCP3 => '0',
        singlyCPActivation => '0');

    --! Default values for the ACCURATE configuration
    --! chargeQuanta values generated with the chargeQuanta_calculator.py script
    constant accurateRecordTDefault : accurateRecordT := (
        chargeQuantaCP1      => "000011000110100110",
        chargeQuantaCP2      => "000110001101001100",
        chargeQuantaCP3      => "011000110100110000",
        cooldownMinCP1       => (others => '0'),
        cooldownMaxCP1       => (others => '0'),
        cooldownMinCP2       => (others => '0'),
        cooldownMaxCP2       => (others => '0'),
        cooldownMinCP3       => (others => '0'),
        cooldownMaxCP3       => (others => '0'),
        resetOTA             => '0',
        tCharge              => x"07",
        tInjection           => x"08",
        disableCP1           => '0',
        disableCP2           => '0',
        disableCP3           => '0',
        singlyCPActivation   => '0'
    );


end package accurateConfigPkg;
