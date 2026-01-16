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
    -- BPC input stream (8 bits from diagram)
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
  
  -- Internal shift register (15-bit as shown in diagram for DATA_W=8)
  -- Upper portion goes to output, lower portion for buffering
  signal stream_reg : unsigned(2*DATA_W-1 downto 0);
  signal fill_state : unsigned(LOG_DATA_W downto 0);
  signal state      : state_t;
  
  signal shift_amount : integer range 0 to DATA_W;
  
begin

  -- Output data from upper portion of shift register
  data_o <= std_logic_vector(stream_reg(2*DATA_W-1 downto DATA_W));
  
  -- Fill state output (shown as 15 in diagram)
  fill_state_o <= std_logic_vector(fill_state);
  
  -- Convert length input to integer for shifting
  shift_amount <= to_integer(len_i);
  
  -- Main unpacker process
  process(clk_i, rst_ni)
    variable refill_data : unsigned(2*DATA_W-1 downto 0);
    variable temp_stream_reg : unsigned(2*DATA_W-1 downto 0);
    variable temp_fill_state : unsigned(LOG_DATA_W downto 0);
  begin
    if rst_ni = '0' then
      -- Reset state
      state      <= idle;
      stream_reg <= (others => '0');
      fill_state <= (others => '0');
      
    elsif rising_edge(clk_i) then
      
      -- Initialize temp variables with current values
      temp_stream_reg := stream_reg;
      temp_fill_state := fill_state;
      
      -- Default handshake signals
      rdy_o <= '0';
      vld_o <= '0';
      
      -- Soft clear: reset but allow current cycle to complete
      if clr_i = '1' then
        state      <= idle;
        temp_stream_reg := (others => '0');
        temp_fill_state := (others => '0');
        
      else
        
        case state is
          
          when idle =>
            -- Ready to accept first BPC data
            rdy_o <= '1';
            
            if vld_i = '1' then
              -- Load BPC input into upper register portion
              temp_stream_reg := unsigned(data_i) & to_unsigned(0, DATA_W);
              temp_fill_state := to_unsigned(DATA_W, LOG_DATA_W+1);
              state <= full;
            end if;
          
          when full =>
            -- Valid data available for Symbol Decoder
            vld_o <= '1';
            
            if rdy_i = '1' then
              -- Symbol Decoder accepted data, consume 'len_i' bits
              temp_stream_reg := temp_stream_reg sll shift_amount;
              temp_fill_state := temp_fill_state - shift_amount;
              
              -- Check if buffer needs refill (< DATA_W bits remaining)
              if temp_fill_state < DATA_W then
                rdy_o <= '1';
                
                if vld_i = '1' then
                  -- Immediate refill: merge new data
                  refill_data := (unsigned(data_i) & to_unsigned(0, DATA_W)) srl to_integer(temp_fill_state);
                  temp_stream_reg := temp_stream_reg or refill_data;
                  temp_fill_state := temp_fill_state + DATA_W;
                else
                  -- Wait for refill
                  state <= filling;
                end if;
              end if;
            end if;
          
          when filling =>
            -- Low on data, requesting refill from BPC stream
            rdy_o <= '1';
            
            -- Handle refill first (if new data arrives)
            if vld_i = '1' then
              -- Merge new data at current fill position
              refill_data := (unsigned(data_i) & to_unsigned(0, DATA_W)) srl to_integer(temp_fill_state);
              temp_stream_reg := temp_stream_reg or refill_data;
              temp_fill_state := temp_fill_state + DATA_W;
              state <= full;
            end if;
            
            -- Handle consume (if downstream ready and we have data)
            -- This uses potentially UPDATED temp variables from refill above
            if temp_fill_state /= 0 then
              vld_o <= '1';
              
              if rdy_i = '1' then
                temp_stream_reg := temp_stream_reg sll shift_amount;
                temp_fill_state := temp_fill_state - shift_amount;
              end if;
            end if;
            
        end case;
      end if;
      
      -- Update signals from temp variables (for all paths)
      stream_reg <= temp_stream_reg;
      fill_state <= temp_fill_state;
      
    end if;
  end process;
  
end architecture rtl;
