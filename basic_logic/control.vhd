-- Controller: selects a circuit and controls clock signal

library ieee, lib_io;
use ieee.std_logic_1164.all;
use lib_io.pkg_crystal;

package pkg_control is
	-- half-period of the output clock (2s)
	constant out_clk_half: positive := pkg_crystal.crystal_hz * 2;
	-- time of button press for entering configuration mode (1s)
	constant cfg_time: positive := pkg_crystal.crystal_hz;
	-- number of circuits
	constant circuit_n: positive := 16;
	-- selection of a circuit
	subtype sel_circuit_t is natural range 0 to circuit_n - 1;
	component control is 
		port (
			-- main system clock
			Clk: in std_logic;
			-- button for clock start/stop and entering configuration
			BtnClkCfg: in std_logic;
			-- button for selecting the next circuit
			BtnNext: in std_logic;
			-- button for selecting the previous circuit
			BtnPrev: in std_logic;
			-- button for switching between combinatorial and sequential circuits
			BtnCombSeq: in std_logic;
			-- configuration mode enabled
			CfgMode: out std_logic;
			-- output clock
			ClkOut: out std_logic;
			-- output clock enabled
			ClkEna: out std_logic;
			-- select combinatorial ('0') or sequential ('1') circuits
			CombSeq: out std_logic;
			-- circuit selection
			Circuit: out sel_circuit_t;
			-- 7-segment display digit selection
			DIG: out std_logic_vector(3 downto 0);
			-- 7-segment display segment selection
			SEG: out std_logic_vector(7 downto 0)
		);
	end component;
end package;

library ieee, lib_io;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_control.all;
use lib_io.pkg_seg7.all;

entity control is
	port (
		Clk, BtnClkCfg, BtnNext, BtnPrev, BtnCombSeq: in std_logic;
		CfgMode, ClkOut, ClkEna, CombSeq: out std_logic;
		Circuit: out sel_circuit_t;
		DIG: out std_logic_vector(3 downto 0);
		SEG: out std_logic_vector(7 downto 0)
	);
end entity;

architecture main of control is
	signal cfg_mode: std_logic := '1';
	signal clk_out, clk_ena, comb_seq: std_logic := '0';
	signal sel_circuit: sel_circuit_t := 0;
	signal s7_cs, s7_c: std_logic_vector(6 downto 0);
	signal d_cs, d_c: unsigned(3 downto 0);
begin
	display: seg7_raw port map (
		Clk=>Clk, Rst=>'0',
		Seg7=>(3=>s7_cs, 0=>s7_c, others=>(others=>'0')),
		DP=>(others=>'0'), EnaSeg7=>"1001", EnaDP=>"0000",
		WSeg7=>(others=>'1'), WDP=>(others=>'1'),
		DIG=>DIG, SEG=>SEG
	);	
	display_comb_seq: seg7_decoder port map (I=>d_cs, CP=>'0', O=>s7_cs);
	display_circuit: seg7_decoder port map (I=>d_c, CP=>'0', O=>s7_c);
	d_cs <= X"c" when comb_seq = '0' else X"5";
	d_c <= to_unsigned(sel_circuit, 4);
	
	ctl: process (Clk) is
		variable old_clk_cfg, old_next, old_prev, old_comb_seq: std_logic := '0';
		variable clk_i, cfg_i: natural := 0;
	begin
		if rising_edge(Clk) then
			-- run output clock
			if clk_ena = '1' then
				if clk_i < out_clk_half then
					clk_i := clk_i + 1;
				else
					clk_i := 0;
					clk_out <= not clk_out;
				end if;
			else
				clk_out <= '1';
				clk_i := 0;
			end if;
			-- switch output clock and configuration
			if BtnClkCfg = '1' and old_clk_cfg = '0' then
				if cfg_mode = '1' then
					cfg_mode <= '0';
				else
					cfg_i := 1;
				end if;
			elsif BtnClkCfg = '0' and old_clk_cfg = '1' then
				if cfg_i > 0 and cfg_i < cfg_time then
					clk_ena <= not clk_ena;
				end if;
				cfg_i := 0;
			else
				if cfg_i > 0 then
					if cfg_i < cfg_time then
						cfg_i := cfg_i + 1;
					end if;
					if cfg_i = cfg_time then
						cfg_mode <= '1';
						clk_ena <= '0';
					end if;
				end if;
			end if;
			old_clk_cfg := BtnClkCfg;
			-- circuit selection
			if cfg_mode = '1' then
				if BtnNext = '1' and old_next = '0' then
					if sel_circuit < 15 then
						sel_circuit <= sel_circuit + 1;
					else
						sel_circuit <= 0;
					end if;
				end if;
				old_next := BtnNext;
				if BtnPrev = '1' and old_prev = '0' then
					if sel_circuit > 0 then
						sel_circuit <= sel_circuit - 1;
					else
						sel_circuit <= 15;
					end if;
				end if;
				old_prev := BtnPrev;
				if BtnCombSeq = '1' and old_comb_seq = '0' then
					comb_seq <= not comb_seq;
				end if;
				old_comb_seq := BtnCombSeq;
			end if;
		end if;
	end process;
	CfgMode <= cfg_mode;
	ClkOut <= clk_out;
	ClkEna <= clk_ena;
	CombSeq <= comb_seq;
	Circuit <= sel_circuit;
end architecture;