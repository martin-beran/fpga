-- Demo of library packages: lib_util.pkg_clock, lib_io.led, lib_io.button
-- 4 LEDs blinking with frequencies 100, 200, 300, and 500 ms.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_util;
use lib_util.pkg_clock.all;
library lib_io;
use lib_io.pkg_button.all;
use lib_io.pkg_crystal.all;
use lib_io.pkg_led.all;
use lib_io.pkg_reset.all;
use lib_io.pkg_speaker.all;

entity demo_lib_led is
	port (
		Clk: in std_logic;
		RstBtn: in std_logic;
		Button: in std_logic_vector(3 downto 0);
		LED: out std_logic_vector(3 downto 0);
		Speaker: out std_logic
	);
end entity;

architecture main of demo_lib_led is
	signal rst: std_logic;
	signal ms100, ms200, ms300, ms500: std_logic;
	signal button_state: std_logic_vector(3 downto 0);
	signal led_state: std_logic_vector(3 downto 0);
	signal led_select: std_logic_vector(3 downto 0);
	signal note: unsigned(half_period_bits - 1 downto 0);
	signal speaker_set: std_logic;
begin
	-- handle reset button
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
	-- control speaker
	speaker_ctl: play_sound port map (Clk=>Clk, Rst=>rst, I=>note, Set=>speaker_set, Speaker=>Speaker);
	note <=
		to_unsigned(note_half_period(note_C4), half_period_bits) when button_state(0) = '1' else
		to_unsigned(note_half_period(note_E4), half_period_bits) when button_state(1) = '1' else
		to_unsigned(note_half_period(note_G4), half_period_bits) when button_state(2) = '1' else
		to_unsigned(note_half_period(note_C4) / 2, half_period_bits) when button_state(3) = '1' else
		to_unsigned(note_half_period(note_Pause), half_period_bits);
	-- buttons; if at least one pressed, only LEDs corresponding to pressed buttons are updated
	button_in: button_group port map (Clk=>Clk, Rst=>rst, Button=>Button, O=>button_state);
	led_select <= (others=>'1') when button_state = "0000" else button_state;
	speaker_set <= '0' when button_state = "0000" else '1';
end architecture;
	