-------------------------------------------------------
--! @file
--! @brief Contains constants used in the design
-------------------------------------------------------
-- Copyright (C) CERN CROME Project
-- Author:         Ciaran Toner
-- Target Device:  Zynq 7020/7010
-- Revision List
-- Version      Date            Modifications
-- 1.0          02/05/2017      File Created
-------------------------------------------------------

--! Use standard library
library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;

--! Constants that may need to be configured and constants that are shared by
--! multiple files in the design are stored in this file. The *VHDL_VERSION*
--! details the version of the VHDL code. This is manually updated when the
--! interface with the PS changes. The PS performs a check when running to
--! ensure that the *VHDL_VERSION* in the PL matches the version in the PL,
--! otherwise the software will not run.

--! Warning! The @variables@ (e.g: @GIT_HASH@ will be expended by the configure
--! script. To modify their values, either use the correct option during
--! `./configure` or modify the configure.ac script to add/correct options.

package configPkg is

    --*************************************************************************
    ------------------------------- Constants----------------------------------
    --*************************************************************************

    -------------------- Register Length Configuration ------------------------
    --! Length of register required to store the voltage sum data
    constant voltageChangeRegLengthC    : natural := 52;
   
    ------------------------ FSM Safe State -----------------------------------
    --! String for safe state attribute. Provides Hamming 3 encoding on state
    --! machines to recover from SEUs to state machine stage registers
    constant fsmSafeStateStringC : string := "auto_safe_state";

    ------------------------ Timing Configuration -----------------------------
    --!The frequency of the clock in MHz
    constant clkFreqMhzC     : real := 20.0;
    --!The period of the clock in nano seconds
    constant clkPeriodNsC    : natural := natural(1000.0 / clkFreqMhzC);
    --!The 100ms cycle period converted to number of clock cycles
    constant cyclePeriodC    : natural := 100_000_000 / clkPeriodNsC; --100ms
    --!The period at which to read the IVCs ADC
    constant samplePeriodMsC : natural := 1;
    --!The sample period converted to number of clock cycles
    constant samplePeriodC   : natural := (samplePeriodMsC * 1_000_000) / clkPeriodNsC;

    type DAC7578InputsT is array (7 downto 0) of std_logic_vector(11 downto 0);

end package configPkg;
