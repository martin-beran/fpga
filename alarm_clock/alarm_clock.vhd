-- Alarm clock main entity

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;
use work.pkg_display_4hex.all;

entity alarm_clock is
	port (
		Clk: in std_logic; -- the main system clock
		BtnSelect: in std_logic; -- button for selecting views and digits
		BtnUp: in std_logic; -- button for increasing a value
		BtnDown: in std_logic; -- button for decreasing a value
		BtnSet: in std_logic; -- button for entering set mode
		Display: out display4x7_t; -- clock display (4 x 7 segments)
		LED: out led4_t; -- 4 LEDs
		Speaker: out std_logic -- sound output
	);
end entity;

architecture main of alarm_clock is
	signal Sel, Up, Down, Set, SetClick, AnyBtn: std_logic; -- processed buttons
	signal RTC, BlinkClk: std_logic;
	signal RstClk, AlarmNow, SoundAlarm, ClockSecShow, AlarmShow, AlarmActive: std_logic;
	signal SelHour, SelMin, StepUp, StepDown: std_logic;
	signal DisplayCtrl: display_in_t;
begin
	-- handle buttons
	button_select: entity work.button(main) port map (Clk=>Clk, Btn=>BtnSelect, Click=>Sel);
	button_up: entity work.button(main) generic map (autorepeat=>true) port map (Clk=>Clk, Btn=>BtnUp, Click=>Up);
	button_down: entity work.button(main) generic map (autorepeat=>true) port map (Clk=>Clk, Btn=>BtnDown, Click=>Down);
	button_set: entity work.button(main) port map (Clk=>Clk, Btn=>BtnSet, Click=>SetClick, LongClick=>Set);
	AnyBtn <= Sel or Up or Down or SetClick;
	
	-- display and sound
	blink: process (Clk, RTC) is
		variable state: std_logic := '0';
	begin
		if rising_edge(Clk) and RTC = '1' then
			state := not state;
		end if;
		BlinkClk <= state;
	end process;
	LED(1) <= not AlarmShow;
	LED(2) <= not (SoundAlarm and BlinkClk);
	LED(3) <= not (SoundAlarm and BlinkClk);
	LED(4) <= not AlarmActive;
	display_time: entity work.display_4hex(main) port map (Clk=>Clk, BlinkClk=>BlinkClk, Ctrl=>DisplayCtrl, Display=>Display);
	sound: entity work.sound(main) port map (Clk=>Clk, Play=>SoundAlarm, Speaker=>Speaker);
	
	-- time keeping
	rt_clock: entity work.rt_clock(main) port map (Clk=>Clk, Rst=>RstClk, RTC=>RTC);
	time_keeping: entity work.time_keeping(main)
		port map (
			Clk=>Clk, RTC=>RTC, RstClockSec=>RstClk,
			ClockSecShow=>ClockSecShow, AlarmShow=>AlarmShow,
			SelHour=>SelHour, SelMin=>SelMin, StepUp=>StepUp, StepDown=>StepDown,
			Display=>DisplayCtrl, AlarmNow=>AlarmNow
		);
	
	-- controller
	control: entity work.control(main)
		port map(
			Clk=>Clk, AlarmNow=>AlarmNow,
			CtrlSel=>Sel, CtrlUp=>Up, CtrlDown=>Down, CtrlSet=>Set, CtrlSave=>SetClick,
			StopAlarm=>AnyBtn, SoundAlarm=>SoundAlarm, RstClockSec=>RstClk,
			ClockSecShow=>ClockSecShow, AlarmShow=>AlarmShow, AlarmActive=>AlarmActive,
			SelHour=>SelHour, SelMin=>SelMin, StepUp=>StepUp, StepDown=>StepDown
		);
end architecture;