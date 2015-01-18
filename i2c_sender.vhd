library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity i2c_sender is
  port (
    send_start: in std_logic;
    clock_master: in std_logic; -- clk_500KHz
    slave_id: in std_logic_vector(6 downto 0);
    rw: in std_logic;
    sub_address: in std_logic_vector(7 downto 0);
    data: in std_logic_vector(7 downto 0);
    ack: out std_logic := '0';
    scl: out std_logic := '1';
    sda: out std_logic := '1'
  );
end i2c_sender;

architecture arch of i2c_sender is
  type state_type is (STATE_IDLE, STATE_SENDING);
  signal state: state_type;
  signal power_on: std_logic := '0';
  signal master_count: integer;
begin
  process(clock_master)
  begin
    if (rising_edge(clock_master)) then
      if (power_on = '0') then
        -- init
        power_on <= '1';
        state <= STATE_IDLE;
        scl <= '1';
        sda <= '1';
      else
        case state is
          when STATE_IDLE =>
            scl <= '1';
            sda <= '1';
            if (send_start = '1') then
              state <= STATE_SENDING;
              master_count <= 0;
            end if;
          when STATE_SENDING =>
            -- scl
            if (master_count /= 0 and master_count mod 4 = 0) then
              scl <= '1';
            elsif (master_count mod 4 = 2) then
              scl <= '0';
            end if;
            if (master_count > 117) then
              scl <= '1';
            end if;
            -- sda
            case master_count is
              -- start bit
              when 1 =>
                ack <= '0';
                sda <= '0';
              -- first byte
              when 3 =>
                sda <= slave_id(6);
              when 7 =>
                sda <= slave_id(5);
              when 11 =>
                sda <= slave_id(4);
              when 15 =>
                sda <= slave_id(3);
              when 19 =>
                sda <= slave_id(2);
              when 23 =>
                sda <= slave_id(1);
              when 27 =>
                sda <= slave_id(0);
              when 31 =>
                sda <= rw;
              when 35 =>
                sda <= 'X';
              -- second byte   
              when 39 =>
                sda <= sub_address(7);
              when 43 =>
                sda <= sub_address(6);
              when 47 =>
                sda <= sub_address(5);
              when 51 =>
                sda <= sub_address(4);
              when 55 =>
                sda <= sub_address(3);
              when 59 =>
                sda <= sub_address(2);
              when 63 =>
                sda <= sub_address(1);
              when 67 =>
                sda <= sub_address(0);
              when 71 =>
                sda <= 'X';
              -- third byte   
              when 75 =>
                sda <= data(7);
              when 79 =>
                sda <= data(6);
              when 83 =>
                sda <= data(5);
              when 87 =>
                sda <= data(4);
              when 91 =>
                sda <= data(3);
              when 95 =>
                sda <= data(2);
              when 99 =>
                sda <= data(1);
              when 103 =>
                sda <= data(0);
              when 107 => 
                sda <= 'X';
              -- end bit
              when 111 => 
                sda <= '0';
              when 123 => 
                sda <= '1';
              -- ack
              -- when 118 =>
              when 258 =>
                ack <= '1';
              -- when 119 =>
              when 259 =>
                ack <= '0';
                state <= STATE_IDLE;
              when others =>
                ack <= '0';
                -- do nothing
            end case; -- master_count
            master_count <= master_count + 1;
        end case; -- state
      end if; -- (power_on = '0')
    end if; --  rising_edge(clock_master)
  end process; -- (clock_master)
end arch;


