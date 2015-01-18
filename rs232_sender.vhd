 --------------------------------------------------------
-- Sender component for comport
--   Trigger on by send_start pulse, otherwise stays
--   idle. Currently send 8-bit data at once. The data
--   must be available during the sending.
-- States
--   STATE_IDLE
--   send_start(pulse) -> STATE_START_BIT
--   STATE_SENDING
--   STATE_END_BIT
--   STATE_IDLE
-- Todo
--   1 add buffer for sender (maybe)
--------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity rs232_sender is
  port(
    clock_115200Hz, send_start: in std_logic;
    send_data: in std_logic_vector(7 downto 0);
    ack: out std_logic; -- a pulse notification
    output: out std_logic
  );
END rs232_sender;

architecture arch of rs232_sender is
  type state_type is (STATE_IDLE, STATE_START_BIT, STATE_SENDING, STATE_END_BIT);
  signal state: state_type;
  signal power_on: std_logic := '0';
  signal bit_count: integer;

begin
  process(clock_115200Hz)
  begin
    if(rising_edge(clock_115200Hz)) then
      if(power_on = '0') then -- init
        power_on <= '1';
        state <= STATE_IDLE;
      else -- non-init
        case state is
          when STATE_IDLE =>
            output <= '1';
            ack <= '0'; -- different!
            if(send_start = '1') then
              ack <= '0';
              state <= STATE_START_BIT;
            end if;
          when STATE_START_BIT =>
            bit_count <= 0;
            output <= '0';
            state <= STATE_SENDING;
          when STATE_SENDING => 
            output <= send_data(bit_count);
            bit_count <= bit_count + 1;
            if (bit_count >= 7) then
              state <= STATE_END_BIT;
            end if;
          when STATE_END_BIT =>
            output <= '1';
            ack <= '1';
            state <= STATE_IDLE;
        end case;
      end if; -- init / non-init
    end if; -- rising edge
  end process;
end arch;

