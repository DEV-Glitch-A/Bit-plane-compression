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
        len_o                   : out unsigned(LOG_DATA_W downto 0);
        push_o                  : out std_logic;
        vld_o                   : out std_logic;

        base_o                  : out std_logic_vector(DATA_W-1 downto 0);
        base_vld_o              : out std_logic;
        is_base_o               : out std_logic;

        -- Handshake
        rdy_i                   : in  std_logic;
        clr_i                   : in  std_logic
    );
end entity symbol_decoder;

architecture rtl of symbol_decoder is

    -------------------------------------
    ---------------------------------------------------------------------------
    signal base_dbp_q, base_dbp_d : std_logic_vector(BLOCK_SIZE-2 downto 0);
    signal base_dbp_loaded_q, base_dbp_loaded_d : std_logic;
    signal first_dbp_q, first_dbp_d : std_logic;

    ---------------------------------------------------------------------------
    -- FSM
    ---------------------------------------------------------------------------
    type state_t is (
    idle,
    base_dbp_load,
    dbx_decode,
    zero_run
    );
    signal state_q, state_d : state_t;

    ---------------------------------------------------------------------------
    -- Counters
    ---------------------------------------------------------------------------
    signal dbx_cnt_q, dbx_cnt_d         : unsigned(LOG_DATA_W downto 0);
    signal zero_cnt_q, zero_cnt_d       : unsigned(LOG_DATA_W-1 downto 0);
    
    ---------------------------------------------------------------------------
    -- Block completion flag to prevent auto-restart
    ---------------------------------------------------------------------------
    signal block_done_q, block_done_d   : std_logic;
    signal dbp_word_cnt_q, dbp_word_cnt_d : unsigned(LOG_DATA_W downto 0);


    ---------------------------------------------------------------------------
    -- DBP register (accumulated XOR)
    ---------------------------------------------------------------------------
    signal dbp_reg_q, dbp_reg_d : std_logic_vector(BLOCK_SIZE-2 downto 0);

    ---------------------------------------------------------------------------
    -- Registered valid
    ---------------------------------------------------------------------------
    signal vld_q, vld_d : std_logic;

    ---------------------------------------------------------------------------
    -- Expander signals
    ---------------------------------------------------------------------------
    signal expander_out     : std_logic_vector(BLOCK_SIZE-2 downto 0);
    signal expander_zeros   : std_logic_vector(LOG_DATA_W downto 0);
    signal expander_len     : unsigned(3 downto 0);
    signal expander_is_dbp  : std_logic;
    signal push_o_temp : std_logic;

