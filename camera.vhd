library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
--use ieee.numeric_std.all;

entity camera is
  generic(
    -- motor
    max_step: integer := 20 -- max_step for motor
  );
  port (
    -- in ------------------------------
    -- clock
    clk_50MHz: in std_logic; -- PIN_N2
    -- capture key
    reset_cam: in std_logic; -- PIN_G26, key 0
    capture_cam: in std_logic;
    -- motor key
    v_cam: in std_logic; -- vertical motor
    h_cam: in std_logic; -- horizontal motor
    v_switch_cam: in std_logic; 
    h_switch_cam: in std_logic;
    -- camera
    href, vsync, pclk: in std_logic := '0';
    img_data: in std_logic_vector (7 downto 0);
    -- comport
    comport_in: in std_logic;
    
    -- out ------------------------------
    -- comport
    comport_out: out std_logic;
    -- i2c
    i2c_sda: out std_logic; -- i2c data
    i2c_scl: out std_logic; -- i2c clock < 400KHz
    -- motor
    motor_v_signal: out std_logic;
    motor_h_signal: out std_logic;
    -- vga
    vga_r: out std_logic_vector(9 downto 0);
    vga_g: out std_logic_vector(9 downto 0);
    vga_b: out std_logic_vector(9 downto 0);
    vga_clock: out std_logic;
    vga_hs: out std_logic;
    vga_vs: out std_logic;
    vga_blank: out std_logic;
    vga_sync: out std_logic;
    -- sram
    CEn, OEn, WEn, UBn, LBn: out std_logic;
    sram_data: inout std_logic_vector(7 downto 0);
    sram_addr: out std_logic_vector(17 downto 0);
    -- debug
    led: out std_logic := '0'; -- main function
    led_r1: out std_logic := '0'; -- sram write
    led_r2: out std_logic := '0'
  );
end camera;

architecture a of camera is
  -- components
  component clk_div is 
    port (
      clock_50MHz: in std_logic;
      clock_25MHz: out std_logic;
      clock_1MHz: out std_logic;
      clock_500KHz: out std_logic;
      clock_115200Hz: out std_logic
    );
  end component;
  component i2c_batch is
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
  end component;
  component rs232_receiver is
    port(
      clock_50MHz: in std_logic;
      input: in std_logic; -- connected to comport input pin
      receive_data: out std_logic_vector(7 downto 0);
      ack: out std_logic -- a pulse notification
    );
  end component;
  component pwm_control is
    port (
      clock: in std_logic; -- 500KHz
      v_step: in integer; -- 0 to 36
      h_step: in integer; -- 0 to 36
      v_signal: out std_logic;
      h_signal: out std_logic
    );
  end component;
  component vga_control is
    port (
      pixel_clock: in std_logic;
      h_sync, v_sync: out std_logic;
      n_blank, n_sync: out std_logic;
      row, col: out integer
    );
  end component;
  component sram_control is
    port (
      -- input --------------------
      -- in clock
      clk_115200Hz: in std_logic;
      clk_50MHz: in std_logic; -- PIN_N2
      -- in from CAM
      href, vsync, pclk: in std_logic := '0';
      img_data: in std_logic_vector (7 downto 0);
      -- in from VGA
      vga_row, vga_col: in integer;
      -- in from COMPORT
      rs232_addr: in std_logic_vector (17 downto 0) := "000000000000000000";
      -- control to send to comport
      to_pc_pulse_50MHz: in std_logic;
      
      -- output -------------------
      ack: out std_logic;
      -- out to SRAM
      CEn, OEn, WEn, UBn, LBn: out std_logic;
      sram_data: inout std_logic_vector(7 downto 0);
      sram_addr: out std_logic_vector(17 downto 0);
      -- out to VGA
      vga_r: out std_logic_vector(9 downto 0);
      vga_g: out std_logic_vector(9 downto 0);
      vga_b: out std_logic_vector(9 downto 0);
      -- out to COMPORT
      comport_out: out std_logic;
      -- debug
      led_debug: out std_logic
    );
  end component;
  component rising_edge_detect is
    port (
      input, clock: in std_logic;
      edge_out: out std_logic
    );
  end component;
    
  -- signal ------------------------------
  -- main states
  type state_type is (STATE_INITING, STATE_IDLE, STATE_TO_PC,
                      STATE_CAPTURE_INIT, STATE_CAPUTRE, 
                      STATE_COMPORT_SEND, STATE_MOTOR);
  signal state: state_type;
  type state_init_type is (STATE_INIT_0, STATE_INIT_1, STATE_INIT_2, 
                           STATE_INIT_3, STATE_INIT_4, STATE_INIT_5, 
                           STATE_INIT_6, STATE_INIT_7);
  signal state_init: state_init_type;
  signal power_on: std_logic := '0'; -- the main power on
  -- control buttons
  signal reset_cam_pulse, capture_cam_pulse, v_cam_pulse, h_cam_pulse: std_logic;
  -- i2c_batch
  signal i2c_batch_pulse: std_logic;
  signal i2c_batch_pulse_sent: std_logic;
  signal i2c_batch_ack: std_logic;
  signal i2c_batch_ack_pulse: std_logic;
  signal batch_mode: std_logic;
  -- sram
  signal sram_ack: std_logic;
  signal sram_ack_pulse: std_logic;
  signal to_pc_pulse: std_logic;
  signal to_pc_pulse_50MHz: std_logic;
  signal to_pc_pulse_sent: std_logic;
  -- motor control
  signal motor_v_step: integer := max_step / 2;
  signal motor_h_step: integer := max_step / 2;
  -- vga
  signal vga_row: integer := 0;
  signal vga_col: integer := 0;
  -- command from comport
  signal comport_command: std_logic_vector(7 downto 0);
  signal receiver_ack: std_logic; -- 50MHz
  signal receiver_ack_pulse: std_logic; -- 500KHz
  -- clocks
  signal clk_500KHz: std_logic;
  signal clk_25MHz: std_logic;
  signal clk_115200Hz: std_logic;

