-- Testbench for button

library ieee;
use ieee.std_logic_1164.all;

entity tb_button is
end entity;

architecture main of tb_button is
	signal Clk: std_logic := '1';
	signal Btn, Click, LongClick: std_logic;
begin
	clock: process is
	begin
		wait for 5 ns;
		Clk <= not Clk;
	end process;
	Btn <=
		'0' after 1 ns,
		'1' after 20 ns, -- pulse 20 ns, not Click, not LongClick
		'0' after 40 ns,
		'1' after 60 ns, -- pulse 40 ns, not Click, not LongClick
		'0' after 100 ns,
		'1' after 120 ns, -- pulse 50 ns, not Click, not LongClick
		'0' after 170 ns,
		'1' after 190 ns, -- pulse 51 ns, Click, not LongClick
		'0' after 241 ns,
		'1' after 260 ns, -- pulse 60 ns, Click, not LongClick
		'0' after 320 ns,
		'1' after 350 ns, -- pulse 61 ns, Click, LongClick
		'0' after 411 ns,
		'1' after 430 ns, -- pulse 70 ns, Click, LongClick
		'0' after 500 ns,
		'1' after 600 ns, -- pulse 111 ns, Click with 2x autorepeat, LongClick
		'0' after 711 ns;
	check: postponed process is
		procedure check_value(constant name: string; signal v: in std_logic; constant expect: std_logic) is
		begin
			assert v = expect report
				name & " at " & time'image(now) & " is not " & std_logic'image(expect)
				severity failure;
		end procedure;
	begin
		if now < 10 ns then
			check_value("Click", Click, 'U');
		elsif now = 240 ns then
			check_value("Click", Click, '1');
		elsif now = 310 ns then
			check_value("Click", Click, '1');
		elsif now = 400 ns then
			check_value("Click", Click, '1');
		elsif now = 480 ns then
			check_value("Click", Click, '1');
		elsif now = 650 ns or now = 680 ns or now = 710 ns then
			check_value("Click", Click, '1');
		else
			check_value("Click", Click, '0');
		end if;
		if now < 10 ns then
			check_value("LongClick", LongClick, 'U');
		elsif now = 410 ns then
			check_value("LongClick", LongClick, '1');
		elsif now = 490 ns then
			check_value("LongClick", LongClick, '1');
		elsif now = 660 ns then
			check_value("LongClick", LongClick, '1');
		else
			check_value("LongClick", LongClick, '0');
		end if;
		wait for 10 ns;
	end process;
	dut: entity work.button
		generic map (press=>5, long=>6, repeat=>3, autorepeat=>true)
		port map (Clk=>Clk, Btn=>Btn, Click=>Click, LongClick=>LongClick);
end architecture;