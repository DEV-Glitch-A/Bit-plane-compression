library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ebpc_pkg.all;


entity bpc_decoder is
  generic (
    DATA_W     : positive := 8;
    LOG_DATA_W : positive := 3;
    BLOCK_SIZE : positive := 8
  );
  port (
    clk_i     : in  std_logic;
    rst_ni    : in  std_logic;

    bpc_i     : in  std_logic_vector(DATA_W-1 downto 0);
    bpc_vld_i : in  std_logic;
    bpc_rdy_o : out std_logic;

    data_o : out signed(DATA_W-1 downto 0);

    vld_o     : out std_logic;
    rdy_i     : in  std_logic;

    clr_i     : in  std_logic
  );
end entity;
architecture rtl of bpc_decoder is

  -- Unpacker  Decoder
  signal data_u2d   : std_logic_vector(DATA_W-1 downto 0);
  signal len_d2u : unsigned(LOG_DATA_W downto 0);
  signal fill_state : std_logic_vector(LOG_DATA_W downto 0);
  signal vld_u2d    : std_logic;
  signal rdy_d2u    : std_logic;
  signal base_u2b     : std_logic_vector(DATA_W-1 downto 0);
  signal base_vld_u2b : std_logic;

  

  -- Decoder Buffer
  signal data_d2b   : std_logic_vector(DATA_W-1 downto 0);
  signal push_d2b   : std_logic;
  signal vld_d2b    : std_logic;
  signal rdy_b2d    : std_logic;

  -- Buffer  Delta Reverse
  signal dbp_b2dr   : dbp_block_t;
  signal vld_b2dr   : std_logic;
  signal rdy_dr2b   : std_logic;


begin
u_unpacker : entity work.unpacker
  generic map (
    DATA_W     => DATA_W,
    LOG_DATA_W => LOG_DATA_W
  )
  port map (
    clk_i        => clk_i,
    rst_ni       => rst_ni,
    data_i       => bpc_i,
    vld_i        => bpc_vld_i,
    rdy_o        => bpc_rdy_o,
    data_o       => data_u2d,
    fill_state_o => fill_state,
    len_i        => len_d2u,
    vld_o        => vld_u2d,
    rdy_i        => rdy_d2u,
    clr_i        => clr_i
    
  );

u_decoder : entity work.symbol_decoder
  port map (
    clk_i                 => clk_i,
    rst_ni                => rst_ni,
    data_i                => data_u2d,
    unpacker_fill_state_i => fill_state,
    len_o                 => len_d2u,
    data_vld_i            => vld_u2d,
    data_rdy_o            => rdy_d2u,
    data_o                => data_d2b,
    push_o                => push_d2b,
    vld_o                 => vld_d2b,
    rdy_i                 => '1',
    clr_i                 => clr_i
  );

u_buffer : entity work.dbp_buffer
  port map (
    clk_i  => clk_i,
    rst_ni => rst_ni,
    data_i => data_d2b,
    push_i => push_d2b,
    vld_i  => vld_d2b,
    rdy_o  => rdy_b2d,
    data_o => dbp_b2dr,
    vld_o  => vld_b2dr,
    rdy_i  => rdy_dr2b,
    clr_i  => clr_i
  );

u_delta_reverse : entity work.delta_reverse
  port map (
    clk_i  => clk_i,
    rst_ni => rst_ni,
    data_i => dbp_b2dr,
    vld_i  => vld_b2dr,
    rdy_o  => rdy_dr2b,
    data_o => data_o,
    vld_o  => vld_o,
    rdy_i  => rdy_i,
    clr_i  => clr_i
  );

end architecture;

