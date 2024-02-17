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
use lib_io.pkg_seg7.all;
use lib_io.pkg_speaker.all;

entity demo_lib_led is
	port (
		Clk: in std_logic;
		RstBtn: in std_logic;
		Button: in std_logic_vector(3 downto 0);
		LED: out std_logic_vector(3 downto 0);
		Speaker: out std_logic;
		DIG: out std_logic_vector(3 downto 0);
		SEG: out std_logic_vector(7 downto 0)
	);
end entity;

architecture main of demo_lib_led is
	signal rst: std_logic;
	signal ms100, sync100, ms200, ms300, ms500, sync500, ms2000: std_logic;
	signal button_state: std_logic_vector(3 downto 0);
	signal led_state: std_logic_vector(3 downto 0);
	signal led_w: std_logic_vector(3 downto 0);
	signal note: unsigned(half_period_bits - 1 downto 0);
	signal speaker_w: std_logic;
	signal seg7_i: unsigned(3 downto 0) := to_unsigned(15, 4);
	signal seg7_cp: std_logic := '0';
	signal seg7: seg7_t(3 downto 0);
	signal seg7_w: std_logic_vector(3 downto 0) := "0011";
begin
	-- handle reset button
	reset: reset_button generic map (initial_rst=>true) port map (Clk=>Clk, RstBtn=>RstBtn, Rst=>rst);
	-- generate pulses with double the target frequency
	clock_ms100: clock_divider generic map (factor=>crystal_hz/20) port map (Clk=>Clk, Rst=>rst, O=>ms100, OSync=>sync100);
	clock_ms200: clock_divider generic map (factor=>2) port map (Clk=>Clk, Rst=>rst, ISync=>sync100, O=>ms200, OSync=>open);
	clock_ms300: clock_divider generic map (factor=>3) port map (Clk=>Clk, Rst=>rst, ISync=>sync100, O=>ms300, OSync=>open);
	clock_ms500: clock_divider generic map (factor=>5) port map (Clk=>Clk, Rst=>rst, ISync=>sync100, O=>ms500, OSync=>sync500);
	clock_ms2000: clock_divider generic map (factor=>4) port map (Clk=>Clk, Rst=>rst, ISync=>sync500, O=>ms2000, OSync=>open);
	-- generate signals with the target frequency and duty cycle 50 %
	blink_ms100: half_f_duty_50 port map (Clk=>Clk, Rst=>rst, I=>ms100, O=>led_state(0));
	blink_ms200: half_f_duty_50 port map (Clk=>Clk, Rst=>rst, I=>ms200, O=>led_state(1));
	blink_ms300: half_f_duty_50 port map (Clk=>Clk, Rst=>rst, I=>ms300, O=>led_state(2));
	blink_ms500: half_f_duty_50 port map (Clk=>Clk, Rst=>rst, I=>ms500, O=>led_state(3));
	-- control LEDs
	led_ctl: led_group port map (Clk=>Clk, Rst=>rst, I=>led_state, W=>led_w, LED=>LED);
	-- control 7-segment display
	seg7_display: seg7_raw
		port map (
			Clk=>Clk, Rst=>rst, Seg7=>seg7, DP=>"0100", EnaSeg7=>led_w(0)&led_w(1)&led_w(2)&led_w(3),
			EnaDP=>"1111", WSeg7=>seg7_w, WDP=>"1111", DIG=>DIG, SEG=>SEG
		);
	seg7_mux: seg7_decoder port map (I=>seg7_i, CP=>seg7_cp, O=>seg7(0));
	seg7(1) <= seg7(0);
	seg7(2) <= seg7(0);
	seg7(3) <= seg7(0);
	process (Clk) is 
	begin
		if rising_edge(Clk) then
			seg7_cp <= not seg7_cp;
			seg7_w <= not seg7_w;
			if rst = '1' then
				seg7_i <= to_unsigned(15, 4);
			elsif ms2000 = '1' then
				seg7_i <= seg7_i + 1;
			end if;
		end if;
	end process;
	-- control speaker
	speaker_ctl: play_sound port map (Clk=>Clk, Rst=>rst, I=>note, W=>speaker_w, Speaker=>Speaker);
	note <=
		to_unsigned(note_half_period(note_C4), half_period_bits) when button_state(0) = '1' else
		to_unsigned(note_half_period(note_E4), half_period_bits) when button_state(1) = '1' else
		to_unsigned(note_half_period(note_G4), half_period_bits) when button_state(2) = '1' else
		to_unsigned(note_half_period(note_C4) / 2, half_period_bits) when button_state(3) = '1' else
		to_unsigned(note_half_period(note_Pause), half_period_bits);
	-- buttons; if at least one pressed, only LEDs corresponding to pressed buttons are updated
	button_in: button_group port map (Clk=>Clk, Rst=>rst, Button=>Button, O=>button_state);
	led_w <= (others=>'1') when button_state = "0000" else button_state;
	speaker_w <= '0' when button_state = "0000" else '1';
end architecture;
	