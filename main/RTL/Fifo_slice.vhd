library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_slice is
  generic (
    type t
  );
  port (
    clk_i  : in  std_logic;
    rst_ni : in  std_logic;

    din_i  : in  t;
    vld_i  : in  std_logic;
    rdy_o  : out std_logic;

    dout_o : out t;
    vld_o  : out std_logic;
    rdy_i  : in  std_logic
  );
end entity fifo_slice;

architecture rtl of fifo_slice is

  type state_t is (empty, full);
  signal state_d, state_q : state_t;

  signal data_d, data_q : t;

begin

  dout_o <= data_q;
  
   fsm : process(all)
  begin
    -- defaults
    vld_o   <= '0';
    rdy_o   <= '0';
    data_d  <= data_q;
    state_d <= state_q;

    case state_q is

      when empty =>
        rdy_o <= '1';
        if vld_i = '1' then
          data_d  <= din_i;
          state_d <= full;
        end if;

      when full =>
        vld_o <= '1';
        if rdy_i = '1' then
          rdy_o <= '1';
          if vld_i = '1' then
            data_d <= din_i;   -- simultaneous pop & push
          else
            state_d <= empty;
          end if;
        end if;

    end case;
  end process;


  seq : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      state_q <= empty;

    elsif rising_edge(clk_i) then
      state_q <= state_d;
      data_q  <= data_d;
    end if;
  end process;


  
end architecture rtl;