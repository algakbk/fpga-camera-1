library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
-- calculate write address only, data in sram_control func.

entity sram_write is
  port (
    -- input --------------------
    pclk, href, vsync: in std_logic;
    module_enable: in std_logic;
    -- output -------------------
    ack: out std_logic;
    sram_addr: out std_logic_vector(17 downto 0)
  );
end sram_write;

architecture arch of sram_write is
  signal sram_addr_buffer: std_logic_vector(17 downto 0);

begin
  sram_addr <= sram_addr_buffer;
  process(pclk, href, vsync, module_enable)
  begin
    if (rising_edge(pclk)) then
      -- calculate new address
      if (module_enable = '0') then 
        sram_addr_buffer <= "000000000000000000";
      else
        if(href = '1') then
          sram_addr_buffer <= sram_addr_buffer + 1;
        end if;
      end if;
      -- finish writing
      -- if (sram_addr_buffer = "001000000111111111" or vsync = '1') then
      if (vsync = '1') then
        sram_addr_buffer <= "000000000000000000";
        ack <= '1';
      else
        ack <= '0';
      end if;
    end if;
  end process;
end arch;


