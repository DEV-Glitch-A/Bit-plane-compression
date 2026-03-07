library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ebpc_pkg.DATA_W;
use work.ebpc_pkg.LOG_DATA_W;
use work.ebpc_pkg.LOG_MAX_ZRLE_LEN;

entity zrle_decoder is
  port (
    clk_i   : in  std_logic;
    rst_ni  : in  std_logic;

    znz_i   : in  std_logic_vector(DATA_W-1 downto 0);
    vld_i   : in  std_logic;
    rdy_o   : out std_logic;

    znz_o   : out std_logic;
    vld_o   : out std_logic;

    flush_i : in  std_logic;
    rdy_i   : in  std_logic
  );
end entity;

architecture rtl of zrle_decoder is

  type state_t is (empty, filling, full, zeros);

  signal state_d, state_q : state_t;

  signal stream_reg_d, stream_reg_q :
    std_logic_vector(2*DATA_W-1 downto 0);

  signal fill_state_d, fill_state_q :
    unsigned(LOG_DATA_W downto 0);

  signal zero_cnt_d, zero_cnt_q :
    unsigned(LOG_MAX_ZRLE_LEN-1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- Combinational FSM
  -----------------------------------------------------------------------------
  fsm : process(all)
    variable tmp_stream : std_logic_vector(2*DATA_W-1 downto 0);
     -- ADD THESE VARIABLES HERE (at top of process)
  variable shifted_stream :unsigned(2*DATA_W-1 downto 0);

  variable upper_bits :unsigned(LOG_MAX_ZRLE_LEN-1 downto 0);
  begin

    -- defaults
    stream_reg_d <= stream_reg_q;
    fill_state_d <= fill_state_q;
    zero_cnt_d   <= zero_cnt_q;
    state_d      <= state_q;

    vld_o <= '0';
    rdy_o <= '0';
    znz_o <= stream_reg_q(2*DATA_W-1);

    case state_q is

      -------------------------------------------------------------------------
      when empty =>
        rdy_o <= '1';
        if vld_i = '1' then
          state_d      <= full;
          fill_state_d <= to_unsigned(DATA_W, fill_state_d'length);
          stream_reg_d <= znz_i & (DATA_W-1 downto 0 => '0');
        end if;

      -------------------------------------------------------------------------
 when full =>

  vld_o <= '1';
  znz_o <= stream_reg_q(2*DATA_W-1);

  assert zero_cnt_q = 0
    report "Assertion failed: zero_cnt_q not 0 in full state"
    severity warning;

  if rdy_i = '1' then

    -- ZERO RUN
    if stream_reg_q(2*DATA_W-1) = '0' then

      stream_reg_d <= std_logic_vector(
        shift_left(unsigned(stream_reg_q),
                   1 + LOG_MAX_ZRLE_LEN)
      );

      fill_state_d <= fill_state_q -
        to_unsigned(1 + LOG_MAX_ZRLE_LEN,
                    fill_state_q'length);

      if unsigned(stream_reg_q(
           2*DATA_W-2 downto
           2*DATA_W-LOG_MAX_ZRLE_LEN-1)) > 0 then

        zero_cnt_d <= unsigned(stream_reg_q(
           2*DATA_W-2 downto
           2*DATA_W-LOG_MAX_ZRLE_LEN-1)) - 2;

        state_d <= zeros;

      end if;

    -- SINGLE ONE
    else

      stream_reg_d <= std_logic_vector(
        shift_left(unsigned(stream_reg_q),1)
      );

      fill_state_d <= fill_state_q - 1;

    end if;

  end if;
      -------------------------------------------------------------------------
  when filling =>

  rdy_o <= '1';

  -- Load new word if available
  if vld_i = '1' then

    shifted_stream :=
      shift_right(
        unsigned(znz_i & (DATA_W-1 downto 0 => '0')),
        to_integer(fill_state_q)
      );

    stream_reg_d <=
      stream_reg_q or std_logic_vector(shifted_stream);

    fill_state_d <=
      fill_state_q +
      to_unsigned(DATA_W, fill_state_q'length);

    state_d <= full;

  end if;

  -- OUTPUT LOGIC (THIS WAS MISSING)
  if stream_reg_q(2*DATA_W-1) = '1' or
     fill_state_q > LOG_MAX_ZRLE_LEN then

    vld_o <= '1';

    if rdy_i = '1' then

      if stream_reg_q(2*DATA_W-1) = '1' then
        -- single one
        stream_reg_d <= std_logic_vector(
          shift_left(unsigned(stream_reg_q), 1)
        );
        fill_state_d <= fill_state_q - 1;

      else
        -- zero runlength
        stream_reg_d <= std_logic_vector(
          shift_left(unsigned(stream_reg_q),
                     LOG_MAX_ZRLE_LEN + 1)
        );
        fill_state_d <= fill_state_q -
                        to_unsigned(LOG_MAX_ZRLE_LEN + 1,
                                    fill_state_q'length);
      end if;

    end if;

  end if;

      -------------------------------------------------------------------------
    when zeros =>

      znz_o <= '0';
      vld_o <= '1';

      if rdy_i = '1' then

        if zero_cnt_q = 0 then
          -- run finished
          state_d <= full;
        else
          zero_cnt_d <= zero_cnt_q - 1;
          state_d    <= zeros;
        end if;

      end if;

    end case;

  end process;

  -----------------------------------------------------------------------------
  -- Sequential logic
  -----------------------------------------------------------------------------
  sequential : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      state_q      <= empty;
      zero_cnt_q   <= (others => '0');
      stream_reg_q <= (others => '0');
      fill_state_q <= (others => '0');
    elsif rising_edge(clk_i) then
      state_q      <= state_d;
      zero_cnt_q   <= zero_cnt_d;
      stream_reg_q <= stream_reg_d;
      fill_state_q <= fill_state_d;
    end if;
  end process;

end architecture;