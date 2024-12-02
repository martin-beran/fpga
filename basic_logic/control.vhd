-- Controller: selects a circuit and controls clock signal

library ieee, lib_io;
use ieee.std_logic_1164.all;
use lib_io.pkg_crystal;

package pkg_control is
	-- half-period of the output clock (2s)
	out_clk_half: positive = pkg_crystal.crystal_hz * 2;
	-- number of circuits
	constant circuit_n: positive := 16;
	-- selection of a circuit
	subtype sel_circuit_t is natural range 0 to sel_input_n - 1;
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

library ieee;
use ieee.std_logic_1164.all;
use work.pkg_control.all;

entity control is
	port (
		Clk, BtnClkCfg, BtnNext, BtnPrev, BtnComSeq: in std_logic;
		CfgMode, CldOut, ClkEna, CombSeq: out std_logic;
		Circuit: out sel_circuit_t;
		DIG: out std_logic_vector(3 downto 0);
		SEG: out std_logic_vector(7 downto 0)
	);
end entity;

architecture main of control is
begin
	CfgMode <= '0';
	ClkOut <= '0';
	ClkEna <= '0';
	CombSeq <= '0';
	Circuit <= 1; -- AND
	DIG <= (others=>'0');
	SEG <= (others=>'0');
	-- TODO
end architecture;