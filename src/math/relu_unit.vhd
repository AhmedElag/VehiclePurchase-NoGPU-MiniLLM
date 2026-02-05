-------------------------------------------------------------------------------
-- ReLU unit: max(0,x)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fx_types_m2.all;

entity relu_unit is
  port (
    x : in  q88_t;   -- Q8.8
    y : out q88_t    -- Q8.8
  );
end entity;

architecture rtl of relu_unit is
begin
  -- If x < 0, output 0; else pass x through
  y <= (others => '0') when x(15) = '1' else x;
end architecture;