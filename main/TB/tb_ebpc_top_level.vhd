library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ebpc_pkg.all;

entity tb_ebpc_top_level is
end tb_ebpc_top_level;

architecture sim of tb_ebpc_top_level is

--------------------------------------------------
-- Clock / Reset
--------------------------------------------------

signal clk_i  : std_logic := '0';
signal rst_ni : std_logic := '0';

--------------------------------------------------
-- BPC interface
--------------------------------------------------

signal bpc_i      : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
signal bpc_vld_i  : std_logic := '0';
signal bpc_rdy_o  : std_logic;

--------------------------------------------------
-- ZRLE interface
--------------------------------------------------

signal znz_i      : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
signal znz_vld_i  : std_logic := '0';
signal znz_rdy_o  : std_logic;

--------------------------------------------------
-- Word count
--------------------------------------------------

signal num_words_i     : unsigned(LOG_MAX_WORDS-1 downto 0) := (others => '0');
signal num_words_vld_i : std_logic := '0';
signal num_words_rdy_o : std_logic;

--------------------------------------------------
-- Output
--------------------------------------------------

signal data_o : std_logic_vector(DATA_W-1 downto 0);
signal last_o : std_logic;
signal vld_o  : std_logic;
signal rdy_i  : std_logic := '1';

--------------------------------------------------
-- BPC compressed stream (9 bytes for 7 decoded words)
--------------------------------------------------

type data_array is array (0 to 8) of std_logic_vector(DATA_W-1 downto 0);

constant BPC_STREAM : data_array :=
(
    x"FA",
    x"FC",
    x"44",
    x"E7",
    x"FB",
    x"6E",
    x"ED",
    x"6D",
    x"80"
);

-- Expected decoded values (for reference in monitor):
-- delta_reverse base = 0xFA = 250 (unsigned) / -6 (signed)
-- diffs: -241, 245, -230, 215, -211, 25, -21
-- cumulative (signed 8-bit wrapping):
--   250, 9, 254, 24, 239, 28, 53  (7 non-zero values)
-- With znz all-ones: 7 non-zero words + FSM also needs 8 total?
-- num_words = 6 (= 7 words - 1) to match 7 BPC output words

begin

--------------------------------------------------
-- DUT
--------------------------------------------------

dut : entity work.ebpc_top_level
port map(
    clk_i           => clk_i,
    rst_ni          => rst_ni,
    bpc_i           => bpc_i,
    bpc_vld_i       => bpc_vld_i,
    bpc_rdy_o       => bpc_rdy_o,
    znz_i           => znz_i,
    znz_vld_i       => znz_vld_i,
    znz_rdy_o       => znz_rdy_o,
    num_words_i     => num_words_i,
    num_words_vld_i => num_words_vld_i,
    num_words_rdy_o => num_words_rdy_o,
    data_o          => data_o,
    last_o          => last_o,
    vld_o           => vld_o,
    rdy_i           => rdy_i
);

--------------------------------------------------
-- Clock generator: 10 ns period
--------------------------------------------------

clk_process : process
begin
    while true loop
        clk_i <= '0'; wait for 5 ns;
        clk_i <= '1'; wait for 5 ns;
    end loop;
end process;

--------------------------------------------------
-- Stimulus
--------------------------------------------------

stimulus : process
begin

    ------------------------------------------------
    -- Reset
    ------------------------------------------------
    rst_ni <= '0';
    wait for 20 ns;
    rst_ni <= '1';
    wait for 10 ns;

    ------------------------------------------------
    -- Provide number of output words
    -- BPC stream encodes exactly 7 words, so num_words = 6
    ------------------------------------------------
    num_words_i     <= to_unsigned(6, LOG_MAX_WORDS);
    num_words_vld_i <= '1';
    wait until rising_edge(clk_i) and num_words_rdy_o = '1';
    wait for 1 ns;
    num_words_vld_i <= '0';

    wait for 10 ns;

    ------------------------------------------------
    -- Send ZRLE stream.
    --
    -- FIX: "10000000" (0x80) encodes ONE non-zero flag then a
    -- zero-run (the trailing 7 zeros become a zero-run symbol).
    --
    -- To encode N consecutive non-zero flags the ZRLE bitstream
    -- needs N consecutive '1' bits.  7 ones fits in one byte:
    -- "11111110" = 0xFE  (7 ones + 1 padding zero).
    -- Send 2 bytes for margin; the decoder stops when the FSM
    -- has consumed all required words.
    ------------------------------------------------
    znz_vld_i <= '1';
    znz_i     <= x"FE";   -- bits 7..1 = '1' (7 non-zero flags), bit 0 = padding
    wait for 10 ns;
    znz_i     <= x"FF";   -- extra byte for pipeline fill
    wait for 10 ns;
    znz_vld_i <= '0';

    wait for 10 ns;

    ------------------------------------------------
    -- Send BPC compressed stream (handshake-aware)
    ------------------------------------------------
    bpc_vld_i <= '1';
    for i in BPC_STREAM'range loop
        bpc_i <= BPC_STREAM(i);
        wait until rising_edge(clk_i) and bpc_rdy_o = '1';
        wait for 1 ns;
    end loop;
    bpc_vld_i <= '0';

    ------------------------------------------------
    -- Wait for all outputs
    ------------------------------------------------
    wait for 500 ns;
    wait;

end process;

--------------------------------------------------
-- Monitor: print every accepted output word
--------------------------------------------------

monitor : process(clk_i)
    variable word_num : integer := 0;
begin
    if rising_edge(clk_i) then
        if vld_o = '1' and rdy_i = '1' then
            report "Word " & integer'image(word_num)
                 & " -> data=" & integer'image(to_integer(signed(data_o)))
                 & " (0x" & to_hstring(data_o) & ")"
                 & " last=" & std_logic'image(last_o);
            word_num := word_num + 1;
        end if;
    end if;
end process;

end architecture;