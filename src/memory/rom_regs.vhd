-------------------------------------------------------------------------------
-- ROM + registers: dataset & weights
--  - Stores training and validation datasets (X and Y)
--  - Stores trainable weights and biases for both layers
--  - Logs weight updates in decimal (Q8.8 -> value/256.0)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fx_types_m2.all;

library std;
use std.textio.all;

entity rom_regs_m2 is
  generic (
    N_TRAIN : integer := 4;
    N_VALID : integer := 2
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;

    sel_valid : in  std_logic;  -- 0 = training set, 1 = validation set
    idx_tr    : in  unsigned(7 downto 0);
    idx_va    : in  unsigned(7 downto 0);

    x_out     : out vec8_q44;               -- input features (Q4.4)
    y_out     : out std_logic_vector(3 downto 0); -- one-hot label

    -- Hidden layer write + inputs
    w1_we     : in  std_logic;
    W1_in     : in  mat8x8_q88;
    B1_in     : in  vec8_bias_q88;

    -- Output layer write + inputs
    w2_we     : in  std_logic;
    W2_in     : in  mat4x8_q88;
    B2_in     : in  vec4_bias_q88;

    -- Current weights (fed into forward_net)
    W2_out    : out mat4x8_q88;
    B2_out    : out vec4_bias_q88;

    W1_out    : out mat8x8_q88;
    B1_out    : out vec8_bias_q88
  );
end entity;

architecture rtl of rom_regs_m2 is

  ---------------------------------------------------------------------------
  -- Basic fixed-point constants for inputs
  ---------------------------------------------------------------------------
  constant ONE_Q44  : q44_t := to_signed(16, 8);  -- 1.0 in Q4.4
  constant ZERO_Q44 : q44_t := to_signed(0,  8);  -- 0.0 in Q4.4

  ---------------------------------------------------------------------------
  -- DATASET
  -- We use 4 “mood” sentences, encoded as one-hot features on x(0..3)
  --
  --   Input sentences (training):
  --     0: "Hello"
  --     1: "I'm stressed"
  --     2: "I'm tired"
  --     3: "I'm going to sleep"
  --
  --   Reply classes (one-hot):
  --     0001 -> "Hey there!"
  --     0010 -> "Try taking a short break."
  --     0100 -> "You should get some rest."
  --     1000 -> "Okay, good night!"
  ---------------------------------------------------------------------------
  type rom_x_t  is array(0 to 3) of vec8_q44;
  type rom_y_t  is array(0 to 3) of std_logic_vector(3 downto 0);

  -- Training inputs: one-hot on first 4 features, rest zero
  constant X_TRAIN : rom_x_t := (
    -- "Hello"              -> 10000000 (conceptually)
    (ONE_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44),

    -- "I'm stressed"       -> 01000000
    (ZERO_Q44, ONE_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44),

    -- "I'm tired"          -> 00100000
    (ZERO_Q44, ZERO_Q44, ONE_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44),

    -- "I'm going to sleep" -> 00010000
    (ZERO_Q44, ZERO_Q44, ZERO_Q44, ONE_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44)
  );

  -- Training labels: one-hot reply classes
  constant Y_TRAIN : rom_y_t := (
    "0001",  -- Hello            -> "Hey there!"
    "0010",  -- I'm stressed     -> "Try taking a short break."
    "0100",  -- I'm tired        -> "You should get some rest."
    "1000"   -- I'm going to sleep -> "Okay, good night!"
  );

  ---------------------------------------------------------------------------
  -- Validation set:
  --   0: mix of Hello + I'm stressed      -> expect "take a break" (class 1)
  --   1: mix of I'm tired + going to sleep-> expect "good night" (class 3)
  ---------------------------------------------------------------------------
  type romxv_t is array(0 to 1) of vec8_q44;
  type romyv_t is array(0 to 1) of std_logic_vector(3 downto 0);

  constant X_VALID : romxv_t := (
    -- Hello + I'm stressed
    (ONE_Q44, ONE_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44),

    -- I'm tired + I'm going to sleep
    (ZERO_Q44, ZERO_Q44, ONE_Q44, ONE_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44, ZERO_Q44)
  );

  constant Y_VALID : romyv_t := (
    "0010",  -- expect "Try taking a short break."
    "1000"   -- expect "Okay, good night!"
  );

  ---------------------------------------------------------------------------
  -- Trainable weight registers
  ---------------------------------------------------------------------------
  signal W1_reg : mat8x8_q88;
  signal B1_reg : vec8_bias_q88;

  signal W2_reg : mat4x8_q88;
  signal B2_reg : vec4_bias_q88;

  ---------------------------------------------------------------------------
  -- Helper: print a Q8.8 value as decimal (value / 256.0)
  ---------------------------------------------------------------------------
  procedure write_q88(L : inout line; v : q88_t) is
    variable r : real;
  begin
    r := real(to_integer(v)) / 256.0;
    -- write(L, real, justification, width, digits_after_decimal)
    write(L, r, right, 0, 3);
  end procedure;

