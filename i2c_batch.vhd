library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
-- send 8 groups of init i2c signals

entity i2c_batch is
  port (
    -- in
    clk_500KHz: in std_logic;
    send_start: in std_logic;
    batch_mode: in std_logic; -- '1' for batch, '0' for capture
    -- out
    ack: out std_logic := '0'; -- ack to main function
    i2c_scl: out std_logic := '1'; -- map to main i2c_scl
    i2c_sda: out std_logic := '1' -- map top main i2c_sda
  );
end i2c_batch;

architecture arch of i2c_batch is
  -- components
  component i2c_sender is
    port (
      send_start: in std_logic;
      clock_master: in std_logic; -- 1MHz
      slave_id: in std_logic_vector(6 downto 0);
      rw: in std_logic;
      sub_address: in std_logic_vector(7 downto 0);
      data: in std_logic_vector(7 downto 0);
      ack: out std_logic;
      scl: out std_logic := '1';
      sda: out std_logic := '1'
    );
  end component;
  -- signals
  signal power_on: std_logic := '0';
  type state_type is (STATE_IDLE, STATE_CAPTURE,
                      STATE_INIT_0, STATE_INIT_1, 
                      STATE_INIT_2, STATE_INIT_3, STATE_INIT_4,
                      STATE_INIT_5, STATE_INIT_6, STATE_INIT_7);
  signal first_byte: std_logic_vector(7 downto 0) := "11000000";
  signal second_byte, third_byte: std_logic_vector(7 downto 0);
  signal state: state_type;
  signal i2c_pulse: std_logic := '0';
  signal i2c_pulse_sent: std_logic := '0';
  signal i2c_ack: std_logic;
  
  -- processes
begin
  process(clk_500KHz)
  begin
    if (rising_edge(clk_500KHz)) then
      if (power_on = '0') then
        power_on <= '1';
        state <= STATE_IDLE;
        ack <= '0';
      else
        case state is
          when STATE_IDLE =>
            ack <= '0';
            if (send_start = '1') then
              i2c_pulse <= '0';
              i2c_pulse_sent <= '0';
              if (batch_mode = '1') then
                state <= STATE_INIT_0;
              else
                state <= STATE_CAPTURE;
              end if;
            end if;
          
          -- signal mode ---------------------
          when STATE_CAPTURE =>
            -- send capture signal
            second_byte <= "00010011";
            third_byte  <= "00000011";
            if (i2c_pulse_sent = '0') then
              i2c_pulse <= '1';
              i2c_pulse_sent <= '1';
            else
              i2c_pulse <= '0';
            end if;
            if (i2c_ack = '1') then
              i2c_pulse_sent <= '0';
              state <= STATE_IDLE;
              ack <= '1';
            end if;
          
          -- batch mode ---------------------  
          when STATE_INIT_0 =>
            second_byte <= "00010001";
            third_byte  <= "00000000";
            if (i2c_pulse_sent = '0') then
              i2c_pulse <= '1';
              i2c_pulse_sent <= '1';
            else
              i2c_pulse <= '0';
            end if;
            if (i2c_ack = '1') then
              -- power_on <= '1';
              i2c_pulse_sent <= '0';
              state <= STATE_INIT_1;
            end if;
          when STATE_INIT_1 =>
            second_byte <= "00010110";
            third_byte  <= "00000000";
            if (i2c_pulse_sent = '0') then
              i2c_pulse <= '1';
              i2c_pulse_sent <= '1';
            else
              i2c_pulse <= '0';
            end if;
            if (i2c_ack = '1') then
              i2c_pulse_sent <= '0';
              state <= STATE_INIT_2;
            end if;
          when STATE_INIT_2 =>
            second_byte <= "00010010";
            third_byte  <= "00101000";
            if (i2c_pulse_sent = '0') then
              i2c_pulse <= '1';
              i2c_pulse_sent <= '1';
            else
              i2c_pulse <= '0';
            end if;
            if (i2c_ack = '1') then
              i2c_pulse_sent <= '0';
              state <= STATE_INIT_3;
            end if;
          when STATE_INIT_3 =>
            second_byte <= "00101000";
            third_byte  <= "10000001";
            if (i2c_pulse_sent = '0') then
              i2c_pulse <= '1';
              i2c_pulse_sent <= '1';
            else
              i2c_pulse <= '0';
            end if;
            if (i2c_ack = '1') then
              i2c_pulse_sent <= '0';
              state <= STATE_INIT_4;
            end if;
          when STATE_INIT_4 =>
            second_byte <= "00010111";
            third_byte  <= "01000001";
            if (i2c_pulse_sent = '0') then
              i2c_pulse <= '1';
              i2c_pulse_sent <= '1';
            else
              i2c_pulse <= '0';
            end if;
            if (i2c_ack = '1') then
              i2c_pulse_sent <= '0';
              state <= STATE_INIT_5;
            end if;
          when STATE_INIT_5 =>
            second_byte <= "00011000";
            third_byte  <= "11100011";
            if (i2c_pulse_sent = '0') then
              i2c_pulse <= '1';
              i2c_pulse_sent <= '1';
            else
              i2c_pulse <= '0';
            end if;
            if (i2c_ack = '1') then
              i2c_pulse_sent <= '0';
              state <= STATE_INIT_6;
            end if;
          when STATE_INIT_6 =>
            second_byte <= "00011001";
            third_byte  <= "00010000";
            if (i2c_pulse_sent = '0') then
              i2c_pulse <= '1';
              i2c_pulse_sent <= '1';
            else
              i2c_pulse <= '0';
            end if;
            if (i2c_ack = '1') then
              i2c_pulse_sent <= '0';
              state <= STATE_INIT_7;
            end if;
          when STATE_INIT_7 =>
            second_byte <= "00011010";
            third_byte  <= "10000111";
            if (i2c_pulse_sent = '0') then
              i2c_pulse <= '1';
              i2c_pulse_sent <= '1';
            else
              i2c_pulse <= '0';
            end if;
            if (i2c_ack = '1') then
              i2c_pulse_sent <= '0';
              state <= STATE_INIT_0;
              state <= STATE_IDLE;
              ack <= '1';
            end if;
        end case;
      end if;
    end if;
  end process;
  
  -- port maps
  b0: i2c_sender port map(
    send_start => i2c_pulse,
    clock_master => clk_500KHz,
    slave_id => first_byte (7 downto 1),
    rw => first_byte(0),
    sub_address => second_byte,
    data => third_byte,
    ack => i2c_ack,
    scl => i2c_scl,
    sda => i2c_sda
  );
  
end arch;