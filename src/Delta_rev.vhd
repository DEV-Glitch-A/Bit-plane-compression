library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ebpc_pkg.all;

entity delta_reverse is
  port (
    clk_i   : in  std_logic;
    rst_ni  : in  std_logic;
    data_i  : in  dbp_block_t;
    vld_i   : in  std_logic;
    rdy_o   : out std_logic;

    -- KEEP 8-bit output
    data_o  : out signed(DATA_W-1 downto 0);

    vld_o   : out std_logic;
    rdy_i   : in  std_logic;
    clr_i   : in  std_logic
  );
end entity;

architecture rtl of delta_reverse is

  constant DIFF_IDX_W : natural := clog2(BLOCK_SIZE-1);

  -- deltas remain 9-bit
  type diff_array_t is array (0 to BLOCK_SIZE-2) of signed(DATA_W downto 0);

  signal diffs : diff_array_t;

  type state_t is (base, stream);
  signal state_q, state_d : state_t;

  -- WIDEN accumulator internally
  signal acc_reg_q, acc_reg_d : signed(DATA_W+1 downto 0);  -- <<< CHANGED

  signal diff_idx_q, diff_idx_d : unsigned(DIFF_IDX_W-1 downto 0);

begin

  --------------------------------------------------------------------
  -- Bit-plane  delta reconstruction (unchanged)
  --------------------------------------------------------------------
  orient_bits : process(all)
  begin
    for i in 0 to BLOCK_SIZE-2 loop
      for j in 0 to DATA_W loop
        diffs(i)(j) <= data_i.dbp(j)(BLOCK_SIZE-2-i);
      end loop;
    end loop;
  end process;

  --------------------------------------------------------------------
  -- Combinational FSM
  --------------------------------------------------------------------
  fsm_comb : process(all)
  begin
    state_d    <= state_q;
    acc_reg_d  <= acc_reg_q;
    diff_idx_d <= diff_idx_q;

    rdy_o  <= '0';
    vld_o  <= '0';

    -- EXPLICIT 8-bit conversion
    data_o <= resize(acc_reg_q, DATA_W);  -- <<< CHANGED

    case state_q is

      ----------------------------------------------------------------
      -- BASE state
      ----------------------------------------------------------------
      when base =>
        diff_idx_d <= (others => '0');

        -- output base (8-bit)
        data_o <= resize(data_i.base, DATA_W);

        if vld_i = '1' then
          vld_o <= '1';

          -- initialize wide accumulator
          acc_reg_d <= resize(data_i.base, DATA_W+2) + resize(diffs(0), DATA_W+2);               -- <<< CHANGED

          if rdy_i = '1' then
            state_d <= stream;
            diff_idx_d <= diff_idx_q + 1;
          end if;
        end if;

      ----------------------------------------------------------------
      -- STREAM state
      ----------------------------------------------------------------
      when stream =>
        vld_o <= '1';

        if rdy_i = '1' then
          acc_reg_d <= acc_reg_q + resize(diffs(to_integer(diff_idx_q)),DATA_W+2);                         -- <<< CHANGED

          if diff_idx_q = 0 then
            rdy_o   <= '1';
            state_d <= base;
          elsif diff_idx_q < BLOCK_SIZE-2 then
            diff_idx_d <= diff_idx_q + 1;
          else
            diff_idx_d <= (others => '0');
          end if;
        end if;

    end case;

    ----------------------------------------------------------------
    -- Clear
    ----------------------------------------------------------------
    if clr_i = '1' then
      state_d    <= base;
      acc_reg_d  <= (others => '0');  -- <<< CHANGED
      diff_idx_d <= (others => '0');
    end if;
  end process;

  --------------------------------------------------------------------
  -- Sequential logic
  --------------------------------------------------------------------
  fsm_seq : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      state_q    <= base;
      acc_reg_q  <= (others => '0');  -- <<< CHANGED
      diff_idx_q <= (others => '0');
    elsif rising_edge(clk_i) then
      state_q    <= state_d;
      acc_reg_q  <= acc_reg_d;        -- <<< CHANGED
      diff_idx_q <= diff_idx_d;
    end if;
  end process;

end architecture;
