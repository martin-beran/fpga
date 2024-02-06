-- HW testbench for button

library ieee;
use ieee.std_logic_1164.all;

entity hwtb_button is
	port (
		Clk: in std_logic; -- the main system clock
		Btn1, Btn2: in std_logic; -- the button input
		LedClick1, LedClick2: out std_logic; -- the button was pressed or autorepeat fired
		LedLongClick1, LedLongClick2: out std_logic -- the button was pressed for a longer time
	);
end entity;

architecture main of hwtb_button is
	signal Click1, Click2, LongClick1, LongClick2: std_logic;
begin
	led_click1: entity work.led_rising_edge port map (Clk=>Clk, I=>Click1, LED=>LedClick1);
	led_long_click1: entity work.led_rising_edge port map (Clk=>Clk, I=>LongClick1, LED=>LedLongClick1);
	led_click2: entity work.led_rising_edge port map (Clk=>Clk, I=>Click2, LED=>LedClick2);
	led_long_click2: entity work.led_rising_edge port map (Clk=>Clk, I=>LongClick2, LED=>LedLongClick2);
	-- DUT
	dut_autorepeat_off: entity work.button
		generic map (autorepeat=>false)
		port map (Clk=>Clk, Btn=>Btn1, Click=>Click1, LongClick=>LongClick1);
	dut_autorepeat_on: entity work.button
		generic map (autorepeat=>true)
		port map (Clk=>Clk, Btn=>Btn2, Click=>Click2, LongClick=>LongClick2);
end architecture;