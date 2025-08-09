library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bit_packer is
port(
    clk_in,rst_in : in std_logic;
    symbol_data     : in std_logic_vector(7 downto 0);
    symbol_len      : in integer range 0 to 7;
    symbol_valid    : in std_logic;
    data_out : out std_logic_vector( 7 downto 0)
);
end entity;

architecture stimt of bit_packer is

    signal bit_buffer : unsigned(11 downto 0):= (others => '0');
    signal upper_8_bits : std_logic_vector(7 downto 0);
    signal bit_count : integer range 0 to 20:=0;

begin

    
    process(clk_in,rst_in)

        variable shifted_symbol : unsigned(11 downto 0); 
        
    begin
        if rst_in = '1' then
         bit_buffer <= (others => '0');
         bit_count <= 0;
         data_out <= (others => '0');
        
        elsif rising_edge(clk_in) then
         
         if symbol_valid = '1' and symbol_len > 0 then
                shifted_symbol := (resize(unsigned(symbol_data),12)) srl (8 - symbol_len);
                bit_buffer <= shifted_symbol or (bit_buffer sll symbol_len);
                bit_count <= bit_count + symbol_len;
        end if;

        
         if bit_count >= 8 then 
                data_out <= std_logic_vector(bit_buffer(7 downto 0));
                bit_buffer <= bit_buffer srl 8;
                bit_count <= bit_count - 8;
         end if;
       end if;

    end process;

end architecture;
