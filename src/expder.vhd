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
    len_o     : out unsigned(3 downto 0);  -- Actual bit length consumed (2 to 8 for default config)
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

  -- Symbol length constants (actual bit counts based on table)
  constant LEN_ALL0_DBX       : natural := 2;                        -- all-0 DBX: 2 bits
  constant LEN_MULTI_ALL0_DBX : natural := 3 + clog2(DATA_W);        -- multi-all-0 DBX: 3 + ⌈log₂(m)⌉
  constant LEN_ALL1_DBX       : natural := 5;                        -- all-1 DBX: 5 bits
  constant LEN_ALL0_DBP       : natural := 5;                        -- all-0 DBP: 5 bits
  constant LEN_TWO_CONSEC_1S  : natural := 5 + clog2(BLOCK_SIZE-2);  -- 2-consec 1s: 5 + ⌈log₂(n-2)⌉
  constant LEN_SINGLE_1       : natural := 5 + clog2(BLOCK_SIZE-1);  -- single-1: 5 + ⌈log₂(n-1)⌉
  constant LEN_UNCOMPRESSED   : natural := 1 + (BLOCK_SIZE-1);       -- uncompressed: 1 + (n-1)
  
  -- Constants for bit patterns
  constant BLOCK_ZEROS   : std_logic_vector(BLOCK_SIZE-2 downto 0) := (others => '0');
  constant BLOCK_ONES    : std_logic_vector(BLOCK_SIZE-2 downto 0) := (others => '1');
  constant LOG_BLOCKSIZE : natural := clog2(BLOCK_SIZE-1);
  
  -- Internal signals for cleaner code
  signal shift_amount     : unsigned(LOG_BLOCKSIZE-1 downto 0);
  signal prefix_5bit      : std_logic_vector(4 downto 0);
  signal prefix_3bit      : std_logic_vector(2 downto 0);
  signal prefix_2bit      : std_logic_vector(1 downto 0);
  signal zero_run_count   : unsigned(LOG_DATA_W-1 downto 0);
  
  -- Shift patterns
  signal pattern_two_ones : unsigned(BLOCK_SIZE-2 downto 0);
  signal pattern_one_one  : unsigned(BLOCK_SIZE-2 downto 0);

begin

  -- Extract prefixes for cleaner code
  prefix_5bit <= data_i(DATA_W-1 downto DATA_W-5);
  prefix_3bit <= data_i(DATA_W-1 downto DATA_W-3);
  prefix_2bit <= data_i(DATA_W-1 downto DATA_W-2);
  
  -- Extract shift amount (used in multiple conditions)
  shift_amount <= unsigned(data_i(DATA_W-6 downto DATA_W-6-LOG_BLOCKSIZE+1));
  
  -- Extract zero run count
  zero_run_count <= unsigned(data_i(DATA_W-4 downto DATA_W-4-LOG_DATA_W+1));
  
  -- Pre-calculate shift patterns
  -- Pattern: "11000..." = decimal 3 shifted left then right by shift_amount
  pattern_two_ones <= shift_right(
                        to_unsigned(3, BLOCK_SIZE-1) sll (BLOCK_SIZE-3),
                        to_integer(shift_amount));
  
  -- Pattern: "10000..." = decimal 1 shifted left then right by shift_amount
  pattern_one_one <= shift_right(
                       to_unsigned(1, BLOCK_SIZE-1) sll (BLOCK_SIZE-2),
                       to_integer(shift_amount));

  -- Main decoder process
  -- Decodes according to Symbol Encoding Table (a)
  decode_proc : process(data_i, prefix_5bit, prefix_3bit, prefix_2bit, 
                        shift_amount, zero_run_count, 
                        pattern_two_ones, pattern_one_one)
  begin
    -- Default assignments (prevents latches)
    zeros_o   <= (others => '0');
    is_dbp_o  <= '0';
    len_o     <= to_unsigned(LEN_UNCOMPRESSED, 4);
    dbx_dbp_o <= BLOCK_ZEROS;
    
    -- Priority decoder based on prefix (matches table order)
    -- Check longest prefixes first to ensure correct decoding
    
    if data_i(DATA_W-1) = '1' then
      -- uncompressed: 1 + (n-1) bits, Code: 1 & to_bin(DBX word)
      -- Extract BLOCK_SIZE-1 bits of literal data from input
      dbx_dbp_o <= data_i(DATA_W-2 downto DATA_W-2-(BLOCK_SIZE-1)+1);
      len_o     <= to_unsigned(LEN_UNCOMPRESSED, 4);
      
    elsif prefix_2bit = "01" then
      -- all-0 DBX: 2 bits, Code: 01
      dbx_dbp_o <= BLOCK_ZEROS;
      len_o     <= to_unsigned(LEN_ALL0_DBX, 4);
      
    elsif prefix_3bit = "001" then
      -- multi-all-0 DBX: 3 + ⌈log₂(m)⌉ bits, Code: 001 & to_bin(runLength-2)
      -- Encodes multiple consecutive zero blocks
      dbx_dbp_o <= BLOCK_ZEROS;
      len_o     <= to_unsigned(LEN_MULTI_ALL0_DBX, 4);
      zeros_o   <= std_logic_vector(resize(zero_run_count + 1, LOG_DATA_W+1));
      
    elsif prefix_5bit = ALL_ONES then  -- "00000"
      -- all-1 DBX: 5 bits, Code: 00000
      dbx_dbp_o <= BLOCK_ONES;
      len_o     <= to_unsigned(LEN_ALL1_DBX, 4);
      
    elsif prefix_5bit = DBXZ_DBPNZ then  -- "00001"
      -- all-0 DBP: 5 bits, Code: 00001
      dbx_dbp_o <= BLOCK_ZEROS;
      len_o     <= to_unsigned(LEN_ALL0_DBP, 4);
      is_dbp_o  <= '0';
      
    elsif prefix_5bit = TWO_ONES_PREFIX then  -- "00010"
      -- 2-consec 1s: 5 + ⌈log₂(n-2)⌉ bits, Code: 00010 & to_bin(posOfFirstOne)
      -- Pattern: "11000..." shifted right by encoded position
      dbx_dbp_o <= std_logic_vector(pattern_two_ones);
      len_o     <= to_unsigned(LEN_TWO_CONSEC_1S, 4);
      
    elsif prefix_5bit = SINGLE_ONE_PREFIX then  -- "00011"
      -- single-1: 5 + ⌈log₂(n-1)⌉ bits, Code: 00011 & to_bin(posOfOne)
      -- Pattern: "10000..." shifted right by encoded position
      dbx_dbp_o <= std_logic_vector(pattern_one_one);
      len_o     <= to_unsigned(LEN_SINGLE_1, 4);
      
    end if;
    
  end process decode_proc;

end architecture rtl;