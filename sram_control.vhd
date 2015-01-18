-- rising_edge_detect.vhd
-- detect rising edge -> output a pulse

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity sram_control is
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
    -- in control to send to comport
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
end sram_control;

architecture a of sram_control is
  component rising_edge_detect is
    port (
      input, clock: in std_logic;
      edge_out: out std_logic
    );
  end component;
  component rs232_sender is
    port(
      clock_115200Hz, send_start: in std_logic;
      send_data: in std_logic_vector(7 downto 0);
      ack: out std_logic; -- a pulse notification
      output: out std_logic
    );
  end component;
  component sram_write is
    port (
      -- input --------------------
      pclk, href, vsync: in std_logic;
      module_enable: in std_logic;
      -- output -------------------
      ack: out std_logic;
      sram_addr: out std_logic_vector(17 downto 0)
    );  
  end component;
  
  -- state
  type state_type is (STATE_IDLE, STATE_WRITE, 
                      STATE_COMPORT_START_BYTE,
                      STATE_COMPORT_DATA,
                      STATE_COMPORT_END_BYTE);
  signal state: state_type;
  -- buffer for previous values
  type array_type is array (319 downto 0) of std_logic_vector(7 downto 0);
  signal prev_line_buffer: array_type := ((others=> (others=>'0')));
  -- signal prev_linear_buffer: std_logic_vector(2559 downto 0);
  signal left_buffer: std_logic_vector(7 downto 0);
  signal power_on: std_logic := '0';
  signal sram_addr_buffer: std_logic_vector(17 downto 0);
  signal pclk_prev: std_logic := '0';
  signal pixel_count: integer;
  -- write module
  signal write_module_enable: std_logic;
  signal sram_write_ack: std_logic;
  signal sram_addr_write_buffer: std_logic_vector(17 downto 0);
  signal sram_write_ack_pulse: std_logic;
  -- comport sender
  signal rs232_pulse: std_logic := '0'; -- pulse enable rs232
  signal rs232_pulse_count: integer;
  signal rs232_data: std_logic_vector(7 downto 0) := "00000000";
  signal rs232_ack: std_logic;
  signal rs232_ack_pulse: std_logic;
  signal clk_115200_pulse: std_logic;
  type comport_state_type is (STATE_IDLE, STATE_START_PULSE,
                              STATE_ACK, STATE_HOLD);
  signal comport_state: comport_state_type;
  signal rs232_sram_addr: std_logic_vector(17 downto 0);
  -- ack to main function
  signal ack_count: integer := 0;
  signal todo_ack: std_logic;

