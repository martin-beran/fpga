-- Demo of library packages: lib_util.pkg_clock, lib_io.led, lib_io.button
-- 4 LEDs blinking with frequencies 100, 200, 300, and 500 ms.

library ieee;
use ieee.std_logic_1164.all;
library lib_util;
use lib_util.pkg_clock.all;
library lib_io;
use lib_io.pkg_button.all;
use lib_io.pkg_crystal.all;
use lib_io.pkg_led.all;
use lib_io.pkg_reset.all;

entity demo_lib_led is
	port (
		Clk: in std_logic;
		RstBtn: in std_logic;
		Button: in std_logic_vector(3 downto 0);
		LED: out std_logic_vector(3 downto 0)
	);
end entity;

architecture main of demo_lib_led is
	signal rst: std_logic;
	signal ms100, ms200, ms300, ms500: std_logic;
	signal button_state: std_logic_vector(3 downto 0);
	signal led_state: std_logic_vector(3 downto 0);
	signal led_select: std_logic_vector(3 downto 0);
begin
	-- reset button
	reset: reset_button port map (Clk=>Clk, RstBtn=>RstBtn, Rst=>rst);
	-- generate pulses with double the target frequency
	clock_ms100: clock_divider generic map (factor=>crystal_hz/20) port map (Clk=>Clk, Rst=>rst, O=>ms100);
	clock_ms200: clock_divider generic map (use_I=>true, factor=>2) port map (Clk=>Clk, Rst=>rst, I=>ms100, O=>ms200);
	clock_ms300: clock_divider generic map (use_I=>true, factor=>3) port map (Clk=>Clk, Rst=>rst, I=>ms100, O=>ms300);
	clock_ms500: clock_divider generic map (use_I=>true, factor=>5) port map (Clk=>Clk, Rst=>rst, I=>ms100, O=>ms500);
	-- generate signals with the target frequency and duty cycle 50 %
	blink_ms100: half_f_duty_50 port map (Clk=>Clk, Rst=>rst, I=>ms100, O=>led_state(0));
	blink_ms200: half_f_duty_50 port map (Clk=>Clk, Rst=>rst, I=>ms200, O=>led_state(1));
	blink_ms300: half_f_duty_50 port map (Clk=>Clk, Rst=>rst, I=>ms300, O=>led_state(2));
	blink_ms500: half_f_duty_50 port map (Clk=>Clk, Rst=>rst, I=>ms500, O=>led_state(3));
	-- control LEDs
	led_ctl: led_group port map (Clk=>Clk, Rst=>rst, I=>led_state, Sel=>led_select, LED=>LED);
	-- buttons; if at least one pressed, only LEDs corresponding to pressed buttons are updated
	button_in: button_group port map (Clk=>Clk, Rst=>rst, Button=>Button, O=>button_state);
	led_select <= (others=>'1') when button_state = "0000" else button_state;
end architecture;
	