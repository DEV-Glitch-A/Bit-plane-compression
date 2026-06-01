library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ebpc_pkg.DATA_W;
use work.ebpc_pkg.LOG_DATA_W;
use work.ebpc_pkg.LOG_MAX_ZRLE_LEN;

entity tb_zrle_decoder is
end entity;

architecture sim of tb_zrle_decoder is

  --------------------------------------------------------------------
  -- Signals
  --------------------------------------------------------------------
  signal clk_i    : std_logic := '0';
  signal rst_ni   : std_logic := '0';

  signal znz_i    : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
  signal vld_i    : std_logic := '0';
  signal rdy_o    : std_logic;

  signal znz_o    : std_logic;
  signal vld_o    : std_logic;

  signal flush_i  : std_logic := '0';
  signal rdy_i    : std_logic := '1';  -- Always ready to accept output

begin

  --------------------------------------------------------------------
  -- Clock generation (10ns period)
  --------------------------------------------------------------------
  clk_i <= not clk_i after 5 ns;

  --------------------------------------------------------------------
  -- DUT
  --------------------------------------------------------------------
  dut : entity work.zrle_decoder
    port map (
      clk_i   => clk_i,
      rst_ni  => rst_ni,
      znz_i   => znz_i,
      vld_i   => vld_i,
      rdy_o   => rdy_o,
      znz_o   => znz_o,
      vld_o   => vld_o,
      flush_i => flush_i,
      rdy_i   => rdy_i
    );

  --------------------------------------------------------------------
  -- Stimulus
  --------------------------------------------------------------------
  process
  begin
    
    ------------------------------------------------------------------
    -- Reset
    ------------------------------------------------------------------
    rst_ni <= '0';
    wait for 30 ns;
    rst_ni <= '1';
    wait until rising_edge(clk_i);

    ------------------------------------------------------------------
    -- Wait until decoder is ready
    ------------------------------------------------------------------
    while rdy_o = '0' loop
      wait until rising_edge(clk_i);
    end loop;

    -- First word
    znz_i <= "10010110";
    vld_i <= '1';
    wait until rising_edge(clk_i);

    vld_i <= '0';
    wait until rising_edge(clk_i);

    -- Wait for request
    while rdy_o = '0' loop
      wait until rising_edge(clk_i);
    end loop;

    -- Second word
    znz_i <= "00010000";
    vld_i <= '1';
    wait until rising_edge(clk_i);

    vld_i <= '0';

    -- Immediately flush after stream
    wait until rising_edge(clk_i);
    flush_i <= '1';
    wait until rising_edge(clk_i);
    flush_i <= '0';

    wait for 50 ns;

    assert false report "Simulation Finished" severity failure;

  end process;
  process(clk_i)
    variable count : integer := 0;
  begin
    if rising_edge(clk_i) then
      if vld_o = '1' then
        report "Decoded bit = " & std_logic'image(znz_o);

        count := count + 1;

        if count = 8 then
          assert false report "Simulation finished correctly" severity failure;
        end if;
      end if;
    end if;
  end process;

end architecture;