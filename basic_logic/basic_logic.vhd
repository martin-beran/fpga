-- Demonstration of basic logic circuits: combinatorial (gates) and sequential (flip-flops)

package pkg_basic_logic is
	constant inputs_n: positive := 4;
	constant outputs_n: positive := 4;
end package;

library ieee, lib_util, lib_io;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use lib_util.pkg_multiplexer.all;
use lib_io.pkg_button.all;
use lib_io.pkg_crystal.all;
use lib_io.pkg_led.all;
use lib_io.pkg_seg7.all;
use work.pkg_control;
use work.pkg_basic_logic.all;

entity basic_logic is
	port (
		-- the main system clock
		Clk: in std_logic;
		-- setting configuration mode, starting/stopping clock signal
		RstBtn: in std_logic;
		-- configuration and input buttons
		Button: in std_logic_vector(inputs_n - 1 downto 0);
		-- LEDs indicating input bits
		LED: out std_logic_vector(inputs_n downto 1);
		-- 7-segment display digit selection
		DIG: out std_logic_vector(3 downto 0);
		-- 7-segment display segment selection
		SEG: out std_logic_vector(7 downto 0)
	);
end entity;

architecture main of basic_logic is
	signal button_state: std_logic_vector(inputs_n downto 0);
	signal inputs: std_logic_vector(inputs_n - 1 downto 0);
	signal outputs: std_logic_vector(outputs_n - 1 downto 0);	
	signal cfg_mode, ctl_clk, ctl_clk_ena, comb_seq: std_logic;
	signal circuit: pkg_control.sel_circuit_t;
	signal ctl_dig: std_logic_vector(3 downto 0);
	signal ctl_seg: std_logic_vector(7 downto 0);
	signal mux_comb_in: mux_input_t(pkg_control.sel_circuit_t'range)(outputs_n - 1 downto 0) := (others=>(others=>'0'));
	signal mux_seq_in: mux_input_t(pkg_control.sel_circuit_t'range)(outputs_n - 1 downto 0) := (others=>(others=>'0'));
	signal mux_comb_out: std_logic_vector(outputs_n - 1 downto 0);
	signal mux_seq_out: std_logic_vector(outputs_n - 1 downto 0);
begin
	-- handle physical buttons
	button_in: button_group
		generic map (count=>inputs_n + 1)
		port map (Clk=>Clk, Button=>Button&RstBtn, O=>button_state);
	-- control, select circuit
	controller: pkg_control.control port map (
		Clk=>Clk,
		BtnClkCfg=>button_state(0), BtnNext=>button_state(1), BtnPrev=>button_state(2), BtnCombSeq=>button_state(3),
		CfgMode=>cfg_mode, ClkOut=>ctl_clk, ClkEna=>ctl_clk_ena,
		CombSeq=>comb_seq, Circuit=>circuit,
		DIG=>ctl_dig, SEG=>ctl_seg
	);
	-- inputs to circuits
	inputs(0) <= ctl_clk when ctl_clk_ena = '1' else button_state(1);
	inputs(inputs_n - 1 downto 1) <= button_state(inputs_n downto 2);
	-- indicate input states by LEDs
	leds: led_group port map (Clk=>Clk, I=>inputs, LED=>LED);
	-- indicate outputs or control state by 7-segment display
	DIG <= ctl_dig when cfg_mode = '1' else not outputs;
	SEG <= ctl_seg when cfg_mode = '1' else "01111111";
	-- output multiplexers
	mux_comb: multiplexer
		generic map (inputs=>pkg_control.circuit_n, bits=>outputs_n)
		port map (Sel=>circuit, I=>mux_comb_in, O=>mux_comb_out);
	mux_seq: multiplexer
		generic map (inputs=>pkg_control.circuit_n, bits=>outputs_n)
		port map (Sel=>circuit, I=>mux_seq_in, O=>mux_seq_out);
	outputs <= mux_comb_out when comb_seq = '0' else mux_seq_out;
	
	-- combinatorial circuits
	c0000: entity work.comb_0000_const0 port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(0)(0));
	c0001: entity work.comb_0001_nor port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(1)(0));
	c0010: entity work.comb_0010_not_rev_impl port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(2)(0));
	c0011: entity work.comb_0011_not_a port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(3)(0));
	c0100: entity work.comb_0100_not_impl port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(4)(0));
	c0101: entity work.comb_0101_not_b port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(5)(0));
	c0110: entity work.comb_0110_xor port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(6)(0));
	c0111: entity work.comb_0111_nand port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(7)(0));
	c1000: entity work.comb_1000_and port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(8)(0));
	c1001: entity work.comb_1001_xnor port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(9)(0));
	c1010: entity work.comb_1010_b port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(10)(0));
	c1011: entity work.comb_1011_impl port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(11)(0));
	c1100: entity work.comb_1100_a port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(12)(0));
	c1101: entity work.comb_1101_rev_impl port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(13)(0));
	c1110: entity work.comb_1110_or port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(14)(0));
	c1111: entity work.comb_1111_const1 port map (A=>inputs(0), B=>inputs(1), Q=>mux_comb_in(15)(0));

	-- sequential circuits
	s_r_s: entity work.seq_r_s port map (R=>inputs(0), S=>inputs(1), Q=>mux_seq_in(0)(0), notQ=>mux_seq_in(0)(1));
	s_gated_d_latch: entity work.seq_gated_d_latch port map (E=>inputs(0), D=>inputs(1), Q=>mux_seq_in(1)(0), notQ=>mux_seq_in(1)(1));
end architecture;