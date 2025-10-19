library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity delta_transformer is
    port(
        clk,rst : in std_logic;
        data_streamin : in integer range 0 to 255;
        data_out : out std_logic_vector (8 downto 0);
   
        shift_reg : out std_logic_vector(23 downto 0)
    );
end entity;


architecture rtl of delta_transformer is

        signal diff : signed (8 downto 0);
        signal base_word_reg : signed(7 downto 0) := (others => '0');
        signal pre_word : signed(7 downto 0); 
        signal shift_reg_int : std_logic_vector(23 downto 0) := (others => '0');

	    type State_Type is (store_firstword, sub_rest);
        signal current_state : State_Type := store_firstword;
        signal con : signed(7 downto 0);

begin 
    con <= to_signed(data_streamin,8); 
    process(clk,rst)
      
    begin
      
        if rst = '1' then
            current_state <= store_firstword; 
            base_word_reg <= (others => '0');
            pre_word       <= (others => '0');
            diff <= (others => '0'); 
            shift_reg_int <= (others=> '0');
        elsif rising_edge(clk) then  
                case current_state is
                    when store_firstword =>
                        base_word_reg <= con;
                        pre_word <= con;
                        diff          <= (others => '0'); 
                        current_state <= sub_rest;
                    when sub_rest => 
                        diff <= resize(con,9) - resize(pre_word,9);
                        pre_word <= con;
                        shift_reg_int <=std_logic_vector(diff(7 downto 0)) & shift_reg(23 downto 8); 
                end case;
        end if;
    end process;
    data_out <= std_logic_vector(diff);
    shift_reg <= shift_reg_int;

end architecture;