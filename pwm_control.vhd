library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
-- generates pwm signal for motor
 
entity pwm_control is
  generic(
    -- clock 500KHz, 0.8ms-2.3ms for 0-180 degrees
    --low_bound: integer := 400;
    --high_bound: integer := 1300;
    low_bound: integer := 300;
    high_bound: integer := 1100;
    cycle_length: integer := 10000;
    max_step: integer := 20
  );
  port (
    clock: in std_logic; -- 500KHz
    v_step: in integer; -- 0 to max_step
    h_step: in integer; -- 0 to max_step
    v_signal: out std_logic;
    h_signal: out std_logic
  );
end pwm_control;

architecture a of pwm_control is
  signal clk_500KHz: std_logic;
  signal v_cam_pulse, h_cam_pulse: std_logic;
  signal v_high_length: integer := 0;
  signal h_high_length: integer := 0;
  signal clock_count: integer := 0;
begin
  process(clock)
  begin
    if (rising_edge(clock)) then
      -- calculate high length
      v_high_length <= ((high_bound - low_bound) * v_step / max_step) 
                       + low_bound;
      h_high_length <= ((high_bound - low_bound) * h_step / max_step) 
                       + low_bound;
      -- calc v_signal
      if (clock_count < v_high_length) then
        v_signal <= '1';
      else
        v_signal <= '0';
      end if;
      -- calc h_signal
      if (clock_count < h_high_length) then
        h_signal <= '1';
      else
        h_signal <= '0';
      end if;
      -- update clock_count
      if (clock_count = cycle_length) then
        clock_count <= 0;
      else
        clock_count <= clock_count + 1;
      end if;
    end if; -- (rising_edge(clock))
  end process;
end a;