-- process
begin
  process(clk_25MHz)
  begin
    vga_clock <= clk_25MHz;
  end process;
  
  process(clk_500KHz, reset_cam_pulse)
  begin
    if (rising_edge(clk_500KHz)) then -- necessary
      if (power_on = '0') then
        power_on <= '1';
        state <= STATE_INITING;
      else -- (power_on = '0')
        if (reset_cam_pulse = '1') then
          led_r2 <= '0';
          i2c_batch_pulse <= '0';
          i2c_batch_pulse_sent <= '0';
          state <= STATE_INITING;
        end if;
        
        -- STATE_INITING ------------------------------
        if (state = STATE_INITING) then
          motor_v_step <= max_step / 2;
          motor_h_step <= max_step / 2;
          batch_mode <= '1';
          if (i2c_batch_pulse_sent = '0') then
            i2c_batch_pulse <= '1';
            i2c_batch_pulse_sent <= '1';
          else
            i2c_batch_pulse <= '0';
          end if;
          if (i2c_batch_ack = '1') then
            i2c_batch_pulse_sent <= '0';
            state <= STATE_IDLE;
          end if;
          
        -- STATE_IDLE ------------------------------
        elsif (state = STATE_IDLE) then
          led <= '0';
          led_r2 <= '0';
          batch_mode <= '0';
          if (capture_cam_pulse = '1') then
            state <= STATE_CAPTURE_INIT;
          elsif (v_cam_pulse = '1') then
            if (h_switch_cam = '1') then
              -- right
              if (motor_h_step > 0) then
                motor_h_step <= motor_h_step - 1;
              end if;
            end if;
            if (v_switch_cam = '1') then
              -- down
              if (motor_v_step > 0) then
                motor_v_step <= motor_v_step - 1;
              end if;
            end if;
          elsif (h_cam_pulse = '1') then
            if (h_switch_cam = '1') then
              -- left
              if (motor_h_step < max_step) then
                motor_h_step <= motor_h_step + 1;
              end if;
            end if;
            if (v_switch_cam = '1') then
              -- up
              if (motor_v_step < max_step) then
                motor_v_step <= motor_v_step + 1;
              end if;
            end if;
          elsif (receiver_ack_pulse = '1') then
            led_r2 <= '1';
            if (comport_command = "10101010") then
              -- init
              state <= STATE_CAPTURE_INIT;
            elsif (comport_command = "10100101") then
              -- retreve
              to_pc_pulse <= '0';
              to_pc_pulse_sent <= '0';
              state <= STATE_TO_PC;
            elsif (comport_command = "01010101") then
              -- reset
              state <= STATE_INITING;
            elsif (comport_command = "00010000") then
              -- up
              if (motor_v_step < max_step) then
                motor_v_step <= motor_v_step + 1;
              end if;
            elsif (comport_command = "00010001") then
              -- down
              if (motor_v_step > 0) then
                motor_v_step <= motor_v_step - 1;
              end if;
            elsif (comport_command = "00010010") then
              -- left
              if (motor_h_step < max_step) then
                motor_h_step <= motor_h_step + 1;
              end if;
            elsif (comport_command = "00010011") then
              -- right
              if (motor_h_step > 0) then
                motor_h_step <= motor_h_step - 1;
              end if;
            elsif (comport_command(7 downto 5) = "011") then
              -- vertical numeric
              motor_v_step <= conv_integer(comport_command(4 downto 0));
              if (motor_v_step < 0) then
                motor_v_step <= 0;
              end if;
              if (motor_v_step > max_step) then
                motor_v_step <= max_step;
              end if;
            elsif (comport_command(7 downto 5) = "001") then
              -- horizontal numeric
              motor_h_step <= conv_integer(comport_command(4 downto 0));
              if (motor_h_step < 0) then
                motor_h_step <= 0;
              end if;
              if (motor_h_step > max_step) then
                motor_h_step <= max_step;
              end if;
            end if;
          end if;
        
        -- STATE_CAPTURE_INIT ------------------------
        elsif (state = STATE_CAPTURE_INIT) then
          led <= '1';
          batch_mode <= '0';
          if (i2c_batch_pulse_sent = '0') then
            i2c_batch_pulse <= '1';
            i2c_batch_pulse_sent <= '1';
          else
            i2c_batch_pulse <= '0';
          end if;
          if (i2c_batch_ack = '1') then
            i2c_batch_pulse_sent <= '0';
            state <= STATE_IDLE;
          end if;
          
        -- STATE_CAPTURE ------------------------------
        elsif (state = STATE_CAPUTRE) then
          if (sram_ack_pulse = '1') then
            state <= STATE_IDLE;
          end if;
       
        -- STATE_TO_PC ---------------------------------
        elsif (state = STATE_TO_PC) then
          if (to_pc_pulse_sent = '0') then
            to_pc_pulse <= '1';
            to_pc_pulse_sent <= '1';
          else
            to_pc_pulse <= '0';
            to_pc_pulse_sent <= '0';
            state <= STATE_IDLE;
          end if;

        -- STATE_COMPORT_SEND -------------------------
        elsif (state = STATE_COMPORT_SEND) then
          
        end if; -- if state
      end if; -- (power_on = '0')
    end if; -- (rising_edge(clk_500KHz))

  end process;
  
  -- port maps -------------------------
  -- clock divider
  b_0: clk_div port map (
    clock_50MHz => clk_50MHz,
    clock_500KHz => clk_500KHz,
    clock_25MHz => clk_25MHz,
    clock_115200Hz => clk_115200Hz
  );
  -- rising edge detecters (buttons)
  b_r0: rising_edge_detect port map (
    input => reset_cam,
    clock => clk_500KHz,
    edge_out => reset_cam_pulse
  );
  b_r1: rising_edge_detect port map (
    input => capture_cam,
    clock => clk_500KHz,
    edge_out => capture_cam_pulse
  );
  b_r2: rising_edge_detect port map (
    input => v_cam,
    clock => clk_500KHz,
    edge_out => v_cam_pulse
  );
  b_r3: rising_edge_detect port map (
    input => h_cam,
    clock => clk_500KHz,
    edge_out => h_cam_pulse
  );
  -- rising edge detecters (component)
  b_r4: rising_edge_detect port map (
    input => sram_ack,
    clock => clk_500KHz,
    edge_out => sram_ack_pulse
  );
  b_r5: rising_edge_detect port map (
    input => receiver_ack,
    clock => clk_500KHz,
    edge_out => receiver_ack_pulse
  );
  b_r6: rising_edge_detect port map (
    input => to_pc_pulse,
    clock => clk_50MHz,
    edge_out => to_pc_pulse_50MHz
  );
  -- connection to components
  b_c0: i2c_batch port map (
    -- in
    clk_500KHz => clk_500KHz,
    send_start => i2c_batch_pulse,
    batch_mode => batch_mode,
    ack => i2c_batch_ack,
    i2c_scl => i2c_scl,
    i2c_sda => i2c_sda
  );
  b_c1: pwm_control port map (
    clock => clk_500KHz,
    v_step => motor_v_step,
    h_step => motor_h_step,
    v_signal => motor_v_signal,
    h_signal => motor_h_signal
  );
  b_c2: vga_control port map (
    pixel_clock => clk_25MHz,
    h_sync => vga_hs,
    v_sync => vga_vs,
    n_blank => vga_blank,
    n_sync => vga_sync,
    col => vga_col,
    row => vga_row
  );
  b_c3: sram_control port map (
    -- in
    clk_115200Hz => clk_115200Hz,
    clk_50MHz => clk_50MHz,
    vga_row => vga_row,
    vga_col => vga_col,
    href => href,
    vsync => vsync, 
    pclk => pclk,
    img_data => img_data,
    to_pc_pulse_50MHz => to_pc_pulse_50MHz,
    -- out
    CEn => CEn,
    OEn => OEn,
    WEn => WEn, 
    UBn => UBn, 
    LBn => LBn,
    sram_data => sram_data,
    sram_addr => sram_addr,
    vga_r => vga_r,
    vga_g => vga_g,
    vga_b => vga_b,
    comport_out => comport_out,
    led_debug => led_r1,
    ack => sram_ack
  );
  b_c4: rs232_receiver port map (
    clock_50MHz => clk_50MHz,
    input => comport_in,
    receive_data => comport_command,
    ack => receiver_ack
  );
end a;










