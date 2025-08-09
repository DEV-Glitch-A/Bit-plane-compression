library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_con_and_reg_file is
    generic(
        addr_depth : integer;           --Number of address bits (e.g., 2 for depth 4)
        data_width : integer           -- Width of the data stored in the FIFO(usally 8-bit)
    );
    port(
        clk, reset: in std_logic;
        fifo_data_in : in std_logic_vector(data_width-1 downto 0);
        wr, rd: in std_logic;
        full, empty: out std_logic;
        fifo_data_out : out std_logic_vector (data_width-1 downto 0)
    );
end entity;

architecture rtl of fifo_con_and_reg_file is
    
    constant ptr_width : integer := addr_depth + 1; --------for full/empty detection
    constant fifo_width : integer := 2**addr_depth;

    type fifo_memory_t is array (0 to fifo_width - 1) of std_logic_vector(data_width-1 downto 0);    ----FIFO internal memory
    signal fifo_mem : fifo_memory_t;

    -----current stage and next stage pointers
    signal w_ptr_reg,w_ptr_next : unsigned(ptr_width-1 downto 0);
    signal r_ptr_reg,r_ptr_next : unsigned (ptr_width-1 downto 0);


      -- Internal addresses derived from current pointers (for RAM access)
    --signal w_addr_i : std_logic_vector(addr_depth-1 downto 0);
    --signal r_addr_i : std_logic_vector(addr_depth-1 downto 0);

    -- Internal flags
    signal full_i, empty_i : std_logic;

    signal fifo_data_out_reg : std_logic_vector(data_width-1 downto 0);  -- registered output

begin
    fifo_data_out <= fifo_data_out_reg;
    full <= full_i;
    empty <= empty_i;

    w_ptr_next <= w_ptr_reg + 1 when wr = '1' and full_i = '0' else w_ptr_reg;     -- --- Write Pointer Next-State Logic
    r_ptr_next <= r_ptr_reg + 1 when rd = '1' and empty_i = '0' else r_ptr_reg;  -------- Read Pointer Next-State Logic

-------full flag logic
    full_i <= '1' when (w_ptr_reg(ptr_width-1)/= r_ptr_reg(ptr_width-1)) and ((w_ptr_reg(addr_depth-1 downto 0) = r_ptr_reg(addr_depth-1 downto 0))) else 
              '0';

    -- --- Empty Flag Logic ---
    empty_i <= '1' when w_ptr_reg = r_ptr_reg else 
               '0';
-----TO access register file
    --w_addr_i <= std_logic_vector(w_ptr_reg(addr_depth-1 downto 0));
    --r_addr_i <= std_logic_vector(r_ptr_reg(addr_depth-1 downto 0));

    process(clk,reset)
    begin
        if (reset = '1') then -- Corrected reset comparison
            w_ptr_reg <= (others => '0');
            r_ptr_reg <= (others => '0');
            fifo_data_out_reg<= (others => '0');

        elsif (rising_edge(clk)) then
            --write to fifo
             if (wr = '1' and full_i = '0') then
                fifo_mem(to_integer(w_ptr_reg(addr_depth-1 downto 0))) <= fifo_data_in;
            end if;

            -- Read from FIFO
            if (rd = '1' and empty_i = '0') then
                fifo_data_out_reg <= fifo_mem(to_integer(r_ptr_reg(addr_depth-1 downto 0)));
            end if;

            ---update pointers
            w_ptr_reg <= w_ptr_next;
            r_ptr_reg <= r_ptr_next;
        end if;
    end process;

end architecture;













