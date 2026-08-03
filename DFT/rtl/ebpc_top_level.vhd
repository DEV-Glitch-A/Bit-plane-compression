library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ebpc_pkg.all;

entity ebpc_top_level is
  port(

    clk_i  : in  std_logic;
    rst_ni : in  std_logic;

    -- BPC compressed stream
    bpc_i      : in  std_logic_vector(DATA_W-1 downto 0);
    bpc_vld_i  : in  std_logic;
    bpc_rdy_o  : out std_logic;

    -- ZRLE stream
    znz_i      : in  std_logic_vector(DATA_W-1 downto 0);
    znz_vld_i  : in  std_logic;
    znz_rdy_o  : out std_logic;

    -- number of output words (value = #words - 1)
    num_words_i     : in  unsigned(LOG_DATA_W-1 downto 0);
    num_words_vld_i : in  std_logic;
    num_words_rdy_o : out std_logic;

    -- final decompressed output
    data_o : out std_logic_vector(DATA_W-1 downto 0);
    last_o : out std_logic;
    vld_o  : out std_logic;
    rdy_i  : in  std_logic;
    SERIAL_IN, SCAN_EN: in std_logic;
    SERIAL_OUT: out std_logic

  );
end entity;

architecture rtl of ebpc_top_level is

  ------------------------------------------------------------
  -- Internal signals
  ------------------------------------------------------------

  -- ZRLE decoder signals
  signal znz_bit    : std_logic;
  signal zrle_vld   : std_logic;
  signal zrle_rdy   : std_logic;
  signal zrle_flush : std_logic;

  -- BPC decoder signals
  signal bpc_data   : signed(DATA_W-1 downto 0);
  signal bpc_vld    : std_logic;
  signal bpc_rdy    : std_logic;
  signal bpc_clr    : std_logic;

  -- FSM
  type state_t is (idle, running);
  signal state_q, state_d : state_t;

  signal word_cnt_q, word_cnt_d : unsigned(LOG_DATA_W-1 downto 0);

begin

  ------------------------------------------------------------
  -- ZRLE DECODER
  ------------------------------------------------------------
  zrle_inst : entity work.zrle_decoder
    port map(
      clk_i   => clk_i,
      rst_ni  => rst_ni,
      znz_i   => znz_i,
      vld_i   => znz_vld_i,
      rdy_o   => znz_rdy_o,
      znz_o   => znz_bit,
      vld_o   => zrle_vld,
      flush_i => zrle_flush,
      rdy_i   => zrle_rdy
    );

  ------------------------------------------------------------
  -- BPC DECODER
  ------------------------------------------------------------
  bpc_inst : entity work.bpc_decoder
    port map(
      clk_i     => clk_i,
      rst_ni    => rst_ni,
      bpc_i     => bpc_i,
      bpc_vld_i => bpc_vld_i,
      bpc_rdy_o => bpc_rdy_o,
      data_o    => bpc_data,
      vld_o     => bpc_vld,
      rdy_i     => bpc_rdy,
      clr_i     => bpc_clr
    );

  ------------------------------------------------------------
  -- CONTROL FSM (combinational)
  ------------------------------------------------------------
  process(all)
  begin

    -- defaults
    state_d         <= state_q;
    word_cnt_d      <= word_cnt_q;

    vld_o           <= '0';
    last_o          <= '0';
    data_o          <= (others => '0');

    zrle_rdy        <= '0';
    zrle_flush      <= '0';
    bpc_rdy         <= '0';
    bpc_clr         <= '0';

    num_words_rdy_o <= '0';

    case state_q is

      ----------------------------------------------------------
      when idle =>

        num_words_rdy_o <= '1';

        if num_words_vld_i = '1' then
          word_cnt_d <= num_words_i;
          state_d    <= running;
        end if;

      ----------------------------------------------------------
      when running =>

        if zrle_vld = '1' then

          -- Assert last on the final word
          if word_cnt_q = 0 then
            last_o <= '1';
          end if;

          if znz_bit = '1' then
            -- -----------------------------------------------
            -- Non-zero word: data comes from BPC decoder
            -- Both ZRLE and BPC must handshake together
            -- -----------------------------------------------
            if bpc_vld = '1' then
              vld_o  <= '1';
              data_o <= std_logic_vector(bpc_data);

              if rdy_i = '1' then
                -- consume both streams simultaneously
                zrle_rdy <= '1';
                bpc_rdy  <= '1';

                if word_cnt_q = 0 then
                  -- last word done: flush and return to idle
                  zrle_flush <= '1';
                  bpc_clr    <= '1';
                  state_d    <= idle;
                else
                  word_cnt_d <= word_cnt_q - 1;
                end if;
              end if;
            end if;

          else
            -- -----------------------------------------------
            -- Zero word: output zero directly, only consume ZRLE
            -- -----------------------------------------------
            vld_o  <= '1';
            data_o <= (others => '0');

            if rdy_i = '1' then
              zrle_rdy <= '1';

              if word_cnt_q = 0 then
                zrle_flush <= '1';
                bpc_clr    <= '1';
                state_d    <= idle;
              else
                word_cnt_d <= word_cnt_q - 1;
              end if;
            end if;

          end if; -- znz_bit

        end if; -- zrle_vld

    end case;

  end process;

  ------------------------------------------------------------
  -- Sequential logic
  ------------------------------------------------------------
  process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      state_q    <= idle;
      word_cnt_q <= (others => '0');
    elsif rising_edge(clk_i) then
      state_q    <= state_d;
      word_cnt_q <= word_cnt_d;
    end if;
  end process;

end architecture;