begin

  ---------------------------------------------------------------------------
  -- Dataset read (combinational)
  ---------------------------------------------------------------------------
  process (sel_valid, idx_tr, idx_va)
    variable it : integer;
    variable iv : integer;
  begin
    it := to_integer(idx_tr);
    iv := to_integer(idx_va);

    if sel_valid = '0' then  -- training set
      if it >= 0 and it <= 3 then
        x_out <= X_TRAIN(it);
        y_out <= Y_TRAIN(it);
      else
        x_out <= (others => ZERO_Q44);
        y_out <= (others => '0');
      end if;
    else                    -- validation set
      if iv >= 0 and iv <= 1 then
        x_out <= X_VALID(iv);
        y_out <= Y_VALID(iv);
      else
        x_out <= (others => ZERO_Q44);
        y_out <= (others => '0');
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Hidden layer weights/bias: initialise, then updated by update_unit_w1
  ---------------------------------------------------------------------------
  process (clk, rst_n)
    constant ONE_Q88  : q88_t := to_signed(256, 16);  -- 1.0 in Q8.8
    constant ZERO_Q88 : q88_t := to_signed(0,   16);
  begin
    if rst_n = '0' then
      -- On reset: W1 starts as a diagonal mapping for the first 4 neurons
      for i in 0 to 7 loop
        for j in 0 to 7 loop
          if (i = j) and (i <= 3) then
            W1_reg(i,j) <= ONE_Q88;
          else
            W1_reg(i,j) <= ZERO_Q88;
          end if;
        end loop;
        B1_reg(i) <= ZERO_Q88;
      end loop;

    elsif rising_edge(clk) then
      if w1_we = '1' then
        W1_reg <= W1_in;
        B1_reg <= B1_in;
      end if;
    end if;
  end process;

  W1_out <= W1_reg;
  B1_out <= B1_reg;

  ---------------------------------------------------------------------------
  -- Output layer weights/bias: trainable registers (start at zero)
  ---------------------------------------------------------------------------
  process (clk, rst_n)
    constant ZERO_Q88 : q88_t := to_signed(0, 16);
  begin
    if rst_n = '0' then
      for k in 0 to 3 loop
        for i in 0 to 7 loop
          W2_reg(k,i) <= ZERO_Q88;
        end loop;
        B2_reg(k) <= ZERO_Q88;
      end loop;

    elsif rising_edge(clk) then
      if w2_we = '1' then
        W2_reg <= W2_in;
        B2_reg <= B2_in;
      end if;
    end if;
  end process;

  W2_out <= W2_reg;
  B2_out <= B2_reg;

  ---------------------------------------------------------------------------
  -- Logging process: print W1 and W2 when they are updated
  -- We only show the first 4x4 “active” block (the rest stay at zero).
  ---------------------------------------------------------------------------
  weights_logger : process (clk)
    variable L   : line;
    variable i,j : integer;
  begin
    if rising_edge(clk) then

      ----------------------------------------------------------------------
      -- Log W2/B2 (output layer) in decimal Q8.8
      ----------------------------------------------------------------------
      if w2_we = '1' then
        L := null;
        write(L, string'("=== W2/B2 UPDATE @ time "));
        write(L, now);
        writeline(output, L);

        -- B2
        L := null;
        write(L, string'("B2 = ["));
        for i in 0 to 3 loop
          write_q88(L, B2_in(i));
          if i < 3 then
            write(L, string'(", "));
          end if;
        end loop;
        write(L, string'("]"));
        writeline(output, L);

        -- 4x4 “active” block of W2
        L := null;
        write(L, string'("W2 (4x4 block):"));
        writeline(output, L);
        for i in 0 to 3 loop
          L := null;
          write(L, string'("  row "));
          write(L, i);
          write(L, string'(" = ["));
          for j in 0 to 3 loop
            write_q88(L, W2_in(i,j));
            if j < 3 then
              write(L, string'(", "));
            end if;
          end loop;
          write(L, string'("]"));
          writeline(output, L);
        end loop;
      end if;

      ----------------------------------------------------------------------
      -- Log W1/B1 (hidden layer) in decimal Q8.8
      ----------------------------------------------------------------------
      if w1_we = '1' then
        L := null;
        write(L, string'("=== W1/B1 UPDATE @ time "));
        write(L, now);
        writeline(output, L);

        -- First 4 biases (tied to our 4 classes)
        L := null;
        write(L, string'("B1[0..3] = ["));
        for i in 0 to 3 loop
          write_q88(L, B1_in(i));
          if i < 3 then
            write(L, string'(", "));
          end if;
        end loop;
        write(L, string'("]"));
        writeline(output, L);

        -- 4x4 “active” block of W1
        L := null;
        write(L, string'("W1 (4x4 block):"));
        writeline(output, L);
        for i in 0 to 3 loop
          L := null;
          write(L, string'("  row "));
          write(L, i);
          write(L, string'(" = ["));
          for j in 0 to 3 loop
            write_q88(L, W1_in(i,j));
            if j < 3 then
              write(L, string'(", "));
            end if;
          end loop;
          write(L, string'("]"));
          writeline(output, L);
        end loop;
      end if;

    end if;
  end process;

end architecture;
