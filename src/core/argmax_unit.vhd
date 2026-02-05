-------------------------------------------------------------------------------
-- Argmax over 4 Q8.8 values
-- decides which output class the neural network is predicting
-- Finds the index of the largest value and converts
-- that index into a one-hot vector
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fx_types_m2.all;

entity argmax4 is
  port (
    y_in      : in  vec4_q88;                  -- 4 Q8.8 values
    pred_idx  : out unsigned(1 downto 0);      -- index 0..3
    pred_1hot : out std_logic_vector(3 downto 0)  -- one-hot
  );
end entity;

architecture rtl of argmax4 is
begin
  process (y_in)
    variable max_val : q88_t;
    variable max_idx : integer range 0 to 3;
  begin
    --find index of max val
    max_val := y_in(0);
    max_idx := 0;
    for k in 1 to 3 loop
      if y_in(k) > max_val then
        max_val := y_in(k);
        max_idx := k;
      end if;
    end loop;

    pred_idx <= to_unsigned(max_idx, 2);
    --map index to labels
    case max_idx is
      when 0 => pred_1hot <= "0001";
      when 1 => pred_1hot <= "0010";
      when 2 => pred_1hot <= "0100";
      when others => pred_1hot <= "1000"; 
    end case;
  end process;
end architecture;