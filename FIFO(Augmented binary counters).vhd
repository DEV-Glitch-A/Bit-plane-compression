library ieee;
use ieee.std logic_1164.all;
use ieee.numeric_std.all:

entity fifo_con_and_reg_file is
    generic(
        add_depth : integer; ------ Number of address bits (e.g., 2 for depth 4)
        data_width : integer           -- Width of the data stored in the FIFO
    );
    port(
        clk, reset: in std logic;
        wr, rd: in std_logic;
        mem_data_in : in std_logic_vector(data_width-1 downto 0);
        fifo_data_out : out std_logic_vector (data_width-1 downto 0);
        full, empty: out std logic;
    );
end entity;

architecture rtl of fifo_con_and_reg_file is
    
    constant ptr_width : integer := add_depth + 1; --------for full/empty detection
    constant fifo_width : integer := 2**ADDR_WIDTH;

    type fifo_memory_t is array (0 to FIFO_DEPTH - 1) of std_logic_vector(DATA_WIDTH-1 downto 0);    ----FIFO internal memory

    -----current stage and next stage pointers
    signal w_ptr_reg,w_ptr_next : unsigned(ptr_width-1 downto 0);
    signal r_ptr_reg,r_ptr_next : unsigned (ptr_width-1 downto 0);


      -- Internal addresses derived from current pointers (for RAM access)
    signal w_addr_i : std_logic_vector(add_depth-1 downto 0);
    signal r_addr_i : std_logic_vector(add_depth-1 downto 0);

    -- Internal flags
    signal full_i, empty_i : std_logic;

begin
    process(clk,rst)
    begin
        if (reset = '1') then -- Corrected reset comparison
            w_ptr_reg <= (others => '0');
            r_ptr_reg <= (others => '0');
        elsif (rising_edge(clk))
            w_ptr_reg <= w_ptr_next;
            r_ptr_reg <= r_ptr_next;
        end if;
    end process;

----   -- --- Write Pointer Next-State Logic- ---
    w_ptr_next <= w_ptr_reg + 1 when wr = '1' and full_i = '0' else w_ptr_reg;
 -- --- Read Pointer Next-State Logic ---
    r_ptr_next <= r_ptr_reg + 1 when rd = '1' and empty_i = '0' else r_ptr_reg;
-------full flag logic
    full_i <= '1' when (w_ptr_reg(ptr_width-1)/= r_ptr_reg(ptr_width-1)) and ((w_ptr_reg(add_depth-1 downto 0) = r_ptr_reg(add_depth-1 downto 0))) else 
              '0';

    -- --- Empty Flag Logic ---
    -- Empty when both pointers are exactly the same
    empty_i <= '1' when w_ptr_reg = r_ptr_reg else 
               '0';












end architecture;














entity fifo sync_ctr14 is
    generic(addr_width : integer);
    port(
    
    );
end fifo sync_ctrl4;

architecture enlarged_bin_arch of fifo_sync_ctrl4 is
    constant N: natural: 2;
    signal w_ptr_reg, w_ptr_next: unsigned (N downto 0);
    signal r_ptr_reg, r_ptr_next: unsigned (N downto 0);
    signal full flag, empty_flag: std_logic;

begin

    ----------register
    process (clk,reset)

    begin
        if (reset-'1') then
            w_ptr_reg <= (others=>'0');
            r_ptr_reg <= (others=>'0');
        elsif (clk'event and clk='1') then
            w_ptr_reg <= w_ptr_next;
            r_ptr_reg <= r_ptr_next;
        end if;
    end process;

    -----------write pointer next-state logic
    w_ptr_next <= w_ptr_reg + 1 when wr='1' and full_flag='0' else w_ptr_reg;:
    full flag <='1' when r_ptr_reg(N) /=w_ptr_reg(N) and r_ptr_reg(N-1 downto 0)=w_ptr_reg(N-1 downto 0)
    else '0';

    -------------write port output

    w_addr <= std_logic_vector(w_ptr_reg(N-1 downto 0));
    full <= full_flag;
    -----read pointer next-state logic
    r_ptr_next <=
        r_ptr_reg + 1 when rd='1' and empty_flag='0' else
        r_ptr_reg;
    empty_flag <= '1' when r_ptr_reg=w_ptr_reg else '0';

    ---------read port output

    r_addr <= std_logic_vector(r_ptr_reg(N-1 downto 0));
    empty <= empty_flag;
end enlarged_bin_arch;