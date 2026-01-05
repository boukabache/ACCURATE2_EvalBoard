library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipelined_increment is
    generic (
        stageBitwidthG : integer := 4;
        inputBitwidthG : integer := 16;
        signedG : std_logic := '0'
    );
    port (
        clk  : in std_logic;
        rst  : in std_logic; -- Unused
        axDI    : in unsigned(inputBitwidthG-1 downto 0);
        sumxDO  : out unsigned(inputBitwidthG-1 downto 0);
        overflowxDO : out std_logic
    );
end pipelined_increment;

architecture behavioral of pipelined_increment is
    constant stageNumber : integer := inputBitwidthG/stageBitwidthG;
    type input_registerT is array (0 to stageNumber) of unsigned(inputBitwidthG-1 downto 0);
    signal axDP : input_registerT := (others => (others => '0'));

    type sumInputStageT is array (0 to stageNumber-1) of unsigned(stageBitwidthG-1 downto 0);
    signal sumInputA : sumInputStageT;

    type sumStageT is array (0 to stageNumber-1) of unsigned(stageBitwidthG downto 0);
    signal sum : sumStageT := (others => (others => '0'));


    type resultT is array (0 to stageNumber) of unsigned(inputBitwidthG-1 downto 0);
    signal resultxDN, resultxDP : resultT := (others => (others => '0'));

    type carry_stageT is array (0 to stageNumber) of unsigned(0 downto 0);
    signal carry_regxDN, carry_regxDP : carry_stageT := (others => (others => '0'));

begin
    assert (inputBitwidthG mod stageBitwidthG = 0)
            report "Error: stageBitwidthG must perfectly divide inputBitwidthG"
            severity error;

    process (clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                resultxDP(1 to stageNumber) <= (others => (others => '0'));
                carry_regxDP <= (others => (others => '0'));
                axDP(1 to axDP'right) <= (others => (others => '0'));

            else
                resultxDP(1 to stageNumber) <= resultxDN(1 to stageNumber);
                carry_regxDP <= carry_regxDN;

                axDP(1 to stageNumber) <= axDP(0 to stageNumber-1);
            end if;
        end if;
    end process;

    axDP(0) <= axDI;
    carry_regxDN(0) <= to_unsigned(1, 1);
    resultxDP(0) <= (others => '0');
    -- Following is not required, but avoids warnings
    resultxDN(0) <= (others => '0');

    gen_pipeline: for i in 0 to stageNumber-1 generate
        sumInputA(i) <= axDP(i)(stageBitwidthG * (i+1) - 1 downto stageBitwidthG * i);

        sum(i) <= ('0' & sumInputA(i)) +
                    (to_unsigned(0, stageBitwidthG) & carry_regxDP(i));

        resultxDN(i+1) <= sum(i)(stageBitwidthG-1 downto 0) & resultxDP(i)(inputBitwidthG-1 downto stageBitwidthG);
        carry_regxDN(i+1) <= sum(i)(stageBitwidthG downto stageBitwidthG);
    end generate gen_pipeline;

    overflowxDO <= '1' when signedG = '1' and
                                axDP(stageNumber - 1)(inputBitwidthG-1) = '0' and
                                resultxDN(stageNumber)(inputBitwidthG-1) = '1' else
                   '1' when signedG = '1' and
                                axDP(stageNumber - 1)(inputBitwidthG-1) = '1' and
                                resultxDP(stageNumber)(inputBitwidthG-1) = '0' else
                   '1' when signedG = '0' and
                                carry_regxDN(stageNumber)(0) = '1' else
                   '0';

    sumxDO <= resultxDN(resultxDN'right);

end behavioral;
