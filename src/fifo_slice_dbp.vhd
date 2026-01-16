-- FIFO Slice for DBP Block Type
-- Specialized version for dbp_block_t
-- Copyright 2019 ETH Zurich, Lukas Cavigelli and Georg Rutishauser
-- Solderpad Hardware License, Version 0.51

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ebpc_pkg.all;

entity fifo_slice_dbp is
  port (
    clk_i   : in  std_logic;
    rst_ni  : in  std_logic;  -- Active-low reset
    -- Input interface
    din_i   : in  dbp_block_t;
    vld_i   : in  std_logic;
    rdy_o   : out std_logic;
    -- Output interface
    dout_o  : out dbp_block_t;
    vld_o   : out std_logic;
    rdy_i   : in  std_logic
  );
end entity fifo_slice_dbp;

architecture rtl of fifo_slice_dbp is
  
  -- State type
  type state_t is (empty, full);
  
  -- Registers
  signal state_d, state_q : state_t;
  signal data_d, data_q   : dbp_block_t;
  
begin
  
  -- Output assignment
  dout_o <= data_q;
  
  -- FSM combinational logic
  fsm : process(all)
  begin
    -- Default assignments
    vld_o   <= '0';
    rdy_o   <= '0';
    data_d  <= data_q;
    state_d <= state_q;
    
    case state_q is
      
      when empty =>
        rdy_o <= '1';
        if vld_i then
          state_d <= full;
          data_d  <= din_i;
        end if;
      
      when full =>
        vld_o <= '1';
        if rdy_i then
          rdy_o <= '1';
          if vld_i then
            data_d <= din_i;
          else
            state_d <= empty;
          end if;
        end if;
      
    end case;
  end process fsm;
  
  -- Sequential logic with proper record initialization
  sequential : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      state_q <= empty;
      -- Initialize record fields
      for i in 0 to DATA_W loop
        data_q.dbp(i) <= (others => '0');
      end loop;
      data_q.base <= (others => '0');
    elsif rising_edge(clk_i) then
      state_q <= state_d;
      data_q  <= data_d;
    end if;
  end process sequential;
  
end architecture rtl;