begin
  CEn <= '0';
  WEn <= pclk or (not href);
  UBn <= '1';
  LBn <= '0';
  
  process(clk_50MHz)
  begin
    if (rising_edge(clk_50MHz)) then
      if (power_on = '0') then
        power_on <= '1';
        state <= STATE_IDLE;
        --pixel_count <= 0;
        write_module_enable <= '0';
        ack_count <= 0;
        todo_ack <= '0';
      else
        case state is
          --------------------------------------------
          when STATE_IDLE =>
            if (todo_ack = '1') then
              ack <= '1';
              ack_count <= ack_count + 1;
            else
              ack <= '0';
            end if;
            if (ack_count > 10000) then
              todo_ack <= '0';
              ack_count <= 0;
            end if;
            led_debug <= '0';
            
            if (href = '0') then
              -- read calculated value to VGA
              -- vga_row, vga_col -> vga_r, vga_g, vga_b
              OEn <= '0';
              sram_data <= "ZZZZZZZZ";
              sram_addr <= std_logic_vector(to_unsigned(vga_row * 320 + vga_col, 18));
              if (vga_row >= 240 or vga_col >= 320) then
                -- out of range
                vga_r <= "0000000000";
                vga_g <= "0000000000";
                vga_b <= "0000000000";
              else
                -- give vga value
                if (vga_row = 0 or vga_row = 239 or 
                    vga_col = 0 or vga_col = 319) then
                  vga_r <= "0000000000";
                  vga_g <= "0000000000";
                  vga_b <= "0000000000";
                elsif (vga_row mod 2 = 0 and vga_col mod 2 = 0) then
                  vga_r <= prev_line_buffer(vga_col + 1) & "00";
                  vga_g <= prev_line_buffer(vga_col) & "00";
                  vga_b <= sram_data & "00";
                elsif (vga_row mod 2 = 0 and vga_col mod 2 = 1) then
                  vga_r <= prev_line_buffer(vga_col) & "00";
                  vga_g <= sram_data & "00";
                  vga_b <= left_buffer & "00";
                elsif (vga_row mod 2 = 1 and vga_col mod 2 = 0) then
                  vga_r <= left_buffer & "00";
                  vga_g <= sram_data & "00";
                  vga_b <= prev_line_buffer(vga_col) & "00";
                elsif (vga_row mod 2 = 1 and vga_col mod 2 = 1) then
                  vga_r <= sram_data & "00";
                  vga_g <= prev_line_buffer(vga_col) & "00";
                  vga_b <= prev_line_buffer(vga_col + 1) & "00";
                end if;
                prev_line_buffer(vga_col) <= sram_data;
                left_buffer <= sram_data;
              end if;
              
              if (to_pc_pulse_50MHz = '1') then
                state <= STATE_COMPORT_START_BYTE;
              end if;
            elsif (href = '1') then
              sram_data <= "ZZZZZZZZ";
              -- led_debug <= '1';
              OEn <= '1';
              sram_addr_buffer <= "000000000000000000";
              sram_addr <= "000000000000000000";
              write_module_enable <= '1';
              --pixel_count <= 0;
              state <= STATE_WRITE;
            end if;
          --------------------------------------------
          when STATE_WRITE =>
            vga_r <= "0000000000";
            vga_g <= "0000000000";
            vga_b <= "0000000000";
            ack <= '0';
            -- get from camera, write to sram
            led_debug <= '0';
            if (sram_write_ack_pulse = '1') then
              todo_ack <= '1';
              ack_count <= 0;
              write_module_enable <= '0';
              sram_data <= "ZZZZZZZZ";
              state <= STATE_IDLE;
              rs232_pulse_count <= 0;
            else
              sram_data <= img_data;
            end if;
            sram_addr <= sram_addr_write_buffer;
          --------------------------------------------
          when STATE_COMPORT_START_BYTE =>
            vga_r <= "0000000000";
            vga_g <= "0000000000";
            vga_b <= "0000000000";
            led_debug <= '1';
            ack <= '0';
            rs232_data <= "11110101";
            sram_data <= "ZZZZZZZZ";
            case comport_state is
              when STATE_IDLE =>
                rs232_pulse <= '0';
                rs232_pulse_count <= 0;
                if (clk_115200_pulse = '1') then
                  comport_state <= STATE_START_PULSE;
                end if;
              when STATE_START_PULSE =>
                rs232_pulse <= '1';
                rs232_pulse_count <= rs232_pulse_count + 1;
                if (rs232_pulse_count > 434) then
                  comport_state <= STATE_ACK;
                  rs232_pulse <= '0';
                end if;
              when STATE_ACK =>
                rs232_pulse <= '0';
                if (rs232_ack_pulse = '1') then
                  comport_state <= STATE_HOLD;
                  rs232_pulse_count <= 0;
                end if;
              when STATE_HOLD => 
                rs232_pulse <= '0';
                rs232_pulse_count <= rs232_pulse_count + 1;
                if (rs232_pulse_count > 1000) then
                  -- to next state
                  rs232_pulse_count <= 0;
                  comport_state <= STATE_IDLE;
                  state <= STATE_COMPORT_DATA;
                  rs232_sram_addr <= "000000000000000000";
                  OEn <= '1';
                end if;
            end case;
          --------------------------------------------
          when STATE_COMPORT_DATA =>
            vga_r <= "0000000000";
            vga_g <= "0000000000";
            vga_b <= "0000000000";
