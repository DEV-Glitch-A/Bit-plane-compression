library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_bpc_decoder is
end entity;

architecture sim of tb_bpc_decoder is

  ---------------------------------------------------------------------------
  -- Constants
  ---------------------------------------------------------------------------
  constant DATA_W     : integer := 8;
  constant LOG_DATA_W : integer := 3;
  constant BLOCK_SIZE : integer := 8;

  ---------------------------------------------------------------------------
  -- DUT signals
  ---------------------------------------------------------------------------
  signal clk_i     : std_logic := '0';
  signal rst_ni    : std_logic := '0';

  signal bpc_i     : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
  signal bpc_vld_i : std_logic := '0';
  signal bpc_rdy_o : std_logic;

  signal data_o    : signed(DATA_W-1 downto 0);
  signal vld_o     : std_logic;
  signal rdy_i     : std_logic := '1';

  signal clr_i     : std_logic := '0';

  ---------------------------------------------------------------------------
  -- Input stimulus
  ---------------------------------------------------------------------------
  type bpc_array_t is array (natural range <>) of std_logic_vector(DATA_W-1 downto 0);

  constant BPC_STREAM : bpc_array_t := (
    x"FA",
    x"FC",  -- Block 0: 11111100
    x"44",  -- 01000100
    x"E7",  -- 11100111
    x"FB",  -- 11111011
    x"6E",  -- 01101110
    x"ED",  -- 11101101
    x"5B",  -- 01011011
    x"40"   -- 01000000 (padding)
  );

begin

  ---------------------------------------------------------------------------
  -- Clock generation (100 MHz)
  ---------------------------------------------------------------------------
  clk_i <= not clk_i after 5 ns;

  ---------------------------------------------------------------------------
  -- DUT instance
  ---------------------------------------------------------------------------
  dut : entity work.bpc_decoder
    generic map (
      DATA_W     => DATA_W,
      LOG_DATA_W => LOG_DATA_W,
      BLOCK_SIZE => BLOCK_SIZE
    )
    port map (
      clk_i     => clk_i,
      rst_ni    => rst_ni,
      bpc_i     => bpc_i,
      bpc_vld_i => bpc_vld_i,
      bpc_rdy_o => bpc_rdy_o,
      data_o    => data_o,
      vld_o     => vld_o,
      rdy_i     => rdy_i,
      clr_i     => clr_i
    );

  ---------------------------------------------------------------------------
  -- Reset process
  ---------------------------------------------------------------------------
  reset_proc : process
  begin
    rst_ni <= '0';
    wait for 50 ns;
    rst_ni <= '1';
    wait;
  end process;

  ---------------------------------------------------------------------------
  -- Stimulus process
  ---------------------------------------------------------------------------
  stim_proc : process
  begin
    -- wait for reset deassertion and pipeline settle
    wait until rst_ni = '1';
    wait for 20 ns;
    wait until rising_edge(clk_i);

    for i in BPC_STREAM'range loop

      -- wait until DUT is ready
      while bpc_rdy_o = '0' loop
        wait until rising_edge(clk_i);
      end loop;

      bpc_i     <= BPC_STREAM(i);
      bpc_vld_i <= '1';

      wait until rising_edge(clk_i);

      bpc_vld_i <= '0';
    end loop;

    -- stop driving inputs
    bpc_i <= (others => '0');

    -- allow pipeline to flush
    wait for 500 ns;

    report "Simulation finished successfully" severity note;
    wait;
  end process;

  ---------------------------------------------------------------------------
  -- Output checker (skip first output)
  ---------------------------------------------------------------------------
  check_proc : process
    variable out_idx : integer := 0;
  begin
    wait until rising_edge(clk_i);

    if vld_o = '1' then

      if out_idx = 0 then
        report "Skipping first output (pipeline warm-up): "
               & integer'image(to_integer(data_o))
               severity note;
      else
        report "Output[" & integer'image(out_idx) & "] = "
               & integer'image(to_integer(data_o))
               severity note;
      end if;

      out_idx := out_idx + 1;
    end if;
  end process;

end architecture sim;
