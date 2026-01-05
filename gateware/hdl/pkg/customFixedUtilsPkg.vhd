library ieee;
use ieee.std_logic_1164.all;

use ieee.fixed_pkg.all;

package customFixedUtilsPkg is

    procedure accumulate (
        constant L, R   : in  sfixed;
        signal result : out sfixed;
        signal overflow  : out std_logic
    );

end package customFixedUtilsPkg;

package body customFixedUtilsPkg is

    procedure accumulate (
        constant L, R   : in  sfixed;
        signal result : out sfixed;
        signal overflow  : out std_logic
    ) is

        constant left_index       : integer := maximum(L'high, R'high);
        constant right_index      : integer := minimum(L'low, R'low);

        variable lresize, rresize : sfixed(left_index downto right_index);
        variable result_tmp : sfixed(left_index + 1 downto right_index);

    begin

        lresize    := resize (L, left_index, right_index);
        rresize    := resize (R, left_index, right_index);

        result_tmp := lresize + rresize;

        overflow <= result_tmp(left_index - right_index) xor result_tmp(result_tmp'left);
        result <= resize(result_tmp, left_index, right_index);

    end procedure accumulate;

end package body customFixedUtilsPkg;
