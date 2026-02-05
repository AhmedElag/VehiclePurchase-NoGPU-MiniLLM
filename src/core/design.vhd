-------------------------------------------------------------------------------
-- Top core: mini_llm_core
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fx_types_m2.all;

entity mini_llm_core is
  generic (
    N_TRAIN  : integer := 4;
    N_VALID  : integer := 2;
    MAX_EPOC : integer := 50
  );
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic;
    start    : in  std_logic;
    done     : out std_logic;

    cur_epoch   : out unsigned(7 downto 0);
    cur_index   : out unsigned(7 downto 0);
    y_true_o    : out std_logic_vector(3 downto 0);
    y_pred_o    : out std_logic_vector(3 downto 0);

    -- extra debug for testbench
    sel_valid_o : out std_logic;
    idx_tr_o    : out unsigned(7 downto 0);
    idx_va_o    : out unsigned(7 downto 0)
  );
end entity;

architecture rtl of mini_llm_core is
  signal sel_valid_s : std_logic;
  signal idx_tr_s    : unsigned(7 downto 0);
  signal idx_va_s    : unsigned(7 downto 0);

  signal x_s         : vec8_q44;
  signal y_true_s    : std_logic_vector(3 downto 0);

  signal W1_s        : mat8x8_q88;
  signal B1_s        : vec8_bias_q88;
  signal W2_s        : mat4x8_q88;
  signal B2_s        : vec4_bias_q88;

  signal W2_new_s    : mat4x8_q88;
  signal B2_new_s    : vec4_bias_q88;
  signal W1_new_s    : mat8x8_q88;
  signal B1_new_s    : vec8_bias_q88;

  signal w2_we_s     : std_logic;
  signal w1_we_s     : std_logic;

  signal h_s         : vec8_q88;
  signal y_raw_s     : vec4_q88;
  signal y_pred_1hot : std_logic_vector(3 downto 0);
begin
  -- ROM + weights
  U_ROMREG : entity work.rom_regs_m2
    generic map (
      N_TRAIN => N_TRAIN,
      N_VALID => N_VALID
    )
    port map (
      clk       => clk,
      rst_n     => rst_n,
      sel_valid => sel_valid_s,
      idx_tr    => idx_tr_s,
      idx_va    => idx_va_s,
      x_out     => x_s,
      y_out     => y_true_s,

      w1_we     => w1_we_s,
      W1_in     => W1_new_s,
      B1_in     => B1_new_s,

      w2_we     => w2_we_s,
      W2_in     => W2_new_s,
      B2_in     => B2_new_s,
      W2_out    => W2_s,
      B2_out    => B2_s,
      W1_out    => W1_s,
      B1_out    => B1_s
    );

  -- Forward pass
  U_FWD : entity work.forward_net
    port map (
      x_in   => x_s,
      W1     => W1_s,
      B1     => B1_s,
      W2     => W2_s,
      B2     => B2_s,
      h_out  => h_s,
      y_raw  => y_raw_s,
      y_1hot => y_pred_1hot
    );

  -- Hidden layer update
  U_UPD1 : entity work.update_unit_w1
    port map (
      x_in   => x_s,
      W1_in  => W1_s,
      B1_in  => B1_s,
      y_true => y_true_s,
      y_pred => y_pred_1hot,
      W1_out => W1_new_s,
      B1_out => B1_new_s
    );

  -- Output layer update
  U_UPD : entity work.update_unit_m2
    port map (
      h_in   => h_s,
      W2_in  => W2_s,
      B2_in  => B2_s,
      y_true => y_true_s,
      y_pred => y_pred_1hot,
      W2_out => W2_new_s,
      B2_out => B2_new_s
    );

  -- Control FSM
  U_FSM : entity work.control_fsm_m2
    generic map (
      N_TRAIN  => N_TRAIN,
      N_VALID  => N_VALID,
      MAX_EPOC => MAX_EPOC
    )
    port map (
      clk       => clk,
      rst_n     => rst_n,
      start     => start,
      cur_epoch => cur_epoch,
      cur_index => cur_index,
      done      => done,
      y_true    => y_true_s,
      y_pred    => y_pred_1hot,
      sel_valid => sel_valid_s,
      idx_tr    => idx_tr_s,
      idx_va    => idx_va_s,
      w2_we     => w2_we_s,
      w1_we     => w1_we_s
    );

  -- Debug taps
  y_true_o    <= y_true_s;
  y_pred_o    <= y_pred_1hot;
  sel_valid_o <= sel_valid_s;
  idx_tr_o    <= idx_tr_s;
  idx_va_o    <= idx_va_s;
end architecture;