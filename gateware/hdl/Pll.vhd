--! @file Pll.vhd
--! @brief Basic wrapper for the PLL SiliconBlue Hard IP core for iCE40 FPGAs
--
--! Documentation can be found in the official Lattice documentation:
--! https://www.latticesemi.com/-/media/LatticeSemi/Documents/ApplicationNotes/IK2/FPGA-TN-02052-1-4-iCE40-sysCLOCK-PLL-Design-User-Guide.ashx?document_id=47778
--
--! The IP core is replaced by looking in the available predefined cells
--! in the cells_sim.v file. The _CORE is for internal input clock (like
--! coming from the interal oscillator) and _PAD is for external input
--! clock (coming from an I/O pad).
--
--! The formula used to calculate the PLL parameters is (only with simple feedback path):
--! clkOut = (clkIn * (DIVF+1)) / (2^DIVQ * (DIVR+1))
--! It is advised to use the icepll tool to calculate the parameters.
--!
--! When using the double output PLL, Port A is forwarding the input clock
--! and Port B is the output clock.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Pll is
    generic (
        DIVQ_G         : bit_vector(2 downto 0) := "000";
        DIVR_G         : bit_vector(3 downto 0) := "0000";
        DIVF_G         : bit_vector(6 downto 0) := "0000000";
        FILTER_RANGE_G : bit_vector(2 downto 0) := "000"
    );
    port (
        clkInxDI        : in std_logic;
        clkInForwardxDO : out std_logic;
        clkOutxDO       : out std_logic
    );
end entity Pll;

architecture rtl of Pll is
    -- Component declaration for PLL
    -- SiliconBlue PLL Cell (proprietary IP)
    component SB_PLL40_2_PAD is
        generic (
            FEEDBACK_PATH                   : string := "SIMPLE";
            DELAY_ADJUSTMENT_MODE_FEEDBACK  : string := "FIXED";
            DELAY_ADJUSTMENT_MODE_RELATIVE  : string := "FIXED";
            SHIFTREG_DIV_MODE               : bit_vector(1 downto 0) := "00";
            FDA_FEEDBACK                    : bit_vector(3 downto 0) := "0000";
            FDA_RELATIVE                    : bit_vector(3 downto 0) := "0000";
            PLLOUT_SELECT_PORTB             : string := "GENCLK";
            DIVR                            : bit_vector(3 downto 0) := x"0";
            DIVF                            : bit_vector(6 downto 0) := "0000000";
            DIVQ                            : bit_vector(2 downto 0) := "000";
            FILTER_RANGE                    : bit_vector(2 downto 0) := "000";
            ENABLE_ICEGATE_PORTA            : bit := '0';
            ENABLE_ICEGATE_PORTB            : bit := '0';
            TEST_MODE                       : bit := '0';
            EXTERNAL_DIVIDE_FACTOR          : integer := 1
        );
        port (
            PACKAGEPIN       : in  std_logic;
            PLLOUTCOREA      : out std_logic;
            PLLOUTGLOBALA    : out std_logic;
            PLLOUTCOREB      : out std_logic;
            PLLOUTGLOBALB    : out std_logic;
            EXTFEEDBACK      : in  std_logic;
            DYNAMICDELAY     : in  std_logic_vector(7 downto 0);
            LOCK             : out std_logic;
            BYPASS           : in  std_logic;
            RESETB           : in  std_logic;
            LATCHINPUTVALUE  : in  std_logic;
            SDO              : out std_logic;
            SDI              : in  std_logic;
            SCLK             : in  std_logic
        );
    end component;

begin
    -- Instantiate PLL
    pll_inst : SB_PLL40_2_PAD
        generic map (
            FEEDBACK_PATH => "SIMPLE",
            DIVR          => DIVR_G,
            DIVF          => DIVF_G,
            DIVQ          => DIVQ_G,
            FILTER_RANGE  => FILTER_RANGE_G
        )
        port map (
            PACKAGEPIN       => clkInxDI, -- Input clock, from I/O pad
            PLLOUTCOREA      => clkInForwardxDO, -- Forward of input clock
            PLLOUTGLOBALA    => open, -- DO NOT WORK, CONSTANT 0 - Output clock, drives a general clock network
            PLLOUTCOREB      => clkOutxDO, -- Output clock, for general FPGA routing
            PLLOUTGLOBALB    => open, -- DO NOT WORK, CONSTANT 0
            EXTFEEDBACK      => '0',
            DYNAMICDELAY     => x"00",
            LOCK             => open,
            BYPASS           => '0',
            RESETB           => '1',
            LATCHINPUTVALUE  => '0',
            SDO              => open,
            SDI              => '0',
            SCLK             => '0'
    );

end architecture rtl;