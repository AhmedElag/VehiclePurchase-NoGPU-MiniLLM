-------------------------------------------------------------------------------
-- Update unit for hidden layer (perceptron-style on W1/B1)
-- Compute a simple "global" error sign from output layer:
-- If the correct class is off but should be on → err_i = +1 (we need more activation)
-- If a wrong class is on when it should be off → err_i = -1 (we need less activation)
-- If everything matches → err_i stays 0 (no update)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fx_types_m2.all;

entity update_unit_w1 is
  port (
    x_in    : in  vec8_q44;         -- input features (Q4.4)
    W1_in   : in  mat8x8_q88;       -- current hidden weights
    B1_in   : in  vec8_bias_q88;    -- current hidden biases

    y_true  : in  std_logic_vector(3 downto 0); -- target one-hot
    y_pred  : in  std_logic_vector(3 downto 0); -- predicted one-hot

    W1_out  : out mat8x8_q88;       -- updated hidden weights
    B1_out  : out vec8_bias_q88     -- updated hidden biases
  );
end entity;

architecture rtl of update_unit_w1 is
begin
  process (x_in, W1_in, B1_in, y_true, y_pred)
    variable W1v   : mat8x8_q88;
    variable B1v   : vec8_bias_q88;

    variable err_i : integer;
    variable errq  : signed(15 downto 0);   -- Q8.8
    variable xq88  : signed(15 downto 0);   -- Q8.8 (from Q4.4)
    variable prod  : signed(31 downto 0);   -- Q16.16
    variable dw    : signed(15 downto 0);   -- Q8.8
    variable db    : signed(15 downto 0);   -- Q8.8

    constant LR_SHIFT : integer := 3;       -- learning rate ~1/8
  begin
    -- Default: pass-through
    for i in 0 to 7 loop
      for j in 0 to 7 loop
        W1v(i,j) := W1_in(i,j);
      end loop;
      B1v(i) := B1_in(i);
    end loop;

    ----------------------------------------------------------------
    -- Compute a simple "global" error sign from output layer
    ----------------------------------------------------------------
    err_i := 0;
    for k in 0 to 3 loop
      if (y_true(k) = '1') and (y_pred(k) = '0') then
        err_i := 1;
      elsif (y_true(k) = '0') and (y_pred(k) = '1') then
        err_i := -1;
      end if;
    end loop;

    if err_i /= 0 then
      errq := to_signed(err_i * 256, 16); -- ±1.0 in Q8.8
      db   := shift_right(errq, LR_SHIFT);

      ----------------------------------------------------------------
      -- Update only hidden neurons 0..3 tied to each class.
      ----------------------------------------------------------------
      for i in 0 to 7 loop
        if (i <= 3) and (y_true(i) = '1') then
          -- Bias update
          B1v(i) := B1_in(i) + db;

          -- Weight updates for row i
          for j in 0 to 7 loop
            -- Promote x_in(j) from Q4.4 (8-bit) to Q8.8 (16-bit)
            xq88 := shift_left(resize(x_in(j), 16), 4); -- *16

            prod := errq * xq88; -- Q8.8 * Q8.8 = Q16.16

            -- Q16.16 -> Q8.8 with LR 1/8 => shift by 8+3 = 11
            dw   := shift_right(prod, 8 + LR_SHIFT)(15 downto 0);

            W1v(i,j) := W1_in(i,j) + dw;
          end loop;
        end if;
      end loop;
    end if;

    W1_out <= W1v;
    B1_out <= B1v;
  end process;
end architecture;