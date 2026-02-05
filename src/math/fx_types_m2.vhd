-------------------------------------------------------------------------------
-- fx_types_m2: fixed-point types and common matrices
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fx_types_m2 is
  -- Q4.4: 8-bit signed (1.0 = 16)
  subtype q44_t is signed(7 downto 0);

  -- Q8.8: 16-bit signed (1.0 = 256)
  subtype q88_t is signed(15 downto 0);

  -- Vectors
  type vec8_q44      is array(0 to 7) of q44_t;   -- input features
  type vec8_q88      is array(0 to 7) of q88_t;   -- hidden layer
  type vec4_q88      is array(0 to 3) of q88_t;   -- output layer

  -- Matrices for weights
  type mat8x8_q88    is array(0 to 7, 0 to 7) of q88_t; -- W1: 8x8
  type mat4x8_q88    is array(0 to 3, 0 to 7) of q88_t; -- W2: 4x8

  -- Bias vectors
  type vec8_bias_q88 is array(0 to 7) of q88_t;         -- B1
  type vec4_bias_q88 is array(0 to 3) of q88_t;         -- B2
end package;

package body fx_types_m2 is
end package body;