-- Alarm clock control (a state machine controlled by buttons)

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity control is
	port (
		-- input
		Clk: in std_logic; -- the main system clock
		AlarmTime: in std_logic; -- the alarm time is now (edge)
		CtrlSel: in std_logic; -- select views and digits (edge)
		CtrlUp: in std_logic; -- increase a value (edge)
		CtrlDown: in std_logic; -- decrease a value (edge)
		CtrlSet: in std_logic; -- enter set mode (edge)
		StopAlarm: in std_logic; -- stop sounding alarm (edge)
		-- output
		SoundAlarm: out std_logic; -- play the alarm sound (level)
		RstClk: out std_logic; -- reset realtime clock (edge)
		AlarmShow: out std_logic; -- show alarm on display (level)
		AlarmActive: out std_logic; -- alarm is enabled (level)
		SelHour: out std_logic; -- select hours for setting (level)
		SelMin: out std_logic; -- select minutes for setting (level)
		StepUp: out std_logic; -- increate the selected value (edge)
		StepDown: out std_logic -- decrease the selected value (edge)
	);
end entity;

architecture main of control is
begin
	SoundAlarm <= '0';
	RstClk <= '0';
	AlarmShow <= '0';
	AlarmActive <= '0';
	SelHour <= '0';
	SelMin <= '0';
	StepUp <= '0';
	StepDown <= '0';
	-- TODO
end;