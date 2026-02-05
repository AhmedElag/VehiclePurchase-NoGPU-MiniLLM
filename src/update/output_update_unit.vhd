-------------------------------------------------------------------------------
-- Update unit for output layer 
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fx_types_m2.all;

entity update_unit_m2 is
  port (
    h_in       : in  vec8_q88;

    W2_in      : in  mat4x8_q88;
    B2_in      : in  vec4_bias_q88;

    y_true     : in  std_logic_vector(3 downto 0); -- target one-hot
    y_pred     : in  std_logic_vector(3 downto 0); -- predicted one-hot

    W2_out     : out mat4x8_q88;
    B2_out     : out vec4_bias_q88
  );
end entity;

architecture rtl of update_unit_m2 is
begin
  process (h_in, W2_in, B2_in, y_true, y_pred)
    variable W2v   : mat4x8_q88;
    variable B2v   : vec4_bias_q88;
    variable err_i : integer;
    variable errq  : signed(15 downto 0);   -- Q8.8
    variable prod  : signed(31 downto 0);   -- Q16.16
    variable dw    : signed(15 downto 0);   -- Q8.8
    variable db    : signed(15 downto 0);   -- Q8.8
    constant LR_SHIFT : integer := 2;       -- learning rate ~1/4
  begin
    -- Default: pass through
    for k in 0 to 3 loop
      for i in 0 to 7 loop
        W2v(k,i) := W2_in(k,i);
      end loop;
      B2v(k) := B2_in(k);
    end loop;

    -- For each output neuron get y_pred - y_true
    for k in 0 to 3 loop
      -- error in {-1,0,+1}
      if (y_true(k) = '1') and (y_pred(k) = '0') then
        err_i := 1;
      elsif (y_true(k) = '0') and (y_pred(k) = '1') then
        err_i := -1;
      else
        err_i := 0;
      end if;

      if err_i /= 0 then
        errq := to_signed(err_i * 256, 16); -- ±1.0 in Q8.8

        -- bias delta update: db = err / 4
        db := shift_right(errq, LR_SHIFT);

        -- weight deltas
        for i in 0 to 7 loop
          prod := signed(errq) * signed(h_in(i)); -- Q8.8*Q8.8=Q16.16
          -- Q16.16 -> Q8.8 + LR 1/4 => shift by 8+2 = 10
          dw   := shift_right(prod, 8 + LR_SHIFT)(15 downto 0);

          W2v(k,i) := W2_in(k,i) + dw;  --update weight
        end loop;

        B2v(k) := B2_in(k) + db;  --update bias
      end if;
    end loop;

    W2_out <= W2v;
    B2_out <= B2v;
  end process;
end architecture;