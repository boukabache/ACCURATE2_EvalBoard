--! @file IOPkg.vhd
--! @brief This package contains the records of the internal busses
--!
--! The package contains the following records:
--! - dacConfig: record for the configuration of the DAC outputs
--! - accurate:  record for the configuration of the ACCURATE ASIC


--! Use standard library
library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;

package IOPkg is

    --! Record for the configuration of the voltage outputs of the DAC
    --! The Vout voltage of the DAC's channels is determined by the following
    --! formula:
    --! Vout = Vref * (D/4096)
    --! where D is the 12-bit digital ([A-H]xDI) value and Vref is the
    --! reference voltage.
    --! In the current Evaluation board design, Vref is 3V.
    --! 4069 is given by 2^n, where n is the number of bits of the DAC (12-bit).
    type dacConfigRecordT is record
        vOutA : unsigned(11 downto 0);
        vOutB : unsigned(11 downto 0);
        vOutC : unsigned(11 downto 0);
        vOutD : unsigned(11 downto 0);
        vOutE : unsigned(11 downto 0);
        vOutF : unsigned(11 downto 0);
        vOutG : unsigned(11 downto 0);
        vOutH : unsigned(11 downto 0);
    end record dacConfigRecordT;

    --! Reset record for the dacConfigRecordT
    constant dacConfigRecordTInit : dacConfigRecordT := (
        vOutA => (others => '0'),
        vOutB => (others => '0'),
        vOutC => (others => '0'),
        vOutD => (others => '0'),
        vOutE => (others => '0'),
        vOutF => (others => '0'),
        vOutG => (others => '0'),
        vOutH => (others => '0')
    );

    --! Default values for the DAC configuration
    --! Values generated with the Din_calculator.py script
    constant dacConfigRecordTDefault : dacConfigRecordT := (
        vOutA => "100010001000", -- A1_Vbias1   = 1.6V 
        vOutB => "100000000000", -- Vcm         = 1.5V 
        vOutC => "110101010101", -- A1_Vth1     = 1.55V
        vOutD => "110101010101", -- A1_Vcharge+ = 2.5V 
        vOutE => "100010001000", -- A1_Vth2     = 1.6V 
        vOutF => "110101010101", -- A1_Vth4     = 2.5V 
        vOutG => "100111000010", -- A1_Vth3     = 1.83V
        vOutH => "011001001011" -- A1_Vbias3    = 1.18V
    );




    --! Record for the configuration of ACCURATE
    type accurateRecordT is record
        --! Charge injected by one activation of CP1, with LSB=39.3390656 atto coulomb
        chargeQuantaCP1 : signed(24 - 1 downto 0);
        --! Charge injected by one activation of CP2, with LSB=39.3390656 atto coulomb
        chargeQuantaCP2 : signed(24 - 1 downto 0);
        --! Charge injected by one activation of CP3, with LSB=39.3390656 atto coulomb
        chargeQuantaCP3 : signed(24 - 1 downto 0);
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

    --! Reset record for the accurateRecordT
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
        singlyCPActivation => '0'
    );

    --! Default values for the ACCURATE configuration
    constant accurateRecordTDefault : accurateRecordT := (
        chargeQuantaCP1      => (others => '0'),
        chargeQuantaCP2      => (others => '0'),
        chargeQuantaCP3      => (others => '0'),
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


end package IOPkg;  