library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipelined_adder is
    generic (
        stageBitwidthG : integer := 4;
        inputBitwidthG : integer := 16
    );
    port (
        clk  : in std_logic;
        rst  : in std_logic; -- Unused
        axDI    : in signed(inputBitwidthG-1 downto 0);
        bxDI    : in signed(inputBitwidthG-1 downto 0);
        sumxDO  : out signed(inputBitwidthG-1 downto 0);
        overflowxDO : out std_logic
    );
end pipelined_adder;

architecture behavioral of pipelined_adder is
    constant stageNumber : integer := inputBitwidthG/stageBitwidthG;
    type input_registerT is array (0 to stageNumber) of signed(inputBitwidthG-1 downto 0);
    signal axDP, bxDP : input_registerT;

    type sumInputStageT is array (0 to stageNumber-1) of signed(stageBitwidthG-1 downto 0);
    signal sumInputA : sumInputStageT;
    signal sumInputB : sumInputStageT;

    type sumStageT is array (0 to stageNumber-1) of signed(stageBitwidthG downto 0);
    signal sum : sumStageT;


    type resultT is array (0 to stageNumber) of signed(inputBitwidthG-1 downto 0);
    signal resultxDN, resultxDP : resultT;

    type carry_stageT is array (0 to stageNumber) of signed(0 downto 0);
    signal carry_regxDN, carry_regxDP : carry_stageT;

begin
    assert (inputBitwidthG mod stageBitwidthG = 0)
            report "Error: stageBitwidthG must perfectly divide inputBitwidthG"
            severity error;

    process (clk)
    begin
        if rising_edge(clk) then
            resultxDP <= resultxDN;
            carry_regxDP <= carry_regxDN;

            axDP(1 to stageNumber) <= axDP(0 to stageNumber-1);
            bxDP(1 to stageNumber) <= bxDP(0 to stageNumber-1);
        end if;
    end process;

    axDP(0) <= axDI;
    bxDP(0) <= bxDI;

    carry_regxDN(0) <= to_signed(0, 1);

    gen_pipeline: for i in 0 to stageNumber-1 generate
        sumInputA(i) <= axDP(i)(stageBitwidthG * (i+1) - 1 downto stageBitwidthG * i);
        sumInputB(i) <= bxDP(i)(stageBitwidthG * (i+1) - 1 downto stageBitwidthG * i);

        sum(i) <= ('0' & sumInputA(i)) +
                    ('0' & sumInputB(i)) +
                    (to_signed(0, stageBitwidthG) & carry_regxDP(i));

        resultxDN(i+1) <= sum(i)(stageBitwidthG-1 downto 0) & resultxDP(i)(inputBitwidthG-1 downto stageBitwidthG);
        carry_regxDN(i+1) <= sum(i)(stageBitwidthG downto stageBitwidthG);
    end generate gen_pipeline;

    overflowxDO <= '1' when axDP(stageNumber)(inputBitwidthG-1) = '0' and
                                bxDP(stageNumber)(inputBitwidthG-1) = '0' and
                                resultxDP(stageNumber)(inputBitwidthG-1) = '1' else
                   '1' when axDP(stageNumber)(inputBitwidthG-1) = '1' and
                                bxDP(stageNumber)(inputBitwidthG-1) = '1' and
                                resultxDP(stageNumber)(inputBitwidthG-1) = '0' else
                   '0';

    sumxDO <= resultxDP(stageNumber);

end behavioral;
