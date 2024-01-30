-- Testbench for rt_clock

library ieee;
use ieee.std_logic_1164.all;

entity tb_rt_clock is
end entity;

architecture main of tb_rt_clock is
	signal Clk: std_logic := '1';
	signal Rst: std_logic := '0';
	signal RTC: std_logic := 'X';
begin
	clock: process is
	begin
		wait for 5 ns;
		Clk <= not Clk;
	end process;
	Rst <=
		'1' after 286 ns,
		'0' after 412 ns;
	dut: entity work.rt_clock generic map (hz=>10) port map (Clk=>Clk, Rst=>Rst, RTC=>RTC);
end architecture;