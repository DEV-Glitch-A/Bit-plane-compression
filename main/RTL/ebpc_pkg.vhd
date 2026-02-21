library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ebpc_pkg is

  ---------------------------------------------------------------------------
  -- Constants
  ---------------------------------------------------------------------------
  constant LOG_DATA_W   : positive := 3;
  constant DATA_W       : positive := 2**LOG_DATA_W;
  constant BLOCK_SIZE   : positive := 8;

  ---------------------------------------------------------------------------
  -- DBP types
  ---------------------------------------------------------------------------
  type dbp_array_t is array (0 to DATA_W) of std_logic_vector(BLOCK_SIZE-2 downto 0);

  type dbp_block_t is record
    dbp  : dbp_array_t;
    base : signed(DATA_W-1 downto 0);
  end record;

  ---------------------------------------------------------------------------
  -- Flattened DBP block width
  ---------------------------------------------------------------------------
  constant DBP_BLOCK_W : natural :=
    DATA_W + (DATA_W + 1) * (BLOCK_SIZE - 1);

  ---------------------------------------------------------------------------
  -- Function declarations (PROTOTYPES ONLY)
  ---------------------------------------------------------------------------
  function pack_dbp(b : dbp_block_t) return std_logic_vector;
  function unpack_dbp(v : std_logic_vector) return dbp_block_t;

  -- ✅ ADD THIS LINE (declaration only!)
  function clog2(n : natural) return natural;

end package ebpc_pkg;
package body ebpc_pkg is

  ---------------------------------------------------------------------------
  -- Ceiling log2
  ---------------------------------------------------------------------------
  function clog2(n : natural) return natural is
    variable r : natural := 0;
    variable v : natural := n - 1;
  begin
    if n <= 1 then
      return 1;
    end if;

    while v > 0 loop
      r := r + 1;
      v := v / 2;
    end loop;

    return r;
  end function clog2;

  ---------------------------------------------------------------------------
  -- Pack DBP block into std_logic_vector
  ---------------------------------------------------------------------------
  function pack_dbp(b : dbp_block_t) return std_logic_vector is
    variable v   : std_logic_vector(DBP_BLOCK_W-1 downto 0);
    variable idx : integer := DBP_BLOCK_W-1;
  begin
    -- Base (MSBs)
    v(idx downto idx-DATA_W+1) := std_logic_vector(b.base);
    idx := idx - DATA_W;

    -- Bit-planes
    for i in 0 to DATA_W loop
      v(idx downto idx-(BLOCK_SIZE-2)) := b.dbp(i);
      idx := idx - (BLOCK_SIZE-1);
    end loop;

    return v;
  end function pack_dbp;

  ---------------------------------------------------------------------------
  -- Unpack std_logic_vector into DBP block
  ---------------------------------------------------------------------------
  function unpack_dbp(v : std_logic_vector) return dbp_block_t is
    variable b   : dbp_block_t;
    variable idx : integer := DBP_BLOCK_W-1;
  begin
    -- Base
    b.base := signed(v(idx downto idx-DATA_W+1));
    idx := idx - DATA_W;

    -- Bit-planes
    for i in 0 to DATA_W loop
      b.dbp(i) := v(idx downto idx-(BLOCK_SIZE-2));
      idx := idx - (BLOCK_SIZE-1);
    end loop;

    return b;
  end function unpack_dbp;

end package body ebpc_pkg;