--            if (vga_row >= 240 or vga_col >= 320) then
--              -- out of range
--              vga_r <= "0000000000";
--              vga_g <= "0000000000";
--              vga_b <= "0000000000";
--            elsif (vga_row = 0 or vga_row = 239 or 
--              vga_col = 0 or vga_col = 319) then
--              vga_r <= "0000000000";
--              vga_g <= "0000000000";
--              vga_b <= "0000000000";
--            else
--              vga_r <= "1111111100";
--              vga_g <= "1111111100";
--              vga_b <= "1111111100";
--            end if;
            led_debug <= '1';
            OEn <= '0';
            sram_addr <= rs232_sram_addr;
            sram_data <= "ZZZZZZZZ";
            rs232_data <= sram_data;
            case comport_state is
              when STATE_IDLE =>
                rs232_pulse <= '0';
                rs232_pulse_count <= 0;
                if (clk_115200_pulse = '1') then
                  comport_state <= STATE_START_PULSE;
                end if;
              when STATE_START_PULSE =>
                rs232_pulse <= '1';
                rs232_pulse_count <= rs232_pulse_count + 1;
                if (rs232_pulse_count > 434) then
                  comport_state <= STATE_ACK;
                  rs232_pulse <= '0';
                end if;
              when STATE_ACK =>
                rs232_pulse <= '0';
                if (rs232_ack_pulse = '1') then
                  comport_state <= STATE_HOLD;
                  rs232_pulse_count <= 0;
                end if;
              when STATE_HOLD => 
                rs232_pulse <= '0';
                rs232_pulse_count <= rs232_pulse_count + 1;
                if (rs232_pulse_count > 1000) then
                  rs232_pulse_count <= 0;
                  comport_state <= STATE_IDLE; -- to next state
                  rs232_sram_addr <= rs232_sram_addr + 1; -- as addr buffer
                end if;
            end case;
            if (rs232_sram_addr >= 76800) then
              state <= STATE_COMPORT_END_BYTE;
              rs232_sram_addr <= "000000000000000000";
              sram_addr <= "000000000000000000";
            end if;
          when STATE_COMPORT_END_BYTE =>
            vga_r <= "0000000000";
            vga_g <= "0000000000";
            vga_b <= "0000000000";
--            if (vga_row >= 240 or vga_col >= 320) then
--              -- out of range
--              vga_r <= "0000000000";
--              vga_g <= "0000000000";
--              vga_b <= "0000000000";
--            elsif (vga_row = 0 or vga_row = 239 or 
--              vga_col = 0 or vga_col = 319) then
--              vga_r <= "0000000000";
--              vga_g <= "0000000000";
--              vga_b <= "0000000000";
--            else
--              vga_r <= "1111111100";
--              vga_g <= "1111111100";
--              vga_b <= "1111111100";
--            end if;
            led_debug <= '1';
            rs232_data <= "11111010";
            case comport_state is
              when STATE_IDLE =>
                rs232_pulse <= '0';
                rs232_pulse_count <= 0;
                if (clk_115200_pulse = '1') then
                  comport_state <= STATE_START_PULSE;
                end if;
              when STATE_START_PULSE =>
                rs232_pulse <= '1';
                rs232_pulse_count <= rs232_pulse_count + 1;
                if (rs232_pulse_count > 434) then
                  comport_state <= STATE_ACK;
                  rs232_pulse <= '0';
                end if;
              when STATE_ACK =>
                rs232_pulse <= '0';
                if (rs232_ack_pulse = '1') then
                  comport_state <= STATE_HOLD;
                  rs232_pulse_count <= 0;
                end if;
              when STATE_HOLD => 
                rs232_pulse <= '0';
                rs232_pulse_count <= rs232_pulse_count + 1;
                if (rs232_pulse_count > 1000) then
                  rs232_pulse_count <= 0;
                  comport_state <= STATE_IDLE; -- to next state
                  state <= STATE_IDLE;
                end if;
            end case;
        end case; -- SRAM state
      end if; -- (power_on = '0')
    else
    end if; -- rising_edge(clk_50MHz)
  end process;

  b0: sram_write port map (
    pclk => pclk,
    href => href,
    vsync => vsync,
    module_enable => write_module_enable,
    ack => sram_write_ack,
    sram_addr => sram_addr_write_buffer
  );
  b1: rising_edge_detect port map (
    input => sram_write_ack,
    clock => clk_50MHz,
    edge_out => sram_write_ack_pulse
  );
  b2: rising_edge_detect port map (
    input => rs232_ack,
    clock => clk_50MHz,
    edge_out => rs232_ack_pulse
  );
  b3: rising_edge_detect port map (
    input => clk_115200Hz,
    clock => clk_50MHz,
    edge_out => clk_115200_pulse
  );
  b4: rs232_sender port map (
    clock_115200Hz => clk_115200Hz,
    send_start => rs232_pulse,
    send_data => rs232_data,
    ack => rs232_ack,
    output => comport_out
  );
  
end a;





