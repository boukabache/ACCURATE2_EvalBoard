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
        vOutC => "100001000100", -- A1_Vth1     = 1.55V
        vOutD => "110101010101", -- A1_Vcharge+ = 2.5V
        vOutE => "100010001000", -- A1_Vth2     = 1.6V
        vOutF => "110101010101", -- A1_Vth4     = 2.5V
        vOutG => "100111000010", -- A1_Vth3     = 1.83V
        vOutH => "011001001011" -- A1_Vbias3    = 1.18V
    );

    --! Record for the SHT41 sensor output data
    type sht41RecordT is record
        temperature : std_logic_vector(16 - 1 downto 0);
        humidity    : std_logic_vector(16 - 1 downto 0);
        dataValid   : std_logic;
    end record sht41RecordT;

    --! Reset record for the sht41RecordT
    constant sht41RecordTInit : sht41RecordT := (
        temperature => (others => '0'),
        humidity    => (others => '0'),
        dataValid   => '0'
    );

end package IOPkg;  