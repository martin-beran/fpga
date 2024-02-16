-- Testbench for package clock

library ieee;
use ieee.std_logic_1164.all;
library lib_util;
use lib_util.pkg_clock.all;

entity tb_clock_divider is
end entity;

architecture main of tb_clock_divider is
	signal Clk, Rst,
		O2, O3, O4, O5, O2_2, O2_3, O3_2, O2_3_2, O2_3_2_3,
		OSync2, OSync3, OSync4, OSync5, OSync2_3, OSync2_3_2: std_logic;
begin
	clock: process is
		variable state: std_logic := '0';
	begin
		state := not state;
		Clk <= state;
		wait for 5 ns;
	end process;
	
	Rst <= '0', '1' after 110 ns, '0' after 120 ns, '1' after 180 ns, '0' after 190 ns;

	dut2: clock_divider generic map (factor=>2) port map (Clk=>Clk, Rst=>Rst, O=>O2, OSync=>OSync2);
	dut3: clock_divider generic map (factor=>3) port map (Clk=>Clk, Rst=>Rst, O=>O3, OSync=>OSync3);
	dut4: clock_divider generic map (factor=>4) port map (Clk=>Clk, Rst=>Rst, O=>O4, OSync=>OSync4);
	dut5: clock_divider generic map (factor=>5) port map (Clk=>Clk, Rst=>Rst, O=>O5, OSync=>OSync5);
	dut2_2: clock_divider generic map (factor=>2) port map (Clk=>Clk, Rst=>Rst, ISync=>OSync2, O=>O2_2, OSync=>open);
	dut2_3: clock_divider generic map (factor=>3) port map (Clk=>Clk, Rst=>Rst, ISync=>OSync2, O=>O2_3, OSync=>OSync2_3);
	dut3_2: clock_divider generic map (factor=>2) port map (Clk=>Clk, Rst=>Rst, ISync=>OSync3, O=>O3_2, OSync=>open);
	dut2_3_2: clock_divider generic map (factor=>2) port map (Clk=>Clk, Rst=>Rst, ISync=>OSync2_3, O=>O2_3_2, OSync=>OSync2_3_2);
	dut2_3_2_3: clock_divider generic map (factor=>3) port map (Clk=>Clk, Rst=>Rst, ISync=>OSync2_3_2, O=>O2_3_2_3, OSync=>open);
end architecture;