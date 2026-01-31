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

    data_o  : out signed(DATA_W-1 downto 0);

    vld_o   : out std_logic;
    rdy_i   : in  std_logic;
    clr_i   : in  std_logic
  );
end entity;

architecture rtl of delta_reverse is

  constant DIFF_IDX_W : natural := clog2(BLOCK_SIZE-1);

  type diff_array_t is array (0 to BLOCK_SIZE-2) of signed(DATA_W downto 0);

  signal diffs : diff_array_t;

  type state_t is (base, stream);
  signal state_q, state_d : state_t;

  signal acc_reg_q, acc_reg_d : signed(DATA_W+1 downto 0);

  signal diff_idx_q, diff_idx_d : unsigned(DIFF_IDX_W-1 downto 0);

begin

  --------------------------------------------------------------------
  orient_bits : process(all)
    constant BASE_DBP : std_logic_vector(6 downto 0) := "1010101";
  begin
    for i in 0 to BLOCK_SIZE-2 loop  -- For each diff (0 to 6)
      -- MSB (bit 8) comes from Base DBP
      diffs(i)(8) <= BASE_DBP(BLOCK_SIZE-2-i);
      
      -- Remaining bits (7 down to 0) come from dbp[0..7] - REVERSED
      for j in 0 to 7 loop
        diffs(i)(7-j) <= data_i.dbp(j)(BLOCK_SIZE-2-i);  -- ✅ Reverse: bit(7-j)
      end loop;
    end loop;
  end process;
  
  --------------------------------------------------------------------
  -- Debug process - prints ALWAYS on every clock to verify file is loaded
  --------------------------------------------------------------------
  debug_proc : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if vld_i = '1' then
        report "=== DELTA_REVERSE: vld_i is HIGH ===" & LF &
               "BIT-PLANES:" & LF &
               "dbp[0]=" & to_string(data_i.dbp(0)) & LF &
               "dbp[1]=" & to_string(data_i.dbp(1)) & LF &
               "dbp[2]=" & to_string(data_i.dbp(2)) & LF &
               "dbp[3]=" & to_string(data_i.dbp(3)) & LF &
               "dbp[4]=" & to_string(data_i.dbp(4)) & LF &
               "dbp[5]=" & to_string(data_i.dbp(5)) & LF &
               "dbp[6]=" & to_string(data_i.dbp(6)) & LF &
               "dbp[7]=" & to_string(data_i.dbp(7)) & LF &
               "dbp[8]=" & to_string(data_i.dbp(8)) & LF &
               "DELTAS:" & LF &
               "diffs[0]=" & to_string(std_logic_vector(diffs(0))) & " = " & integer'image(to_integer(diffs(0))) & LF &
               "diffs[1]=" & to_string(std_logic_vector(diffs(1))) & " = " & integer'image(to_integer(diffs(1))) & LF &
               "diffs[2]=" & to_string(std_logic_vector(diffs(2))) & " = " & integer'image(to_integer(diffs(2))) & LF &
               "diffs[3]=" & to_string(std_logic_vector(diffs(3))) & " = " & integer'image(to_integer(diffs(3))) & LF &
               "diffs[4]=" & to_string(std_logic_vector(diffs(4))) & " = " & integer'image(to_integer(diffs(4))) & LF &
               "diffs[5]=" & to_string(std_logic_vector(diffs(5))) & " = " & integer'image(to_integer(diffs(5))) & LF &
               "diffs[6]=" & to_string(std_logic_vector(diffs(6))) & " = " & integer'image(to_integer(diffs(6)))
               severity note;
      end if;
    end if;
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

    -- Take lower 8 bits as unsigned, then convert to signed
    data_o <= signed(unsigned(acc_reg_q(DATA_W-1 downto 0)));

    case state_q is

      ----------------------------------------------------------------
      -- BASE state
      ----------------------------------------------------------------
      when base=>
        diff_idx_d <= (others => '0');
        -- output base
        data_o <= resize(data_i.base, DATA_W);

        if vld_i = '1' then
          vld_o <= '1';

          acc_reg_d <= signed(resize(unsigned(data_i.base), DATA_W+2)) + resize(diffs(0), DATA_W+2);

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
        --  Output current accumulator value (already includes previous diffs)
        data_o <= acc_reg_q(DATA_W-1 downto 0);  -- Truncate to 8 bits
        
        if rdy_i = '1' then
          --  Add NEXT diff for next cycle
          if diff_idx_q <= BLOCK_SIZE-2 then
            acc_reg_d <= acc_reg_q + resize(diffs(to_integer(diff_idx_q)), DATA_W+2);
            diff_idx_d <= diff_idx_q + 1;
          end if;

          -- Check if we've output all 7 values (diffs 0-6)
          if diff_idx_q = BLOCK_SIZE-1 then
            rdy_o   <= '1';
            state_d <= base;
            diff_idx_d <= (others => '0');
          end if;
        end if;

    end case;

    ----------------------------------------------------------------
    -- Clear
    ----------------------------------------------------------------
    if clr_i = '1' then
      state_d    <= base;
      acc_reg_d  <= (others => '0');
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
      acc_reg_q  <= (others => '0');
      diff_idx_q <= (others => '0');
    elsif rising_edge(clk_i) then
      state_q    <= state_d;
      acc_reg_q  <= acc_reg_d;
      diff_idx_q <= diff_idx_d;
    end if;
  end process;

end architecture;
