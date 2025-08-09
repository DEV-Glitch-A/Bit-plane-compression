library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity zrle is 
    generic(
        N: integer  -- burst length, max length '0' that can be encoded  
        );
    port(
        clk,rst : in std_logic;
        dstream_in : in integer range 0 to 255 ; -----8-bit input
        --conbuff : out std_logic_vector(7 downto 0) ;
        dstream_nxt : out std_logic_vector(15 downto 0);
        symbol_data    : out std_logic_vector(15 downto 0);  -- for bit-packer
        symbol_len     : out integer range 0 to 16;          -- valid bits in symbol_data
        symbol_valid   : out std_logic                       -- 1-cycle pulse when data is valid 
    );
end entity;


architecture runl of zrle is 
     signal conbuff : std_logic_vector(7 downto 0);  -- make it internal

begin
       
    process(clk,rst)
        variable temp_out : std_logic_vector(15 downto 0); -- Output buffer
        variable out_idx  : integer := 0;   ---write pointer
	    variable zero_count : integer range 0 to (2**N)-1 := 0;

    begin
        if rst = '1' then
            zero_count := 0;
            dstream_nxt  <= (others => '0');
            temp_out := (others => '0');
            out_idx     := 0;
        
        elsif (rising_edge(clk)) then
        conbuff <= std_logic_vector(to_unsigned(dstream_in,8));
           temp_out := (others => '0');  -- Important: clear buffer 
           out_idx := 0;                 -- Reset output write index
           zero_count := 0;
            for i in 7 downto 0 loop            
                if conbuff(i) =  '0' then
                    zero_count := zero_count + 1;

                    if (zero_count = 2**N-1) then
                        --temp_out(out_idx) := '0';
                        temp_out(out_idx + N downto out_idx) := '0' & std_logic_vector(to_unsigned(zero_count, N ));
                        out_idx := out_idx + N+1;  ---- updating the write pointer
                        zero_count := 0;
                    end if;
                else 
                     if zero_count > 0 then
                        temp_out(out_idx + N downto out_idx) := '0' & std_logic_vector(to_unsigned(zero_count, N ));
                        out_idx := out_idx + N+1;
                        zero_count := 0;
                    end if;
                    ---write 1
                    temp_out(out_idx) := '1';
                    out_idx := out_idx + 1;
                end if;
            end loop;
            -- Final flush if stream ends in zeros
            if zero_count > 0 then
                temp_out(out_idx + N downto out_idx) :='0' & std_logic_vector(to_unsigned(zero_count, N));
                zero_count := 0;
            end if;
            dstream_nxt <= temp_out;
            if out_idx > 0 then
                symbol_data  <= dstream_nxt;
                symbol_len   <= out_idx;
                symbol_valid <= '1' ;
                else 
                symbol_valid <= '0';
            end if;
	end if;
    end process;
end architecture;