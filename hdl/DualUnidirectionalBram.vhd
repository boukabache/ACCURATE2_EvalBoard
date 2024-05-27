--! @file DualUnidirectionalBram.vhd
--! @brief Dual port, read-only + write-only BRAM with single clock
--!
--! This module implements a dual port BRAM with one port for reading
--! and one port for writing.
--! The module is correctly recognised as a BRAM cell by the GHDL+Yosys
--! synthesis flow, exploiting the iCE40 BRAM Hard IP.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DualUnidirectionalBram is
    generic (
        DATA_BW_G : integer := 32;
        ADDR_BW_G : integer := 10
    );
    port (
        clk   : in  std_logic;

        -- Port A
        --! Write enable signal for port A
        wePortAxDI       : in  std_logic;
        addressPortAxDI  : in  unsigned(ADDR_BW_G - 1 downto 0);
        dataInPortAxDI   : in  std_logic_vector(DATA_BW_G - 1 downto 0);
        -- Port B
        addressPortBxDI  : in  unsigned(ADDR_BW_G - 1 downto 0);
        dataOutPortBxDO  : out std_logic_vector(DATA_BW_G - 1 downto 0)
    );
end entity DualUnidirectionalBram;

architecture behaviour of DualUnidirectionalBram is
    type mem_type is
        array ( (2 ** ADDR_BW_G) - 1 downto 0 ) of
        std_logic_vector(DATA_BW_G - 1 downto 0);

    signal mem : mem_type;
begin

    regP : process (clk)
    begin
        if rising_edge(clk) then
            if (wePortAxDI = '1') then
                mem(to_integer(addressPortAxDI)) <= dataInPortAxDI;
            end if;

            dataOutPortBxDO <= mem(to_integer(addressPortBxDI));
        end if;
    end process regP;

end architecture behaviour;