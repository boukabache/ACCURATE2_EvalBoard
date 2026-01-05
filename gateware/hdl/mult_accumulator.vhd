--! Use standard library
library ieee;
--! For logic elements
use ieee.std_logic_1164.all;
--! For using natural type
use ieee.numeric_std.all;

entity mult_accumulator is
    generic (
        ABitwidthG : integer := 8;
        BBitwidthG : integer := 8;
        resultBitwidthG : integer := 32
    );
    port (
        clk : in  std_logic;
        rst : in  std_logic;

        startxDI : in  std_logic;

        A1xDI : in  unsigned(ABitwidthG - 1 downto 0);
        B1xDI : in  signed(BBitwidthG - 1 downto 0);

        A2xDI : in  unsigned(ABitwidthG - 1 downto 0);
        B2xDI : in  signed(BBitwidthG - 1 downto 0);

        A3xDI : in  unsigned(ABitwidthG - 1 downto 0);
        B3xDI : in  signed(BBitwidthG - 1 downto 0);

        resultxDO : out signed(resultBitwidthG - 1 downto 0);
        resultValidxDO : out std_logic
    );
end entity mult_accumulator;

architecture behavior of mult_accumulator is
    signal accumulatorxDP, accumulatorxDN : signed(resultBitwidthG - 1 downto 0);

    signal multResultxDP, multResultxDN : signed(ABitwidthG + BBitwidthG - 1 downto 0);

    signal processStagexDP, processStagexDN : integer range 0 to 5 := 5;

    type AArrayT is array (0 to 2) of unsigned(ABitwidthG - 1 downto 0);
    type BArrayT is array (0 to 2) of signed(BBitwidthG - 1 downto 0);

    signal AArray : AArrayT := (others => (others => '0'));
    signal BArray : BArrayT := (others => (others => '0'));

begin
    AArray <= (A1xDI, A2xDI, A3xDI);
    BArray <= (B1xDI, B2xDI, B3xDI);

    processStagexDN <= 0 when startxDI = '1' else
                       5 when processStagexDP = 5 else
                       processStagexDP + 1;

    -- Lots of casting here. The unsigned element is casted to signed, adding a dummy bit in front of it.
    -- This causes the multiplication result to also have a dummy bit, which we can then get rid of.
    multResultxDN <= resize(signed('0' & AArray(processStagexDP)) * BArray(processStagexDP),
                            ABitwidthG + BBitwidthG) when processStagexDP < 3 else
                     (others => '0');

    accumulatorxDN <= multResultxDP + accumulatorxDP when processStagexDP /= 0 else
                      (others => '0');

    regP : process (clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                accumulatorxDP <= (others => '0');
                multResultxDP <= (others => '0');
                processStagexDP <= 0;
            else
                accumulatorxDP <= accumulatorxDN;
                multResultxDP <= multResultxDN;
                processStagexDP <= processStagexDN;
            end if;
        end if;
    end process regP;

    resultxDO <= accumulatorxDP;
    resultValidxDO <= '1' when processStagexDP = 4 else
                      '0';

end architecture behavior;
