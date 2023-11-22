library ieee;
use ieee.std_logic_1164.all;

entity top is
    port (
        led_green : out std_logic;
        led_red : out std_logic;
        led_blue : out std_logic
    );
end entity top;

architecture arch of top is
begin
    led_green <= '0';
    led_red <= '0';
    led_blue <= '0';
end architecture arch;
