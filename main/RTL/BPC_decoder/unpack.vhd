library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity unpacker is
generic(
  DATA_W    : positive := 8;
  LOG_DATA_W: positive := 3
);
port (
  clk_i        : in  std_logic;
  rst_ni       : in  std_logic;
  -- Input compressed byte stream
  data_i       : in  std_logic_vector(DATA_W-1 downto 0);
  vld_i        : in  std_logic;
  rdy_o        : out std_logic;
   -- Output symbol stream toward decoder
  data_o       : out std_logic_vector(DATA_W-1 downto 0);
  fill_state_o : out std_logic_vector(LOG_DATA_W downto 0);
  -- Number of bits consumed by decoder
  len_i        : in  unsigned(LOG_DATA_W downto 0);
  -- Output handshake
  vld_o        : out std_logic;
  rdy_i        : in  std_logic;
  -- Flush/clear unpacker
  clr_i        : in  std_logic
);
end entity unpacker;

architecture rtl of unpacker is
  type state_t is (idle, pre_fill, running);
  -- 4x wide buffer: holds up to 32 bits
  constant BUF_W     : positive := 4 * DATA_W;   
  constant RDY_THRESH: positive := 3 * DATA_W;   
   -- Internal Registers
  signal stream_reg_d, stream_reg_q : unsigned(BUF_W-1 downto 0);
  signal fill_d,       fill_q       : unsigned(LOG_DATA_W+2 downto 0); -- 6 bits: 0..32
  signal state_d,      state_q      : state_t;

begin
  -- Always output top DATA_W bits
  data_o <= std_logic_vector(stream_reg_q(BUF_W-1 downto BUF_W-DATA_W));

  -- Cap fill_state_o at DATA_W (port width unchanged)
  fill_state_o <= std_logic_vector(to_unsigned(DATA_W, LOG_DATA_W+1))
                  when fill_q >= to_unsigned(DATA_W, fill_q'length)
                  else std_logic_vector(fill_q(LOG_DATA_W downto 0));
  ---------------------------------------------------------------------------
  -- Combinational logic
  ---------------------------------------------------------------------------
  comb_proc : process(all)
    variable next_stream_buffer : unsigned(BUF_W-1 downto 0);
    variable next_fill_level : unsigned(LOG_DATA_W+2 downto 0);
    variable s : integer range 0 to BUF_W;
  begin
    next_stream_buffer := stream_reg_q;
    next_fill_level := fill_q;
    consume_length  := to_integer(len_i);

    rdy_o   <= '0';
    vld_o   <= '0';
    state_d <= state_q;

    if clr_i = '1' then
      next_stream_buffer       := (others => '0');
      next_fill_level          := (others => '0');
      state_d <= idle;

    else
      case state_q is
        -- ------------------------------------------------------------
        -- IDLE: wait for first byte
        -- ------------------------------------------------------------
        when idle =>
          rdy_o <= '1';
          if vld_i = '1' then
            next_stream_buffer       := unsigned(data_i) & to_unsigned(0, 3*DATA_W);
            next_fill_level          := to_unsigned(DATA_W, f'length);
            state_d <= pre_fill;
          end if;
        -- ------------------------------------------------------------
        -- PRE_FILL: wait for second byte before asserting vld_o
        -- ------------------------------------------------------------
        when pre_fill =>
          rdy_o <= '1';
          if vld_i = '1' then
            next_stream_buffer  := next_stream_buffer or shift_right(unsigned(data_i) & to_unsigned(0, 3*DATA_W),
                                        to_integer(next_fill_level));
            next_fill_level     := next_fill_level + DATA_W;
            state_d <= running;
          end if;
        -- ------------------------------------------------------------
        when running =>
          if fill_q >= len_i then
            vld_o <= '1';
          end if;
          -- STEP 1: consume
          if rdy_i = '1' and fill_q >= len_i then
            next_stream_buffer := shift_left(next_stream_buffer, consume_length );
            next_fill_level := next_fill_level - consume_length ;             
          end if;
          -- STEP 2: refill if room (threshold 3*DATA_W = 24)
          if next_fill_level < to_unsigned(RDY_THRESH, next_fill_level'length) then
            rdy_o <= '1';
            if vld_i = '1' then
              next_stream_buffer := next_stream_buffer or shift_right(unsigned(data_i) & to_unsigned(0, 3*DATA_W),
                                    to_integer(next_fill_level));
              next_fill_level := next_fill_level + DATA_W;
            end if;
          end if;
      end case;
    end if;
    stream_reg_d <= next_stream_buffer;
    fill_d       <= next_fill_level;
  end process comb_proc;
  ---------------------------------------------------------------------------
  -- Sequential
  ---------------------------------------------------------------------------
  seq_proc : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      state_q      <= idle;
      stream_reg_q <= (others => '0');
      fill_q       <= (others => '0');
    elsif rising_edge(clk_i) then
      state_q      <= state_d;
      stream_reg_q <= stream_reg_d;
      fill_q       <= fill_d;
    end if;
  end process seq_proc;

end architecture rtl;