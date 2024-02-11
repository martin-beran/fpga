-- Testbench for package clock

library ieee;
use ieee.std_logic_1164.all;
library lib_util;
use lib_util.pkg_clock.all;

entity tb_clock_divider is
end entity;

architecture main of tb_clock_divider is
	signal Clk, Rst, O1, O2, O3, O3p1, O2_1, O2_2, O2_2p1: std_logic;
begin
	clock: process is
		variable state: std_logic := '0';
	begin
		state := not state;
		Clk <= state;
		wait for 5 ns;
	end process;
	
	Rst <= '0', '1' after 110 ns, '0' after 120 ns;

	dut1: clock_divider generic map (factor=>1) port map (Clk=>Clk, Rst=>Rst, O=>O1);
	dut2: clock_divider generic map (factor=>2) port map (Clk=>Clk, Rst=>Rst, O=>O2);
	dut3: clock_divider generic map (factor=>3) port map (Clk=>Clk, Rst=>Rst, O=>O3);
	dut3p1: clock_divider generic map (factor=>3, phase=>1) port map (Clk=>Clk, Rst=>Rst, O=>O3p1);
	dut2_1: clock_divider generic map (use_I=>true, factor=>1) port map (Clk=>Clk, Rst=>Rst, I=>O2, O=>O2_1);
	dut2_2: clock_divider generic map (use_I=>true, factor=>2) port map (Clk=>Clk, Rst=>Rst, I=>O2, O=>O2_2);
	dut2_2p1: clock_divider generic map (use_I=>true, factor=>2, phase=>1) port map (Clk=>Clk, Rst=>Rst, I=>O2, O=>O2_2p1);
end architecture;