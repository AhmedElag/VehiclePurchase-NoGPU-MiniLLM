-------------------------------------------------------------------------------
-- Forward Pass
-- Computes the hidden layer
-- Applies ReLU
-- Selects the predicted class using argmax
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fx_types_m2.all;

entity forward_net is
  port (
    x_in    : in  vec8_q44;
    W1      : in  mat8x8_q88;
    B1      : in  vec8_bias_q88;
    W2      : in  mat4x8_q88;
    B2      : in  vec4_bias_q88;

    h_out   : out vec8_q88;                     -- hidden activations (after ReLU)
    y_raw   : out vec4_q88;                     -- raw outputs (Q8.8)
    y_1hot  : out std_logic_vector(3 downto 0)  -- one-hot of argmax
  );
end entity;

architecture rtl of forward_net is
  -- internal signals
  signal h_pre_s  : vec8_q88;  -- before ReLU
  signal h_int_s  : vec8_q88;  -- after ReLU
  signal y_int_s  : vec4_q88;  -- internal raw outputs
begin
  --------------------------------------------------------------------
  -- Hidden layer: 
  -- weight × input for each hidden neuron
  -- h_pre[i] = sum_j W1[i,j] * x[j] + B1[i]
  -- W1: Q8.8 (16 bits)
  -- x : Q4.4 (8 bits, extended to 16)
  -- W1*x: Q8.8 * Q4.4 -> Q12.12 (32 bits)
  -- acc: Q12.12
  -- final: shift_right(acc, 4) -> Q8.8
  --------------------------------------------------------------------
  hidden_calc : process (x_in, W1, B1)
    variable acc  : signed(31 downto 0); -- Q12.12
    variable prod : signed(31 downto 0);
  begin
    for i in 0 to 7 loop
      acc := shift_left(resize(B1(i), 32), 4); -- bias promoted

      for j in 0 to 7 loop
        prod := signed(W1(i,j)) * resize(signed(x_in(j)), 16);
        acc  := acc + prod;
      end loop;

      h_pre_s(i) <= resize(shift_right(acc, 4), 16);
    end loop;
  end process;

  --------------------------------------------------------------------
  -- ReLU on hidden layer: h_int_s
  --------------------------------------------------------------------
  gen_relu : for i in 0 to 7 generate
  begin
    HRELU : entity work.relu_unit
      port map (
        x => h_pre_s(i),
        y => h_int_s(i)
      );
  end generate;

  --------------------------------------------------------------------
  -- Output layer: y_int_s[k] = sum_i W2[k,i] * h_int_s[i] + B2[k]
  -- W2,h: Q8.8 * Q8.8 -> Q16.16 (32 bits)
  -- acc: Q16.16
  -- final: shift_right(acc, 8) -> Q8.8
  --------------------------------------------------------------------
  output_calc : process (h_int_s, W2, B2)
    variable acc  : signed(31 downto 0); -- Q16.16
    variable prod : signed(31 downto 0);
  begin
    for k in 0 to 3 loop
      acc := shift_left(resize(B2(k), 32), 8);

      for i in 0 to 7 loop
        prod := signed(W2(k,i)) * signed(h_int_s(i));
        acc  := acc + prod;
      end loop;

      y_int_s(k) <= resize(shift_right(acc, 8), 16);
    end loop;
  end process;

  --------------------------------------------------------------------
  -- Argmax on internal y_int_s
  --------------------------------------------------------------------
  U_ARGMAX : entity work.argmax4
    port map (
      y_in      => y_int_s,
      pred_idx  => open,
      pred_1hot => y_1hot
    );

  --------------------------------------------------------------------
  -- Drive OUT ports from internal signals
  --------------------------------------------------------------------
  h_out <= h_int_s;
  y_raw <= y_int_s;
end architecture;