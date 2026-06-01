library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity expander is
  generic (
    -- Data width configuration
    LOG_DATA_W  : natural := 3;                    
    DATA_W      : natural := 8;                    
    BLOCK_SIZE  : natural := 8;                    
    
    -- Encoding prefix constants (5-bit patterns)
    ALL_ONES          : std_logic_vector(4 downto 0) := "00000";
    DBXZ_DBPNZ        : std_logic_vector(4 downto 0) := "00001";
    TWO_ONES_PREFIX   : std_logic_vector(4 downto 0) := "00010";
    SINGLE_ONE_PREFIX : std_logic_vector(4 downto 0) := "00011"
  );
  port (
    data_i    : in  std_logic_vector(DATA_W-1 downto 0);
    zeros_o   : out std_logic_vector(LOG_DATA_W downto 0);
    len_o     : out unsigned(3 downto 0);
    dbx_dbp_o : out std_logic_vector(BLOCK_SIZE-2 downto 0);
    is_dbp_o  : out std_logic
  );
end entity expander;

architecture rtl of expander is

  -- Helper function for ceiling log base 2
  function clog2(n : natural) return natural is
    variable temp : natural := n;
    variable ret  : natural := 0;
  begin
    if n <= 1 then
      return 0;
    end if;
    
    temp := n - 1;
    while temp > 0 loop
      ret  := ret + 1;
      temp := temp / 2;
    end loop;
    return ret;
  end function clog2;

  -- Symbol length constants
  constant LEN_ALL0_DBX       : natural := 2;
  constant LEN_MULTI_ALL0_DBX : natural := 3 + clog2(DATA_W);
  constant LEN_ALL1_DBX       : natural := 6;
  constant LEN_ALL0_DBP       : natural := 5;
  constant LEN_TWO_CONSEC_1S  : natural := 5 + clog2(BLOCK_SIZE-2);
  constant LEN_SINGLE_1       : natural := 5 + clog2(BLOCK_SIZE-1);
  constant LEN_UNCOMPRESSED   : natural := 1 + (BLOCK_SIZE-1);
  
  -- Constants for bit patterns
  constant BLOCK_ZEROS   : std_logic_vector(BLOCK_SIZE-2 downto 0) := (others => '0');
  constant BLOCK_ONES    : std_logic_vector(BLOCK_SIZE-2 downto 0) := (others => '1');
  constant LOG_BLOCKSIZE : natural := clog2(BLOCK_SIZE-1);
  
  -- Internal signals
  signal shift_amount     : unsigned(LOG_BLOCKSIZE-1 downto 0);
  signal prefix_5bit      : std_logic_vector(4 downto 0);
  signal prefix_3bit      : std_logic_vector(2 downto 0);
  signal prefix_2bit      : std_logic_vector(1 downto 0);
  signal zero_run_count   : unsigned(LOG_DATA_W-1 downto 0);
  
  -- Shift patterns
  signal pattern_two_ones : unsigned(BLOCK_SIZE-2 downto 0);
  signal pattern_one_one  : unsigned(BLOCK_SIZE-2 downto 0);


begin

  -- Extract prefixes
  prefix_5bit <= data_i(DATA_W-1 downto DATA_W-5);
  prefix_3bit <= data_i(DATA_W-1 downto DATA_W-3);
  prefix_2bit <= data_i(DATA_W-1 downto DATA_W-2);
  
  -- Extract shift amount
  shift_amount <= unsigned(data_i(DATA_W-6 downto DATA_W-6-LOG_BLOCKSIZE+1));
  
  -- Extract zero run count
  zero_run_count <= unsigned(data_i(DATA_W-4 downto DATA_W-4-LOG_DATA_W+1));
  
  -- Pre-calculate shift patterns
  pattern_two_ones <= shift_right(
                        to_unsigned(3, BLOCK_SIZE-1) sll (BLOCK_SIZE-3),
                        to_integer(shift_amount));
  
  pattern_one_one <= shift_right(
                       to_unsigned(1, BLOCK_SIZE-1) sll (BLOCK_SIZE-2),
                       to_integer(shift_amount));

  -- Main decoder process
  decode_proc : process(data_i, prefix_5bit, prefix_3bit, prefix_2bit, 
                        shift_amount, zero_run_count, 
                        pattern_two_ones, pattern_one_one)
  begin
    -- Default assignments
    zeros_o   <= (others => '0');
    is_dbp_o  <= '0';
    len_o     <= to_unsigned(LEN_UNCOMPRESSED, 4);
    dbx_dbp_o <= BLOCK_ZEROS;
    
    -- Priority decoder based on prefix
    if data_i(DATA_W-1) = '1' then
      -- Uncompressed: 1 + (n-1) bits
      dbx_dbp_o <= data_i(DATA_W-2 downto DATA_W-2-(BLOCK_SIZE-1)+1);
      len_o     <= to_unsigned(LEN_UNCOMPRESSED, 4);
      
    elsif prefix_2bit = "01" then
      -- All-0 DBX: 2 bits
      dbx_dbp_o <= BLOCK_ZEROS;
      len_o     <= to_unsigned(LEN_ALL0_DBX, 4);

    elsif prefix_3bit = "001" then
      zeros_o <= std_logic_vector(zero_run_count + 2);
      len_o   <= to_unsigned(LEN_MULTI_ALL0_DBX, 4);
      dbx_dbp_o <= BLOCK_ZEROS;
      
    elsif prefix_5bit = ALL_ONES then  -- "00000"
      -- All-1 DBX: 5 bits
      dbx_dbp_o <= BLOCK_ONES;
      len_o     <= to_unsigned(LEN_ALL1_DBX, 4);
          
    elsif prefix_5bit = TWO_ONES_PREFIX then  -- "00010"
      -- 2-consecutive 1s: 5 + ⌈log₂(n-2)⌉ bits
      dbx_dbp_o <= std_logic_vector(pattern_two_ones);
      len_o     <= to_unsigned(LEN_TWO_CONSEC_1S, 4);
      
    elsif prefix_5bit = SINGLE_ONE_PREFIX then  -- "00011"
      -- Single-1: 5 + ⌈log₂(n-1)⌉ bits
      dbx_dbp_o <= std_logic_vector(pattern_one_one);
      len_o     <= to_unsigned(LEN_SINGLE_1, 4);
      
    end if;
    
  end process decode_proc;

end architecture rtl;