-- rising_edge_detect.vhd
-- detect rising edge -> output a pulse

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity rising_edge_detect is
  port (
    input, clock: in std_logic;
    edge_out: out std_logic
  );
end rising_edge_detect;

architecture a of rising_edge_detect is
  signal power_on: std_logic := '0'; -- init to 0
  signal input_delay: std_logic;
begin
  process(clock)
  begin
    if (rising_edge(clock)) then
      if power_on = '0' then
        edge_out <= '0';
        input_delay <= '1';
        power_on <= '1';
      else
        if input = '1' and input_delay = '0' then
          edge_out <= '1';
        else
          edge_out <= '0';
        end if;
        input_delay <= input;
      end if;
    end if;
  end process;
end a;