-- Testbench for counter

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_counter is
end entity;

architecture main of tb_counter is
	constant bits1: integer := 4;
	constant max1: integer := 9;
	constant max2: integer := 23;
	constant bits10: integer := 2;
	constant max10: integer := 2;
	signal Clk: std_logic := '1';
	signal Rst, Inc, IncClk, Dec, DecClk, CInc, CDec: std_logic;
	signal Value1: unsigned(bits1 - 1 downto 0);
	signal Value10: unsigned(bits10 - 1 downto 0);
begin
	clock: process is
	begin
		wait for 2500 ps;
		Clk <= not Clk;
	end process;
	Rst <=
		'1' after 0 ns,
		'0' after 10 ns,
		'1' after 450 ns,
		'0' after 460 ns;
	Inc <=
		'0' after 0 ns,
		'1' after 100 ns,
		'0' after 400 ns;
	Dec <=
		'0' after 0 ns,
		'1' after 500 ns,
		'0' after 800 ns;
	process (Clk) is
		variable state: std_logic := '0';
	begin
		if rising_edge(Clk) then
			state := not state;
			IncClk <= state and Inc;
			DecClk <= state and Dec;
		end if;
	end process;
	cnt1: entity work.counter
		generic map (bits=>bits1, max=>max1, max2=>max2)
		port map (Clk=>Clk, Rst=>Rst, Inc=>Inc, Dec=>DecClk, CInc=>CInc, CDec=>CDec, Value=>Value1);
	cnt10: entity work.counter
		generic map (bits=>bits10, max=>max10)
		port map (Clk=>Clk, Rst=>Rst, Inc=>Inc, Dec=>DecClk, InCInc=>CInc, InCDec=>CDec, InCarry=>'1', Value=>Value10);
end architecture;