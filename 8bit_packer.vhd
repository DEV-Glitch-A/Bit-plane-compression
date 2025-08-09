library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bit_packer is
port(
    clk_in,rst_in : in std_logic;
    symbol_data     : in std_logic_vector(15 downto 0);
    symbol_len      : in integer range 0 to 15;
    symbol_valid    : in std_logic;
    data_out : out std_logic_vector( 7 downto 0)
);
end entity;

architecture stimt of bit_packer is

    
    /*component zrle
        port(
        clk,rst : in std_logic;
        dstream_in : in integer range 0 to 255 ; -----8-bit input
        --conbuff : out std_logic_vector(7 downto 0) ;
        dstream_nxt : out std_logic_vector(15 downto 0);
        symbol_data    : out std_logic_vector(15 downto 0);  -- for bit-packer
        symbol_len     : out integer range 0 to 16;          -- valid bits in symbol_data
        symbol_valid   : out std_logic                       -- 1-cycle pulse when data is valid 
        );
    end component;*/      


    signal bit_buffer : std_logic_vector(23 downto 0);
    signal upper_8_bits : std_logic_vector(7 downto 0);
    signal bit_count : integer range 0 to 23:=0;

begin

    ---- Instantiate the zrle

    
    process(clk_in,rst_in)
        
    begin
        if rst_in = '1' then
         bit_buffer <= (others => '0');
         bit_count <= 0;
         data_out <= (others => '0');
        
        elsif rising_edge(clk_in) then
         
         if symbol_valid = '1' then
            if symbol_len > 0 then
                bit_buffer(bit_buffer'high downto bit_buffer'high - bit_count - symbol_len + 1) <=
                        bit_buffer(bit_buffer'high downto bit_buffer'high - bit_count + 1)
                        & symbol_data(symbol_len - 1 downto 0); -------- shifting
                 bit_buffer(bit_buffer'high - bit_count - symbol_len downto 0) <= (others => '0');
                bit_count <= bit_count + symbol_len;
            end if;
        end if;
         if bit_count >= 8 then 
                data_out <= bit_buffer(bit_buffer'high downto bit_buffer'high -7);
                bit_buffer(bit_buffer'high downto 0) <= (others => '0'); -- Clear entire buffer first
                bit_buffer(bit_buffer'high downto bit_buffer'high - (bit_count - 8) + 1) <= bit_buffer(bit_buffer'high - 8 downto bit_buffer'high - bit_count + 1);
                bit_count <= bit_count - 8;
         end if;
       end if;

    end process;

end architecture;
