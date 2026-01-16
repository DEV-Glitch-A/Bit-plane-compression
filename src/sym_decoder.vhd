--------------------------------------------------------------------------------
-- File: symbol_decoder.vhd
-- Description: Symbol decoder with DBX/DBP support
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity symbol_decoder is
    generic (
        DATA_W      : natural := 8;
        BLOCK_SIZE  : natural := 8;
        LOG_DATA_W  : natural := 3
    );
    port (
        clk_i                   : in  std_logic;
        rst_ni                  : in  std_logic;
        
        -- Input from unpacker
        data_i                  : in  std_logic_vector(DATA_W-1 downto 0);
        unpacker_fill_state_i   : in  std_logic_vector(LOG_DATA_W downto 0);
        data_vld_i              : in  std_logic;
        data_rdy_o              : out std_logic;
        
        -- Output to buffer
        data_o                  : out std_logic_vector(DATA_W-1 downto 0);
        len_o                   : out unsigned(3 downto 0);
        push_o                  : out std_logic;
        vld_o                   : out std_logic;
        
        -- Handshake
        rdy_i                   : in  std_logic;
        clr_i                   : in  std_logic
    );
end entity symbol_decoder;

architecture rtl of symbol_decoder is

    ---------------------------------------------------------------------------
    -- FSM
    ---------------------------------------------------------------------------
    type state_t is (idle, dbx_decode, zeros);
    signal state_q, state_d : state_t;

    ---------------------------------------------------------------------------
    -- Counters
    ---------------------------------------------------------------------------
    signal dbx_cnt_q, dbx_cnt_d         : unsigned(LOG_DATA_W downto 0);
    signal zero_cnt_q, zero_cnt_d       : unsigned(LOG_DATA_W-1 downto 0);
    
    -- DBP word counter (BLOCK_SIZE-1 words per block)
    signal dbp_word_cnt_q, dbp_word_cnt_d : unsigned(LOG_DATA_W downto 0);

    ---------------------------------------------------------------------------
    -- DBP register
    ---------------------------------------------------------------------------
    signal dbp_reg_q, dbp_reg_d : std_logic_vector(BLOCK_SIZE-2 downto 0);

    ---------------------------------------------------------------------------
    -- Registered valid (CRITICAL FIX)
    ---------------------------------------------------------------------------
    signal vld_q, vld_d : std_logic;

    ---------------------------------------------------------------------------
    -- Expander signals
    ---------------------------------------------------------------------------
    signal expander_out     : std_logic_vector(BLOCK_SIZE-2 downto 0);
    signal expander_zeros   : std_logic_vector(LOG_DATA_W downto 0);
    signal expander_len     : unsigned(3 downto 0);
    signal expander_is_dbp  : std_logic;

