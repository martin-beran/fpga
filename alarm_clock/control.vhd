-- Alarm clock control (a state machine controlled by buttons)

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity control is
	port (
		-- input
		Clk: in std_logic; -- the main system clock
		AlarmNow: in std_logic; -- the alarm time is now (edge)
		CtrlSel: in std_logic; -- select views and digits (edge)
		CtrlUp: in std_logic; -- increase a value (edge)
		CtrlDown: in std_logic; -- decrease a value (edge)
		CtrlSet: in std_logic; -- enter set mode (edge)
		CtrlSave: in std_logic; -- exit set mode (edge)
		StopAlarm: in std_logic; -- stop sounding alarm (edge)
		-- output
		SoundAlarm: out std_logic; -- play the alarm sound (level)
		RstClockSec: out std_logic; -- reset seconds to 00 (edge)
		ClockSecShow: out std_logic; -- show seconds in clock display (level)
		AlarmShow: out std_logic; -- show alarm on display (level)
		AlarmActive: out std_logic; -- alarm is enabled (level)
		SelHour: out std_logic; -- select hours for setting (level)
		SelMin: out std_logic; -- select minutes for setting (level)
		SelSec: out std_logic; -- select seconds for setting (level)
		StepUp: out std_logic; -- increase the selected value (edge)
		StepDown: out std_logic -- decrease the selected value (edge)
	);
end entity;

architecture main of control is
	signal AlarmOnOff: boolean;
begin
	-- View FSM
	view_fsm: block is
		type state is (ClockHM, ClockS, ClockSetH, ClockSetM, ClockSetS, AlarmHM, AlarmSetH, AlarmSetM);
		signal current_state, next_state: state := ClockHM;
	begin
		step: process (Clk) is
		begin
			if rising_edge(Clk) then
				current_state <= next_state;
			end if;
		end process;
		transition: process (current_state, CtrlSel, CtrlUp, CtrlDown, CtrlSet, CtrlSave) is
		begin
			AlarmOnOff <= current_state = AlarmHM;
			RstClockSec <= '0';
			ClockSecShow <= '0';
			AlarmShow <= '0';
			SelHour <= '0';
			SelMin <= '0';
			SelSec <= '0';
			StepUp <= '0';
			StepDown <= '0';
			if current_state = ClockSetH or current_state = ClockSetM or
				current_state = AlarmSetH or current_state = AlarmSetM
			then
				if CtrlUp = '1' then
					StepUp <= '1';
				elsif CtrlDown = '1' then
					StepDown <= '1';
				end if;
			elsif current_state = ClockSetS then
				if CtrlUp = '1' or CtrlDown = '1' then
					RstClockSec <= '1';
				end if;
			end if;
			next_state <= current_state;
			case current_state is
				when ClockHM =>
					if CtrlSel = '1' then
						next_state <= ClockS;
					elsif CtrlSet = '1' then
						next_state <= ClockSetH;
					end if;
				when ClockS =>
					if CtrlSel = '1' then
						next_state <= AlarmHM;
					end if;
					ClockSecShow <= '1';
				when ClockSetH =>
					if CtrlSave = '1' then
						next_state <= ClockHM;
					elsif CtrlSel = '1' then
						next_state <= ClockSetM;
					end if;
					SelHour <= '1';
				when ClockSetM =>
					if CtrlSave = '1' then
						next_state <= ClockHM;
					elsif CtrlSel = '1' then
						next_state <= ClockSetS;
					end if;
					SelMin <= '1';
				when ClockSetS =>
					if CtrlSave = '1' then
						next_state <= ClockHM;
					elsif CtrlSel = '1' then
						next_state <= ClockSetH;
					end if;
					ClockSecShow <= '1';
					SelSec <= '1';
				when AlarmHM =>
					if CtrlSel then
						next_state <= ClockHM;
					elsif CtrlSet = '1' then
						next_state <= AlarmSetH;
					end if;
					AlarmShow <= '1';
				when AlarmSetH =>
					if CtrlSave = '1' then
						next_state <= AlarmHM;
					elsif CtrlSel = '1' then
						next_state <= AlarmSetM;
					end if;
					AlarmShow <= '1';
					SelHour <= '1';
				when AlarmSetM =>
					if CtrlSave = '1' then
						next_state <= AlarmHM;
					elsif CtrlSel = '1' then
						next_state <= AlarmSetH;
					end if;
					AlarmShow <= '1';
					SelMin <= '1';
				when others =>
					null;
			end case;
		end process;
	end block;

	-- Alarm FSM
	alarm_fsm: block is
		type state is (Disabled, Enabled, Sounding);
		signal current_state, next_state: state := Disabled;
	begin
		step: process (Clk) is
		begin
			if rising_edge(Clk) then
				current_state <= next_state;
			end if;
		end process;
		transition: process (current_state, AlarmOnOff, AlarmNow, CtrlUp, CtrlDown, StopAlarm) is
		begin
			SoundAlarm <= '0';
			AlarmActive <= '0';
			next_state <= current_state;
			case current_state is
				when Disabled =>
					if AlarmOnOff and (CtrlUp = '1' or CtrlDown = '1') then
						next_state <= Enabled;
					end if;
				when Enabled =>
					if AlarmOnOff and (CtrlUp = '1' or CtrlDown = '1') then
						next_state <= Disabled;
					elsif AlarmNow = '1' then
						next_state <= Sounding;
					end if;
					AlarmActive <= '1';
				when Sounding =>
					if StopAlarm then
						next_state <= Enabled;
					end if;
					SoundAlarm <= '1';
					AlarmActive <= '1';
				when others =>
					null;
			end case;
		end process;
	end block;
end;