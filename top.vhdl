library ieee;
use ieee.std_logic_1164.all;

entity top is
  port (
    led_green : out std_logic;
    led_red : out std_logic;
    led_blue : out std_logic;
    scl : inout std_logic;
    sda : inout std_logic;
    sdaFeedback : out std_logic;
    clk : in std_logic;
    sw1 : in std_logic
  );
end entity top;

architecture arch of top is
  signal clk_100kHz : std_logic := '0';
  signal counter : integer range 0 to 59 := 0;
  signal second_counter : integer range 0 to 12000000 := 0;
  signal send_message : std_logic := '0';

  component I2C_slave is
    generic (
      SLAVE_ADDR : std_logic_vector(6 downto 0)
    );
    port (
      scl : inout std_logic;
      sda : inout std_logic;
      clk : in std_logic;
      read_req : out std_logic;
      data_to_master : in std_logic_vector(7 downto 0);
      data_valid : out std_logic;
      data_from_master : out std_logic_vector(7 downto 0);
      led_blue : out std_logic;
      rst : in std_logic
    );
  end component I2C_slave;

  signal data_valid : std_logic;
  signal read_req : std_logic;
  signal data_from_master : std_logic_vector(7 downto 0);
  signal data_to_master : std_logic_vector(7 downto 0);
  signal data_received : std_logic;
  signal reset : std_logic;
  signal bit_counter : integer range 0 to 7 := 0;  -- Add this line



begin
  led_red <= '1';

  clk_gen : process (clk)
  begin
    if rising_edge(clk) then
      if counter = 59 then
        clk_100kHz <= not clk_100kHz;
        counter <= 0;
      else
        counter <= counter + 1;
      end if;

      if second_counter = 12000000 then
        send_message <= '1';
        second_counter <= 0;
      else
        send_message <= '0';
        second_counter <= second_counter + 1;
      end if;
    end if;
  end process clk_gen;

  reset_process : process (sw1)
  begin
    reset <= not sw1;
  end process reset_process;



  I2C_inst : I2C_slave
  generic map (
    SLAVE_ADDR => "0001111"
  )
  port map (
    scl => scl,
    sda => sda,
    clk => clk_100kHz,
    read_req => read_req,
    data_to_master => data_to_master,
    data_valid => data_valid,
    data_from_master => data_from_master,
    led_blue => led_blue,
    rst => reset
    );

  sda <= sda;
  scl <= scl;
  sdaFeedback <= scl;

  led_green <= data_received;
end architecture arch;
