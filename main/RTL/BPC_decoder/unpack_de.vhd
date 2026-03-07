library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity unpacker is
generic(
  DATA_W: positive:=8;
  LOG_DATA_W: positive := 3
);
  port (
    clk_i        : in  std_logic;
    rst_ni       : in  std_logic;
    
    -- BPC input stream
    data_i       : in  std_logic_vector(DATA_W-1 downto 0);
    vld_i        : in  std_logic;
    rdy_o        : out std_logic;
    
    -- Output to Symbol Decoder
    data_o       : out std_logic_vector(DATA_W-1 downto 0);
    fill_state_o : out std_logic_vector(LOG_DATA_W downto 0);
    
    -- Length from Symbol Decoder (feedback)
    len_i        : in  unsigned(LOG_DATA_W downto 0);
    vld_o        : out std_logic;
    rdy_i        : in  std_logic;
    clr_i        : in  std_logic
  );
end entity unpacker;

architecture rtl of unpacker is
  
  type state_t is (idle, full, filling);
  
  signal stream_reg_d, stream_reg_q : unsigned(2*DATA_W-1 downto 0);
  signal fill_state_d, fill_state_q : unsigned(LOG_DATA_W downto 0);
  signal state_d, state_q : state_t;
  
begin

  -- Output data from upper portion of shift register
  data_o <= std_logic_vector(stream_reg_q(2*DATA_W-1 downto DATA_W));
  
  -- Fill state output
  fill_state_o <= std_logic_vector(fill_state_q);
  
  ---------------------------------------------------------------------------
  -- Combinational FSM - EXACTLY matches SystemVerilog semantics
  ---------------------------------------------------------------------------
  fsm_comb : process(all)
    variable shift : integer range 0 to 2*DATA_W;
    variable next_stream_reg : unsigned(2*DATA_W-1 downto 0);
    variable next_fill_state : unsigned(LOG_DATA_W downto 0);
  begin
    -- Defaults
    shift := to_integer(len_i);
    stream_reg_d <= stream_reg_q;
    fill_state_d <= fill_state_q;
    rdy_o <= '0';
    vld_o <= '0';
    state_d <= state_q;
    
    -- Soft clear
    if clr_i = '1' then
      rdy_o <= '0';
      stream_reg_d <= (others => '0');
      fill_state_d <= (others => '0');
      state_d <= idle;
      
    else
      case state_q is
        
        when idle =>
          rdy_o <= '1';
          
          if vld_i = '1' then
            fill_state_d <= to_unsigned(DATA_W, LOG_DATA_W+1);
            stream_reg_d <= unsigned(data_i) & to_unsigned(0, DATA_W);
            state_d <= full;
          end if;
        
        when full =>
          vld_o <= '1';
              report "UNPACKER full: fill_state=" & integer'image(to_integer(fill_state_q)) &
           " rdy_i=" & std_logic'image(rdy_i) &
           " data_o=" & to_hstring(data_o)
           severity note;
          
          if rdy_i = '1' then
            stream_reg_d <= stream_reg_q sll shift ;
            fill_state_d <= fill_state_q - shift;
            
            if (fill_state_q - shift) < DATA_W then
              rdy_o <= '1';
              
              if vld_i = '1' then
                -- Refill: use the UPDATED fill_state (fill_state_q - shift)
                stream_reg_d <= (stream_reg_q sll shift) or 
                                ((unsigned(data_i) & to_unsigned(0, DATA_W)) srl to_integer(fill_state_q - shift));
                fill_state_d <= (fill_state_q - shift) + DATA_W;
              else
                state_d <= filling;
              end if;
            end if;
          end if;
        
        when filling =>
          rdy_o <= '1';
          
          -- Only handle refill in filling state - do NOT output data
          next_stream_reg := stream_reg_q;
          next_fill_state := fill_state_q;
          
          -- Wait for new data to arrive
          if vld_i = '1' then
            state_d <= full;
            next_stream_reg := next_stream_reg or 
                              ((unsigned(data_i) & to_unsigned(0, DATA_W)) srl to_integer(next_fill_state));
            next_fill_state := next_fill_state + DATA_W;
            --  Only assert vld_o when transitioning back to full
            vld_o <= '1';
          end if;
          
          --  Do NOT output data while in filling state
          -- The decoder should stop requesting when fill_state < required length
          
          stream_reg_d <= next_stream_reg;
          fill_state_d <= next_fill_state;
          
      end case;
    end if;
    
  end process fsm_comb;
  
  ---------------------------------------------------------------------------
  -- Sequential process
  ---------------------------------------------------------------------------
  fsm_seq : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      state_q      <= idle;
      stream_reg_q <= (others => '0');
      fill_state_q <= (others => '0');
    elsif rising_edge(clk_i) then
      state_q      <= state_d;
      stream_reg_q <= stream_reg_d;
      fill_state_q <= fill_state_d;
    end if;
  end process fsm_seq;
  
end architecture rtl;