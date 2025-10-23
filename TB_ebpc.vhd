library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_delta_transformer is
    -- The test bench entity is usually empty
end entity tb_delta_transformer;

architecture test_behavior of tb_delta_transformer is

    -- Component Declaration (Must match your entity)
    component delta_transformer
        port(
            clk           : in std_logic;
            rst           : in std_logic;
            data_streamin : in integer range 0 to 255;
            data_out      : out std_logic_vector (8 downto 0);
            shift_reg     : out std_logic_vector(23 downto 0)
        );
    end component;

    -- Constants for Clock Generation
    constant CLK_PERIOD : time := 10 ns;

    -- Signals for connecting to the Unit Under Test (UUT)
    signal clk_s           : std_logic := '0';
    signal rst_s           : std_logic := '1'; -- Start in reset
    signal data_streamin_s : integer range 0 to 255;
    signal data_out_s      : std_logic_vector (8 downto 0);
    signal shift_reg_s     : std_logic_vector(23 downto 0);


    

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: delta_transformer
        port map(
            clk           => clk_s,
            rst           => rst_s,
            data_streamin => data_streamin_s,
            data_out      => data_out_s,

            shift_reg     => shift_reg_s
        );

    -- 1. Clock Generation Process
    clk_gen: process
    begin
        loop
            clk_s <= '0';
            wait for CLK_PERIOD / 2;
            clk_s <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process clk_gen;

    -- 2. Stimulus Generation Process
    stim_proc: process
    begin
        -- 1. Initial Reset Phase
        rst_s <= '1';
        wait for CLK_PERIOD * 2; -- Hold reset for 2 clock cycles
        rst_s <= '0';
        wait for CLK_PERIOD;

        -- Test Sequence:
        -- Data In (Decimal) | Data In (Signed) | Prev Word (Signed) | Difference (Decimal) | Delta Out
        
        -- State: store_firstword
        -- CLK Cycle 1 (store_firstword state): Store the first word (10)
        data_streamin_s <= 247; -- Decimal 10
        -- data_out should be "00000000" (diff is reset)
        wait for CLK_PERIOD; 
        
        
        -- CLK Cycle 2: Current In (25), Prev Word (10). Delta = 25 - 10 = 15
        data_streamin_s <= 142; -- Decimal 25
        -- data_out should be "00001111" (15)
        -- shift_reg(7 downto 0) should be "00001111"
        wait for CLK_PERIOD;
        
        -- CLK Cycle 3: Current In (20), Prev Word (25). Delta = 20 - 25 = -5
        data_streamin_s <= 8; -- Decimal 20
        -- data_out should be "11111011" (-5 in 2's complement)
        -- shift_reg(15 downto 8) should be "00001111", shift_reg(7 downto 0) should be "11111011"
        wait for CLK_PERIOD;
        
        -- Finish simulation
        wait;
    end process stim_proc;

end architecture test_behavior;