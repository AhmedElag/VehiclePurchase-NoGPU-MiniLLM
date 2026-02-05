library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.fx_types_m2.all;

entity testbench is
end entity;

architecture tb of testbench is
  signal clk       : std_logic := '0';
  signal rst_n     : std_logic := '0';
  signal start     : std_logic := '0';
  signal done      : std_logic;

  signal cur_epoch : unsigned(7 downto 0);
  signal cur_index : unsigned(7 downto 0);
  signal y_true    : std_logic_vector(3 downto 0);
  signal y_pred    : std_logic_vector(3 downto 0);

  signal sel_valid : std_logic;
  signal idx_tr    : unsigned(7 downto 0);
  signal idx_va    : unsigned(7 downto 0);

  signal end_sim   : std_logic := '0';

  --------------------------------------------------------------------
  -- Helper: convert std_logic_vector to "0101" string
  --------------------------------------------------------------------
  function slv_to_string(slv : std_logic_vector) return string is
    variable res : string(1 to slv'length);
    variable k   : integer := 1;
  begin
    for i in slv'range loop
      if slv(i) = '1' then
        res(k) := '1';
      else
        res(k) := '0';
      end if;
      k := k + 1;
    end loop;
    return res;
  end function;

  --------------------------------------------------------------------
  -- Helper: pad a string on the right to a fixed width
  --------------------------------------------------------------------
  function pad_right(s : string; width : natural) return string is
    variable res : string(1 to width);
    variable i   : integer;
  begin
    -- default spaces
    for i in 1 to width loop
      res(i) := ' ';
    end loop;

    -- copy s into the beginning
    for i in 1 to width loop
      exit when i > s'length;
      res(i) := s(s'low + i - 1);
    end loop;
    return res;
  end function;

  --------------------------------------------------------------------
  -- Helper: input sentence labels (TRAINING)
  --------------------------------------------------------------------
  function train_input_label(idx : integer) return string is
  begin
    case idx is
      when 0 => return "Hello";
      when 1 => return "I'm stressed";
      when 2 => return "I'm tired";
      when 3 => return "I'm going to sleep";
      when others => return "Unknown";
    end case;
  end function;

  --------------------------------------------------------------------
  -- NEW: input sentence labels (VALIDATION)
  --------------------------------------------------------------------
  function valid_input_label(idx : integer) return string is
  begin
    case idx is
      when 0 => return "Hello + I'm stressed";
      when 1 => return "Tired + Going to sleep";
      when others => return "Unknown";
    end case;
  end function;

  --------------------------------------------------------------------
  -- Helper: class / response label from y bits
  --------------------------------------------------------------------
  function class_label(y : std_logic_vector(3 downto 0)) return string is
  begin
    if    y = "0001" then return "Hey there!";
    elsif y = "0010" then return "Take a short break.";
    elsif y = "0100" then return "Get some rest.";
    elsif y = "1000" then return "Good night!";
    else                return "Unknown";
    end if;
  end function;

begin
  --------------------------------------------------------------------
  -- DUT
  --------------------------------------------------------------------
  UUT : entity work.mini_llm_core
    generic map (
      N_TRAIN  => 4,
      N_VALID  => 2,
      MAX_EPOC => 50
    )
    port map (
      clk         => clk,
      rst_n       => rst_n,
      start       => start,
      done        => done,
      cur_epoch   => cur_epoch,
      cur_index   => cur_index,
      y_true_o    => y_true,
      y_pred_o    => y_pred,
      sel_valid_o => sel_valid,
      idx_tr_o    => idx_tr,
      idx_va_o    => idx_va
    );

  --------------------------------------------------------------------
  -- Clock
  --------------------------------------------------------------------
  clk_gen : process
  begin
    while end_sim = '0' loop
      clk <= '0'; wait for 5 ns;
      clk <= '1'; wait for 5 ns;
    end loop;
    wait;
  end process;

  --------------------------------------------------------------------
  -- Stimulus
  --------------------------------------------------------------------
  stim_proc : process
  begin
    rst_n <= '0';
    start <= '0';
    wait for 50 ns;

    rst_n <= '1';
    wait for 20 ns;

    start <= '1';
    wait for 10 ns;
    start <= '0';

    -- wait for training + validation to finish
    wait until done = '1';
    wait for 100 ns;

    end_sim <= '1';
    wait;
  end process;

  --------------------------------------------------------------------
  -- Logger: per-epoch training tables + one validation table
  --------------------------------------------------------------------
  logger : process (clk)
    variable L            : line;
    variable prev_sel_val : std_logic := '1';
    variable prev_idx_tr  : unsigned(7 downto 0) := (others => '1');
    variable prev_idx_va  : unsigned(7 downto 0) := (others => '0');
    variable prev_done    : std_logic := '0';

    variable ep_int       : integer;
    variable idx_int      : integer;
    constant COL_INP_LEN  : natural := 26;
    constant COL_TXT_LEN  : natural := 15;
  begin
    if rising_edge(clk) then
      ep_int := to_integer(cur_epoch);

      ----------------------------------------------------------------
      -- TRAINING
      ----------------------------------------------------------------
      if sel_valid = '0' then
        if (prev_sel_val /= '0') or (idx_tr /= prev_idx_tr) then
          idx_int := to_integer(idx_tr);

          if idx_int = 0 then
            L := null;
            writeline(output, L);

            L := null;
            write(L, string'("--------------------------------------------------------------------------------------------"));
            writeline(output, L);
            L := null;
            write(L, string'("EPOCH "));
            write(L, ep_int);
            write(L, string'(" - TRAINING"));
            writeline(output, L);
            L := null;
            write(L, string'("--------------------------------------------------------------------------------------------"));
            writeline(output, L);
            L := null;
            write(L, string'("Idx  "));
            write(L, pad_right("Input text", COL_INP_LEN));
            write(L, string'("  "));
            write(L, pad_right("y_true(bits/text)", COL_TXT_LEN + 5));
            write(L, string'("  "));
            write(L, pad_right("y_pred(bits/text)", COL_TXT_LEN + 5));
            write(L, string'("  Result"));
            writeline(output, L);
            L := null;
            write(L, string'("--------------------------------------------------------------------------------------------"));
            writeline(output, L);
          end if;

          L := null;
          write(L, idx_int);
          if idx_int < 10 then
            write(L, string'("   "));
          else
            write(L, string'("  "));
          end if;

          write(L, pad_right(train_input_label(idx_int), COL_INP_LEN));
          write(L, string'("  "));

          write(L, slv_to_string(y_true));
          write(L, string'(" "));
          write(L, pad_right(class_label(y_true), COL_TXT_LEN));
          write(L, string'("  "));

          write(L, slv_to_string(y_pred));
          write(L, string'(" "));
          write(L, pad_right(class_label(y_pred), COL_TXT_LEN));
          write(L, string'("  "));

          if y_true = y_pred then
            write(L, string'("PASS"));
          else
            write(L, string'("FAIL"));
          end if;

          writeline(output, L);
        end if;

      ----------------------------------------------------------------
      -- VALIDATION
      ----------------------------------------------------------------
      else
        if (prev_sel_val /= '1') or (idx_va /= prev_idx_va) then
          idx_int := to_integer(idx_va);

          if (prev_sel_val = '0') and (idx_int = 0) then
            L := null;
            writeline(output, L);
            L := null;
            write(L, string'("============================================================================================"));
            writeline(output, L);
            L := null;
            write(L, string'("VALIDATION AFTER EPOCH "));
            write(L, ep_int);
            writeline(output, L);
            L := null;
            write(L, string'("============================================================================================"));
            writeline(output, L);
            L := null;
            write(L, string'("Idx  "));
            write(L, pad_right("Input text", COL_INP_LEN));
            write(L, string'("  "));
            write(L, pad_right("y_true(bits/text)", COL_TXT_LEN + 5));
            write(L, string'("  "));
            write(L, pad_right("y_pred(bits/text)", COL_TXT_LEN + 5));
            write(L, string'("  Result"));
            writeline(output, L);
            L := null;
            write(L, string'("--------------------------------------------------------------------------------------------"));
            writeline(output, L);
          end if;

          L := null;
          write(L, idx_int);
          if idx_int < 10 then
            write(L, string'("   "));
          else
            write(L, string'("  "));
          end if;

          write(L, pad_right(valid_input_label(idx_int), COL_INP_LEN));
          write(L, string'("  "));

          write(L, slv_to_string(y_true));
          write(L, string'(" "));
          write(L, pad_right(class_label(y_true), COL_TXT_LEN));
          write(L, string'("  "));

          write(L, slv_to_string(y_pred));
          write(L, string'(" "));
          write(L, pad_right(class_label(y_pred), COL_TXT_LEN));
          write(L, string'("  "));

          if y_true = y_pred then
            write(L, string'("PASS"));
          else
            write(L, string'("FAIL"));
          end if;

          writeline(output, L);
        end if;
      end if;

      ----------------------------------------------------------------
      -- DONE message
      ----------------------------------------------------------------
      prev_sel_val := sel_valid;
      prev_idx_tr  := idx_tr;
      prev_idx_va  := idx_va;

      if (prev_done = '0') and (done = '1') then
        L := null;
        writeline(output, L);
        L := null;
        write(L, string'("---- MINI LLM TRAINING + VALIDATION COMPLETE ----"));
        writeline(output, L);
      end if;
      prev_done := done;
    end if;
  end process;
end architecture;
