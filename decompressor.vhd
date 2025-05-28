library ieee;
use ieee.std_logic_1164.all;

entity encoder is 

    port(clk,rst : in std_logic;
    start_encoding  : in  std_logic;                        -- control signal to intiate encoding
    Original_data : in std_logic_vector(7 downto 0);        -- Data read from memory
    compressed_data : out std_logic_vector(7 downto 0);
    encoding_complete   : out std_logic
    );
end entity;

entity decoder is
    port(clk,rst: in std_logic;
        start_decoding : in std_logic;         ---- control signal to intiate decoding
        compressed_data: in std_logic_vector(7 downto 0);
        Original_data : out std_logic_vector(7 downto 0); ----- data write to memory
        decoder_write_enable  : out std_logic   ----- Enable to write Original_data_out
    );
end entity;