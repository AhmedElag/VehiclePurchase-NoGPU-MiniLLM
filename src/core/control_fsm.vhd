-------------------------------------------------------------------------------
-- Control FSM for training + validation (both layers updated on error)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_fsm_m2 is
  generic (
    N_TRAIN  : integer := 4;
    N_VALID  : integer := 2;
    MAX_EPOC : integer := 50
  );
  port (
    clk, rst_n, start : in  std_logic;

    cur_epoch : out unsigned(7 downto 0);
    cur_index : out unsigned(7 downto 0);
    done      : out std_logic;

    y_true    : in  std_logic_vector(3 downto 0);
    y_pred    : in  std_logic_vector(3 downto 0);

    sel_valid : out std_logic;
    idx_tr    : out unsigned(7 downto 0);
    idx_va    : out unsigned(7 downto 0);

    w2_we     : out std_logic;
    w1_we     : out std_logic
  );
end entity;

architecture rtl of control_fsm_m2 is
  type state_t is (
    IDLE,
    LOAD_T,
    FWD_T,
    DECIDE,
    NEXT_T,
    LOAD_V,
    FWD_V,
    NEXT_V,
    ST_DONE
  );
  signal st : state_t := IDLE;

  signal epoch   : integer range 0 to MAX_EPOC := 0;
  signal it      : integer range 0 to N_TRAIN  := 0;
  signal iv      : integer range 0 to N_VALID  := 0;
  signal err_cnt : integer range 0 to N_TRAIN  := 0;
begin
  cur_epoch <= to_unsigned(epoch, 8);
  cur_index <= to_unsigned(it, 8);

  process (clk, rst_n)
    variable mis : boolean;
  begin
    if rst_n = '0' then
      st        <= IDLE;
      epoch     <= 0;
      it        <= 0;
      iv        <= 0;
      err_cnt   <= 0;
      done      <= '0';
      sel_valid <= '0';
      idx_tr    <= (others => '0');
      idx_va    <= (others => '0');
      w2_we     <= '0';
      w1_we     <= '0';

    elsif rising_edge(clk) then
      w2_we <= '0';
      w1_we <= '0';

      case st is
        when IDLE =>
          done <= '0';
          if start = '1' then
            epoch     <= 0;
            it        <= 0;
            err_cnt   <= 0;
            sel_valid <= '0';
            idx_tr    <= (others => '0');
            st        <= LOAD_T;
          end if;

        when LOAD_T =>
          sel_valid <= '0';
          idx_tr    <= to_unsigned(it, 8);
          st        <= FWD_T;

        when FWD_T =>
          st <= DECIDE;

        when DECIDE =>
          mis := (y_true /= y_pred);
          if mis then
            w2_we   <= '1';
            w1_we   <= '1';
            err_cnt <= err_cnt + 1;
          end if;
          st <= NEXT_T;

        when NEXT_T =>
          if it = N_TRAIN - 1 then
            if (err_cnt = 0) or (epoch = MAX_EPOC - 1) then
              iv        <= 0;
              sel_valid <= '1';
              idx_va    <= (others => '0');
              st        <= LOAD_V;
            else
              epoch   <= epoch + 1;
              it      <= 0;
              err_cnt <= 0;
              st      <= LOAD_T;
            end if;
          else
            it <= it + 1;
            st <= LOAD_T;
          end if;

        when LOAD_V =>
          sel_valid <= '1';
          idx_va    <= to_unsigned(iv, 8);
          st        <= FWD_V;

        when FWD_V =>
          st <= NEXT_V;

        when NEXT_V =>
          if iv = N_VALID - 1 then
            st <= ST_DONE;
          else
            iv <= iv + 1;
            st <= LOAD_V;
          end if;

        when ST_DONE =>
          done <= '1';

        when others =>
          st <= IDLE;
      end case;
    end if;
  end process;
end architecture;