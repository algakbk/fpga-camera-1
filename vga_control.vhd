-- vga_control.vhd
-- given pixel clock, calculate sync signals and location index
-- input: pixel clock
-- output: sync signals, pixel locations(row, col)

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.all;
use IEEE.std_logic_UNSIGNED.all;

entity vga_control is
  generic (
    -- constants
		h_pixels:	integer := 640;
		h_fp	 	:	integer := 16;
		h_pulse :	integer := 96;
		h_bp	 	:	integer := 48;
		v_pixels:	integer := 480;
		v_fp	 	:	integer := 11;
		v_pulse :	integer := 2;
		v_bp	 	:	integer := 33
  );
  port (
    pixel_clock: in std_logic;
    h_sync, v_sync: out std_logic;
    n_blank, n_sync: out std_logic;
    row, col: out integer
  );
end vga_control;

architecture arch of vga_control is
  constant  h_period:  integer := h_pulse + h_bp + h_pixels + h_fp;
  constant  v_period:  integer := v_pulse + v_bp + v_pixels + v_fp;
  signal power_on: std_logic := '0';

begin
  n_blank <= '1';
  n_sync <= '0';
  process(pixel_clock)
    variable h_count: integer range 0 to h_period - 1 := 0;
    variable v_count: integer range 0 to v_period - 1 := 0;
  begin
    if(power_on = '0') then
      h_count := 0;
      v_count := 0;
      h_sync <= '1';
      v_sync <= '1';
      col <= 0;
      row <= 0;
      power_on <= '1';
    elsif(pixel_clock'event and pixel_clock = '1') then
      -- counters
      if(h_count < h_period - 1) then
        h_count := h_count + 1;
      else
        h_count := 0;
        if(v_count < v_period - 1) then
          v_count := v_count + 1;
        else
          v_count := 0;
        end if;
      end if;
      -- horizontal sync signal
      if(h_count < h_pixels + h_fp or h_count > h_pixels + h_fp + h_pulse) then
        h_sync <= '1';
      else
        h_sync <= '0';
      end if;
      -- vertical sync signal
      if(v_count < v_pixels + v_fp or v_count > v_pixels + v_fp + v_pulse) then
        v_sync <= '1';
      else
        v_sync <= '0';
      end if;
      -- set pixel coordinates
      if(h_count < h_pixels) then
        col <= h_count;
      end if;
      if(v_count < v_pixels) then
        row <= v_count;
      end if;
    end if;
  end process;

end arch;

