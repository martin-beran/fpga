library ieee;
use ieee.std_logic_1164.all;

entity tb_blink is
end entity;

architecture main of tb_blink is
	signal tClk: std_logic := '0';
	signal tStart, tStop: std_logic := '1';
	signal led1, led2: std_logic;
begin
	process
	begin
		wait for 5 ns;
		tClk <= not tClk;
	end process;
	tStop <=
		'0' after 200 ns,
		'1' after 400 ns;
	uub: entity work.blink
		generic map (crystal_khz=>1, period_ms=>10)
		port map (clk=>tClk, start=>tStart, stop=>tStop, led1=>led1, led2=>led2);
end;