begin

    ---------------------------------------------------------------------------
    -- FSM + Datapath
    ---------------------------------------------------------------------------
    fsm : process(all)
    begin
        -- Defaults
        data_rdy_o      <= '0';
        push_o          <= '0';
        vld_d           <= '0';
        state_d         <= state_q;
        dbx_cnt_d       <= dbx_cnt_q;
        zero_cnt_d      <= zero_cnt_q;
        dbp_word_cnt_d  <= dbp_word_cnt_q;
        dbp_reg_d       <= dbp_reg_q;
        len_o           <= expander_len;
        data_o          <= expander_out & '0' ;

        case state_q is
            -------------------------------------------------------------------
            when idle =>
                data_o <= data_i;
                len_o  <= to_unsigned(DATA_W, 4);
                
                if unsigned(unpacker_fill_state_i) >= DATA_W then
                    data_rdy_o <= '1';
                    
                    if data_vld_i = '1' then
                        push_o          <= '1';
                        dbp_word_cnt_d  <= (others => '0');
                        state_d         <= dbx_decode;
                    end if;
                end if;

            -------------------------------------------------------------------
            when dbx_decode =>
                if unsigned(unpacker_fill_state_i) >= expander_len then
                    data_rdy_o <= '1';
                    
                    if data_vld_i = '1' then
                        push_o      <= '1';
                        dbx_cnt_d   <= dbx_cnt_q + 1;
                        
                        if expander_is_dbp = '1' then
                            dbp_reg_d <= expander_out;
                        else
                            dbp_reg_d <= dbp_reg_q xor expander_out;
                        end if;
                        
                        if unsigned(expander_zeros) /= 0 then
                            zero_cnt_d  <= unsigned(expander_zeros(LOG_DATA_W-1 downto 0)) - 1;
                            state_d     <= zeros;
                            data_rdy_o  <= '0';
                        end if;
                    end if;
                end if;

            -------------------------------------------------------------------
            when zeros =>
                push_o      <= '1';
                dbx_cnt_d   <= dbx_cnt_q + 1;
                
                if zero_cnt_q = 0 then
                    data_rdy_o  <= '1';
                    state_d     <= dbx_decode;
                else
                    zero_cnt_d  <= zero_cnt_q - 1;
                end if;

        end case;

        -----------------------------------------------------------------------
        -- DBP word counting (ETH contract)
        -----------------------------------------------------------------------
        if push_o = '1' then
            dbp_word_cnt_d <= dbp_word_cnt_q + 1;
        end if;

        -----------------------------------------------------------------------
        -- END OF DBP BLOCK (REGISTERED VALID)
        -----------------------------------------------------------------------
        if push_o = '1' and 
           dbp_word_cnt_q = to_unsigned(DATA_W-2, dbp_word_cnt_q'length) then
            len_o          <= to_unsigned(DATA_W, len_o'length);
            vld_d           <= '1';
            dbp_word_cnt_d  <= (others => '0');
            dbx_cnt_d       <= (others => '0');
            dbp_reg_d       <= (others => '0');
            state_d         <= idle;
        end if;

        -----------------------------------------------------------------------
        -- Soft clear
        -----------------------------------------------------------------------
        if clr_i = '1' then
            state_d         <= idle;
            dbx_cnt_d       <= (others => '0');
            zero_cnt_d      <= (others => '0');
            dbp_word_cnt_d  <= (others => '0');
            dbp_reg_d       <= (others => '0');
            vld_d           <= '0';
        end if;

    end process fsm;

    ---------------------------------------------------------------------------
    -- Registers
    ---------------------------------------------------------------------------
    regs : process(clk_i, rst_ni)
    begin
        if rst_ni = '0' then
            state_q         <= idle;
            dbx_cnt_q       <= (others => '0');
            zero_cnt_q      <= (others => '0');
            dbp_word_cnt_q  <= (others => '0');
            dbp_reg_q       <= (others => '0');
            vld_q           <= '0';
        elsif rising_edge(clk_i) then
            state_q         <= state_d;
            dbx_cnt_q       <= dbx_cnt_d;
            zero_cnt_q      <= zero_cnt_d;
            dbp_word_cnt_q  <= dbp_word_cnt_d;
            dbp_reg_q       <= dbp_reg_d;
            vld_q           <= vld_d;
        end if;
    end process regs;

    ---------------------------------------------------------------------------
    -- Outputs
    ---------------------------------------------------------------------------
    vld_o <= vld_q;

    ---------------------------------------------------------------------------
    -- Expander instantiation
    ---------------------------------------------------------------------------
    expander_i : entity work.expander
        generic map (
            DATA_W      => DATA_W,
            BLOCK_SIZE  => BLOCK_SIZE,
            LOG_DATA_W  => LOG_DATA_W
        )
        port map (
            data_i      => data_i,
            zeros_o     => expander_zeros,
            len_o       => expander_len,
            dbx_dbp_o   => expander_out,
            is_dbp_o    => expander_is_dbp
        );

end architecture rtl;