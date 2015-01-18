------------------------------------------------------------
-- Receiver (with buffer) component for comport-
--   1) Stays idle until start bit occurs. Then eceive 8-bit 
--   one by one. At stop bit, store the 8 bits in buffer,
--   send notification to the other system. The contents
--   in the buffer remains unchnaged until the next stop 
--   bit
--   2) Sync clock at every start bit
-- States
--   STATE_IDLE
--   STATE_RECEIVING
--   STATE_END_BIT
--   STATE_IDLE
------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity rs232_receiver is
  port(
    clock_50MHz: in std_logic;
    input: in std_logic; -- connected to comport input pin
    receive_data: out std_logic_vector(7 downto 0);
    ack: out std_logic -- a pulse notification
  );
end rs232_receiver;

architecture arch of rs232_receiver is
  type state_type is (STATE_IDLE, 
                      STATE_RECEIVING, STATE_END_BIT,
                      STATE_ACKING);
  signal state: state_type;
  signal power_on: std_logic := '0';
  signal bit_count: integer;
  signal cycle_count: integer;
  signal ack_count: integer;

begin
  process(clock_50MHz, input)
  begin
    if(rising_edge(clock_50MHz)) then
      if(power_on = '0') then -- init
        power_on <= '1';
        ack <= '0';
        state <= STATE_IDLE;
        receive_data <= "00000000";
        ack_count <= 0;
      else -- non-init
        case state is
          when STATE_IDLE =>
            ack <= '0';
            ack_count <= 0;
            if(input = '0') then
              state <= STATE_RECEIVING;
              bit_count <= 0;
              cycle_count <= 0;
            end if;
          when STATE_RECEIVING =>
            cycle_count <= cycle_count + 1;
            ack <= '0';
            if(cycle_count=651 or cycle_count=1085 or cycle_count=1519
               or cycle_count=1953 or cycle_count=2387 or cycle_count=2821 
               or cycle_count=3255 or cycle_count=3689) then
              receive_data(bit_count) <= input;
              bit_count <= bit_count + 1;
            elsif (cycle_count > 3689) then
              state <= STATE_END_BIT;
            end if;
          when STATE_END_BIT =>
            cycle_count <= cycle_count + 1;
            if (cycle_count > 4123 and input = '1') then
              state <= STATE_ACKING;
            end if;
          when STATE_ACKING =>
            ack <= '1';
            ack_count <= ack_count + 1;
            if (ack_count > 500) then
              state <= STATE_IDLE;
            end if;
        end case;
      end if; -- init / non-init
    end if; -- rising edge
  end process;
end arch;
