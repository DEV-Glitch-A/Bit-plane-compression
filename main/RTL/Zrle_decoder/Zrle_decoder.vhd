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

  signal state_d,      state_q      : state_t;
  signal stream_reg_d, stream_reg_q : std_logic_vector(2*DATA_W-1 downto 0);
  signal fill_state_d, fill_state_q : unsigned(LOG_DATA_W downto 0);
  signal zero_cnt_d,   zero_cnt_q   : unsigned(LOG_MAX_ZRLE_LEN-1 downto 0);

  -- Minimum fill needed to decode a zero-run token (flag + count field)
  constant ZRUN_BITS : natural := 1 + LOG_MAX_ZRLE_LEN;

begin
  ---------------------------------------------------------------------------
  -- Combinational FSM
  ---------------------------------------------------------------------------
  fsm : process(all)

    variable v_stream       : std_logic_vector(2*DATA_W-1 downto 0);
    variable v_fill         : unsigned(LOG_DATA_W downto 0);
    variable v_state        : state_t;
    variable v_zero_cnt     : unsigned(LOG_MAX_ZRLE_LEN-1 downto 0);
    variable shifted_stream : unsigned(2*DATA_W-1 downto 0);
    variable v_count        : unsigned(LOG_MAX_ZRLE_LEN-1 downto 0);
    variable can_output     : boolean;

  begin
    -- Signal defaults 
    stream_reg_d <= stream_reg_q;
    fill_state_d <= fill_state_q;
    zero_cnt_d   <= zero_cnt_q;
    state_d      <= state_q;

    vld_o <= '0';
    rdy_o <= '0';
    znz_o <= stream_reg_q(2*DATA_W-1);

    -- =====================================================================
    -- FIX 5: flush resets all pipeline state (synchronous, high priority)
    -- =====================================================================
    if flush_i = '1' then

      state_d      <= empty;
      stream_reg_d <= (others => '0');
      fill_state_d <= (others => '0');
      zero_cnt_d   <= (others => '0');

    else
      case state_q is
        when empty =>
          rdy_o <= '1';
          if vld_i = '1' then
            state_d      <= full;
            fill_state_d <= to_unsigned(DATA_W, fill_state_d'length);
            stream_reg_d <= znz_i & (DATA_W-1 downto 0 => '0');
          end if;
        -- -------------------------------------------------------------------
        when full =>
          -- Initialise working variables from registered state
          v_stream   := stream_reg_q;
          v_fill     := fill_state_q;
          v_state    := full;
          v_zero_cnt := zero_cnt_q;
          -- ================================================================
          -- FIX 1a: gate vld_o on fill_state > 0.
          -- Without this, an empty (all-zero) stream register asserts valid
          -- and gets decoded as a spurious zero-run with count=0.
          -- ================================================================
          if fill_state_q > 0 then

            znz_o <= v_stream(2*DATA_W-1);

            -- ================================================================
            -- FIX 1b: for a zero-run token we need flag + count bits.
            -- If fill is insufficient, stall in 'filling' until more arrive.
            -- ================================================================
            if v_stream(2*DATA_W-1) = '0' and fill_state_q < to_unsigned(ZRUN_BITS, fill_state_q'length) then ---(checks if data_w is ending with '0')
              -- Not enough bits to read the full count field; go fetch more.
              rdy_o   <= '1';
              v_state := filling;
              -- Don't assert vld_o; wait silently.
            else
              vld_o <= '1'; (Current token is valid and decodable)
              if rdy_i = '1' then
                -- ----------------------------------------------------------
                -- Step 1 – CONSUME current token (using variable, immediate)
                -- ----------------------------------------------------------
                if v_stream(2*DATA_W-1) = '0' then
                  -- Zero-run: read count field BEFORE shifting.
                  v_count := unsigned(v_stream(2*DATA_W-2 downto 2*DATA_W-1-LOG_MAX_ZRLE_LEN));
                  -- FIX 3: use "> 1" to prevent count=1 → underflow bug.
                  -- count=0 → 1 zero (flag only, no zeros state needed).
                  -- count=1 → illegal per encoder contract; treated as 1 zero.
                  -- count≥2 → enter zeros state.
                  if v_count > 1 then
                    v_zero_cnt := v_count - 2; --(first zero emitted now, remaining zeros emitted in ZERO state)
                    v_state    := zeros;
                  end if;
                  v_stream := std_logic_vector(shift_left(unsigned(v_stream), ZRUN_BITS));
                  v_fill := v_fill - to_unsigned(ZRUN_BITS, v_fill'length);
                else
                  -- Single-one token: consume 1 bit.
                  v_stream := std_logic_vector(shift_left(unsigned(v_stream), 1));
                  v_fill := v_fill - 1;
                end if;
                -- ---------------------------------------------------------
                -- Step 2 – REFILL at post-consume offset
                -- v_fill already reflects the consumed bits, so the new byte
                -- lands at exactly the right position in the window.
                -- ----------------------------------------------------------
                if v_fill < DATA_W then
                  rdy_o <= '1';
                  if vld_i = '1' then
                    shifted_stream :=shift_right(unsigned(znz_i & (DATA_W-1 downto 0 => '0')),to_integer(v_fill));
                    v_stream := v_stream or std_logic_vector(shifted_stream);
                    v_fill   := v_fill + to_unsigned(DATA_W, v_fill'length);
                  else -- no incoming byte
                    -- No input available; stall in filling unless headed to zeros.
                    if v_state /= zeros then
                      v_state := filling;
                    end if;
                  end if;
                end if;
                -- Commit variable results to signals.
                stream_reg_d <= v_stream;
                fill_state_d <= v_fill;
                state_d      <= v_state;
                zero_cnt_d   <= v_zero_cnt;
              end if; -- rdy_i
            end if; -- fill sufficient / zero-run guard
          else
            -- fill = 0: nothing valid in the window; stall.
            state_d <= filling;
          end if; -- fill_state_q > 0
        -- -------------------------------------------------------------------
        when filling =>
          v_stream   := stream_reg_q;
          v_fill     := fill_state_q;
          v_state    := filling;
          v_zero_cnt := zero_cnt_q;
          -- Determine whether a full token is available in the current window.
          -- A single-one needs 1 bit; a zero-run needs ZRUN_BITS bits.
          if v_stream(2*DATA_W-1) = '1' then
            can_output := (v_fill >= 1);
          else
            can_output := (v_fill >= to_unsigned(ZRUN_BITS, v_fill'length));
          end if;
          if can_output then
            vld_o <= '1';
            znz_o <= v_stream(2*DATA_W-1);
            if rdy_i = '1' then
              if v_stream(2*DATA_W-1) = '1' then
                -- Single-one
                v_stream := std_logic_vector(
                  shift_left(unsigned(v_stream), 1));
                v_fill := v_fill - 1;

              else
                -- Zero-run
                v_count := unsigned(v_stream(2*DATA_W-2 downto 2*DATA_W-1-LOG_MAX_ZRLE_LEN));
                if v_count > 1 then
                  v_zero_cnt := v_count - 2;
                  v_state    := zeros;
                end if;
                v_stream := std_logic_vector(
                  shift_left(unsigned(v_stream), ZRUN_BITS));
                v_fill := v_fill - to_unsigned(ZRUN_BITS, v_fill'length);
              end if;

            end if;

          end if; -- can_output

          -- Always accept a new byte to top up the window.
          rdy_o <= '1';

          if vld_i = '1' then
            shifted_stream :=
              shift_right(
                unsigned(znz_i & (DATA_W-1 downto 0 => '0')),
                to_integer(v_fill));

            v_stream := v_stream or std_logic_vector(shifted_stream);
            v_fill   := v_fill + to_unsigned(DATA_W, v_fill'length);

            if v_state /= zeros then
              v_state := full;
            end if;
          end if;

          stream_reg_d <= v_stream;
          fill_state_d <= v_fill;
          state_d      <= v_state;
          zero_cnt_d   <= v_zero_cnt;

        -- -------------------------------------------------------------------
        when zeros =>

          znz_o <= '0';
          vld_o <= '1';
          if fill_state_q < DATA_W then

            rdy_o <= '1';

            if vld_i = '1' then
              shifted_stream :=
                shift_right(
                  unsigned(znz_i & (DATA_W-1 downto 0 => '0')),
                  to_integer(fill_state_q));

              stream_reg_d <=
                stream_reg_q or std_logic_vector(shifted_stream);

              fill_state_d <=
                fill_state_q + to_unsigned(DATA_W, fill_state_q'length);
            end if;

          end if;

          if rdy_i = '1' then
            if zero_cnt_q = 0 then
              -- Last zero in this run; return to full.
              state_d <= full;
            else
              zero_cnt_d <= zero_cnt_q - 1;
            end if;
          end if;
      end case;
    end if; -- flush_i
  end process;
  ---------------------------------------------------------------------------
  -- Sequential logic
  ---------------------------------------------------------------------------
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