begin

    ---------------------------------------------------------------------------
    -- FSM + Datapath
    ---------------------------------------------------------------------------
    fsm : process(all)
        variable accumulated_plane : std_logic_vector(BLOCK_SIZE-2 downto 0);
    begin
        -- =====================================================================
        -- DEFAULTS - SET FIRST
        -- =====================================================================
        data_rdy_o      <= '0';
        push_o          <= '0';
        vld_d           <= '0';
        is_base_o       <= '0';
        base_vld_o      <= '0';
        base_o          <= (others => '0');
        
        state_d         <= state_q;
        block_done_d    <= block_done_q;
        dbx_cnt_d       <= dbx_cnt_q;
        zero_cnt_d      <= zero_cnt_q;
        dbp_word_cnt_d  <= dbp_word_cnt_q;
        dbp_reg_d       <= dbp_reg_q;
        
        len_o           <= expander_len;
        data_o          <= (others => '0');
        
        accumulated_plane := dbp_reg_q xor expander_out;

        -- =====================================================================
        -- FSM CASE STATEMENT
        -- =====================================================================
        case state_q is
            
            -------------------------------------------------------------------
            when idle =>
                data_o <= data_i;
                first_dbp_d <= '1';
                len_o  <= to_unsigned(DATA_W, 4);
                    if unsigned(unpacker_fill_state_i) >= DATA_W then
                        data_rdy_o <= '1';
                        if data_vld_i = '1' then
                            push_o      <= '1';
                            base_o      <= data_i;
                            base_vld_o  <= '1';
                            is_base_o   <= '1';
                            dbp_word_cnt_d <= (others => '0');
                            state_d <= base_dbp_load;
                        end if;
                    end if;
            when base_dbp_load =>

                -- consume 7 bits only
                len_o <= to_unsigned(BLOCK_SIZE-1, len_o'length);

                if unsigned(unpacker_fill_state_i) >= BLOCK_SIZE-1 then

                    data_rdy_o <= '1';

                    if data_vld_i='1' then

                        -- capture BASE_DBP plane
                        dbp_reg_d <= data_i(DATA_W-1 downto 1);

                        push_o <= '1';

                        data_o(DATA_W-1 downto 1)<= data_i(DATA_W-1 downto 1);

                        data_o(0) <= '0';

                        dbp_word_cnt_d <= dbp_word_cnt_q + 1;

                        first_dbp_d <= '0';

                        -- DO NOT let expander use this word
                        state_d <= dbx_decode;

                    end if;

                end if;

            -------------------------------------------------------------------
            when dbx_decode =>

                accumulated_plane := dbp_reg_q xor expander_out;

                data_o(DATA_W-1 downto DATA_W-(BLOCK_SIZE-1))<= accumulated_plane;

                if unsigned(unpacker_fill_state_i) >= expander_len and dbp_word_cnt_q /= 0 then
                    data_rdy_o <= '1';
                    if data_vld_i='1' then
                        dbp_reg_d <= accumulated_plane;
                        push_o <= '1';
                        dbp_word_cnt_d <= dbp_word_cnt_q + 1;
                        -- detect zero run
                        if unsigned(expander_zeros) >= 1 then
                            zero_cnt_d <= unsigned(expander_zeros(LOG_DATA_W-1 downto 0));
                            state_d <= zero_run;
                        end if;

                    end if;

                end if;
            when zero_run =>

                accumulated_plane := dbp_reg_q;

                data_o(DATA_W-1 downto DATA_W-(BLOCK_SIZE-1)) <= accumulated_plane;

                push_o <= '1';          

                dbp_reg_d <= dbp_reg_q;

                if zero_cnt_q > 1 then
                    zero_cnt_d <= zero_cnt_q - 1;
                end if;

                dbp_word_cnt_d <= dbp_word_cnt_q + 1;

                if zero_cnt_q = 1 then
                    state_d <= dbx_decode;
                end if;
        end case;
        -- =====================================================================
        -- END OF DBP BLOCK (REGISTERED VALID)
        -- =====================================================================
        if push_o_temp = '1' and 
           dbp_word_cnt_q = to_unsigned(BLOCK_SIZE, dbp_word_cnt_q'length) then
            len_o          <= to_unsigned(DATA_W, len_o'length);
            vld_d          <= '1';
            dbp_word_cnt_d <= (others => '0');
            dbx_cnt_d      <= (others => '0');
            dbp_reg_d <= (others=>'0');
            base_dbp_loaded_d <= '0';
            zero_cnt_d <= (others=>'0');
            state_d        <= idle;
        end if;

        -- =====================================================================
        -- SOFT CLEAR
        -- =====================================================================
        if clr_i = '1' then
            state_d         <= idle;
            dbx_cnt_d       <= (others => '0');
            zero_cnt_d      <= (others => '0');
            dbp_word_cnt_d  <= (others => '0');
            dbp_reg_d <= (others => '0');
            base_dbp_loaded_d <= '0';
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
            block_done_q    <= '0';
            dbx_cnt_q       <= (others => '0');
            zero_cnt_q      <= (others => '0');
            dbp_word_cnt_q  <= (others => '0');
            dbp_reg_q <= (others=>'0');
            base_dbp_q <= (others=>'0');
            base_dbp_loaded_q <= '0';
            vld_q           <= '0';
       elsif rising_edge(clk_i) then
            state_q <= state_d;
            block_done_q <= block_done_d;
            dbx_cnt_q <= dbx_cnt_d;
            zero_cnt_q <= zero_cnt_d;
            dbp_word_cnt_q <= dbp_word_cnt_d;
            dbp_reg_q <= dbp_reg_d;
            base_dbp_q <= base_dbp_d;
            base_dbp_loaded_q <= base_dbp_loaded_d;
            first_dbp_q <= first_dbp_d;
            vld_q <= vld_d;
            push_o <= push_o_temp;
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
            data_i => data_i,
            zeros_o     => expander_zeros,
            len_o       => expander_len,
            dbx_dbp_o   => expander_out,
            is_dbp_o    => expander_is_dbp
        );

end architecture rtl;