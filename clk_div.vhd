library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity clk_div is
  port (
    clock_50MHz: in std_logic;
    clock_25MHz: out std_logic;
    clock_1MHz: out std_logic;
    clock_500KHz: out std_logic;
    clock_115200Hz: out std_logic
  );
end clk_div;

architecture b of clk_div is
  -- clock 25
  signal clock_25MHz_int: std_logic := '0';
  -- others
  signal count_1MHz: std_logic_vector(4 downto 0);
  signal clock_1MHz_int: std_logic := '0';
  signal count_500KHz: std_logic_vector(5 downto 0);
  signal clock_500KHz_int: std_logic := '0';
  signal count_115200Hz: std_logic_vector(7 downto 0); 
  signal clock_115200Hz_int: std_logic;

begin
  -- 25MHz, devide by 2
  process
    begin
      wait until clock_50MHz'event and clock_50MHz = '1';
        clock_25MHz <= clock_25MHz_int;
        clock_25MHz_int <= not clock_25MHz_int;
  end process;
  
  -- 1MHz, devide by 50
  process
  begin
    wait until clock_50MHz'event and clock_50MHz = '1';
      if count_1MHz /= 25 then
        count_1MHz <= count_1MHz + 1;
      else
        count_1MHz <= "00000";
        clock_1MHz_int <= not clock_1MHz_int;
      end if;
      clock_1MHz <= clock_1MHz_int;
  end process;
  
  -- 500KHz, devide by 100
  process
  begin
    wait until clock_50MHz'event and clock_50MHz = '1';
      if count_500KHz /= 50 then
        count_500KHz <= count_500KHz + 1;
      else
        count_500KHz <= "000000";
        clock_500KHz_int <= not clock_500KHz_int;
      end if;
      clock_500KHz <= clock_500KHz_int;
  end process;
  
  -- 115200Hz, divide by 434
  process 
  begin  
    wait until clock_50MHz'event and clock_50MHz = '1';
      if count_115200Hz /= 216 then
        count_115200Hz <= count_115200Hz + 1;
      else
        count_115200Hz <= "00000000";
        clock_115200Hz_int <= not clock_115200Hz_int;
      end if;
      clock_115200Hz <= clock_115200Hz_int;
  end process;

end b;


