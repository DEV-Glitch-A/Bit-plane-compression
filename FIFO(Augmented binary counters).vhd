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
    constant fifo_width : integer := 2**add_depth;

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

    w_ptr_next <= w_ptr_reg + 1 when wr = '1' and full_i = '0' else w_ptr_reg;     -- --- Write Pointer Next-State Logic
    r_ptr_next <= r_ptr_reg + 1 when rd = '1' and empty_i = '0' else r_ptr_reg;  -------- Read Pointer Next-State Logic

-------full flag logic
    full_i <= '1' when (w_ptr_reg(ptr_width-1)/= r_ptr_reg(ptr_width-1)) and ((w_ptr_reg(add_depth-1 downto 0) = r_ptr_reg(add_depth-1 downto 0))) else 
              '0';

    -- --- Empty Flag Logic ---
    empty_i <= '1' when w_ptr_reg = r_ptr_reg else 
               '0';
-----TO access register file
    w_addr_i <= std_logic_vector(w_ptr_reg(add_depth-1 downto 0));
    r_addr_i <= std_logic_vector(r_ptr_reg(add_depth-1 downto 0));


end architecture;













