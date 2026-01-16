-- Collects base + delta/XOR words and forms DBP block

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ebpc_pkg.all;

entity dbp_buffer is
  port (
    clk_i   : in  std_logic;
    rst_ni  : in  std_logic;

    data_i  : in  std_logic_vector(DATA_W-1 downto 0);
    push_i  : in  std_logic;
    vld_i   : in  std_logic;

    rdy_o   : out std_logic;

    data_o  : out dbp_block_t;
    vld_o   : out std_logic;
    rdy_i   : in  std_logic;

    clr_i   : in  std_logic
  );
end entity dbp_buffer;

architecture rtl of dbp_buffer is

  ---------------------------------------------------------------------------
  -- FSM
  ---------------------------------------------------------------------------
  type state_t is (wait_base, filling, full);
  signal state_d, state_q : state_t;

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------
  signal base_d, base_q : unsigned(DATA_W-1 downto 0);

  type shift_reg_t is array (0 to DATA_W) of
    std_logic_vector(BLOCK_SIZE-2 downto 0);

  signal shift_reg_d, shift_reg_q : shift_reg_t;

  ---------------------------------------------------------------------------
  -- FIFO interface
  ---------------------------------------------------------------------------
  signal vld_to_slice    : std_logic;
  signal rdy_from_slice  : std_logic;
  signal rdy_to_slice    : std_logic;

  signal dbp_block_to_fifo : dbp_block_t;

begin

  ---------------------------------------------------------------------------
  -- Pack DBP block
  ---------------------------------------------------------------------------
  pack_block : process(all)
  begin
    dbp_block_to_fifo.base <= signed(base_q);
    for i in 0 to DATA_W loop
      dbp_block_to_fifo.dbp(i) <= shift_reg_q(i);
    end loop;
  end process;

  ---------------------------------------------------------------------------
  -- FSM + datapath
  ---------------------------------------------------------------------------
  comb : process(all)
  begin
    -- defaults
    rdy_o        <= '0';
    shift_reg_d  <= shift_reg_q;
    vld_to_slice <= '0';
    rdy_to_slice <= rdy_i;
    state_d      <= state_q;
    base_d       <= base_q;

    case state_q is

      -----------------------------------------------------------------------
      when wait_base =>
        rdy_o <= '1';
        if push_i = '1' then
          base_d  <= unsigned(data_i);
          state_d <= filling;
        end if;

      -----------------------------------------------------------------------
      when filling =>
        rdy_o <= '1';

        if push_i = '1' then
          -- MSB / sign plane
          shift_reg_d(DATA_W) <= data_i(DATA_W-1 downto 1);

          -- Shift remaining planes
          for i in DATA_W-1 downto 0 loop
            shift_reg_d(i) <= shift_reg_q(i+1);
          end loop;
        end if;

        if vld_i = '1' then
          state_d <= full;
        end if;

      -----------------------------------------------------------------------
      when full =>
        vld_to_slice <= '1';

        if rdy_from_slice = '1' then
          rdy_o <= '1';
          if push_i = '1' then
            base_d  <= unsigned(data_i);
            state_d <= filling;
          else
            state_d <= wait_base;
          end if;
        end if;

    end case;

    -------------------------------------------------------------------------
    -- Soft clear
    -------------------------------------------------------------------------
    if clr_i = '1' then
      for i in 0 to DATA_W loop
        shift_reg_d(i) <= (others => '0');
      end loop;
      base_d       <= (others => '0');
      state_d      <= wait_base;
      rdy_to_slice <= '1';
    end if;

  end process;

  ---------------------------------------------------------------------------
  -- Sequential logic
  ---------------------------------------------------------------------------
  seq : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      for i in 0 to DATA_W loop
        shift_reg_q(i) <= (others => '0');
      end loop;
      base_q  <= (others => '0');
      state_q <= wait_base;

    elsif rising_edge(clk_i) then
      shift_reg_q <= shift_reg_d;
      base_q      <= base_d;
      state_q     <= state_d;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- FIFO slice (record-based)
  ---------------------------------------------------------------------------
  slice_i : entity work.fifo_slice
    generic map (
      t => dbp_block_t
    )
    port map (
      clk_i  => clk_i,
      rst_ni => rst_ni,
      din_i  => dbp_block_to_fifo,
      vld_i  => vld_to_slice,
      rdy_o  => rdy_from_slice,
      dout_o => data_o,
      vld_o  => vld_o,
      rdy_i  => rdy_to_slice
    );

end architecture rtl;
 