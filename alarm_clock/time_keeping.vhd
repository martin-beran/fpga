-- Time keeping

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;
use work.pkg_display_4hex.all;
use work.pkg_multiplexer.all;

entity time_keeping is
	port (
		Clk: in std_logic; -- the main system clock
		RTC: in std_logic; -- the real time clock
		RstClockSec: in std_logic; -- reset seconds to 00
		ClockSecShow: in std_logic; -- display seconds in clock view
		AlarmShow: in std_logic; -- display alarm
		SelHour: in std_logic; -- select hours for setting
		SelMin: in std_logic; -- select minutes for setting
		SelSec: in std_logic; -- select seconds for setting
		StepUp: in std_logic; -- increase the selected value
		StepDown: in std_logic; -- decrease the selected value
		Display: out display_in_t; -- controlling display
		AlarmNow: out std_logic -- the alarm time is now
	);
end entity;

architecture main of time_keeping is
	type mux_sel_t is (mux_hm, mux_s, mux_alarm);
	constant mux_sel_n: positive := mux_sel_t'pos(mux_sel_t'right) + 1;
	type mux_display is array (digits_t'range, mux_sel_t) of digit_t;
	signal Rst,
		ClockHourUp, ClockHourDown, ClockMinUp, ClockMinDown,
		AlarmHourUp, AlarmHourDown, AlarmMinUp, AlarmMinDown,
		ClockHourCInc, ClockHourCDec, ClockMinCInc, ClockMinCDec, ClockSecCInc, ClockSecCDec,
		ClockHMCInc, ClockHMCDec, ClockCarry, ClockMSCInc, ClockMSCDec,
		AlarmHourCInc, AlarmHourCDec, AlarmMinCInc, AlarmMinCDec: std_logic;
	signal MuxDisplay: mux_display;
	signal MuxSel: mux_sel_t;
begin
	Rst <= '0'; -- ready for reset, but currently not implemented
	ClockCarry <= not ((SelHour or SelMin) and (StepUp or StepDown));
	
	-- Up/Down signals for individual counters
	ClockHourUp <= RTC or (not AlarmShow and not ClockSecShow and SelHour and StepUp);
	ClockHourDown <= not AlarmShow and not ClockSecShow and SelHour and StepDown;
	ClockMinUp <= RTC or (not AlarmShow and not ClockSecShow and SelMin and StepUp);
	ClockMinDown <= not AlarmShow and not ClockSecShow and SelMin and StepDown;
	AlarmHourUp <= AlarmShow and SelHour and StepUp;
	AlarmHourDown <= AlarmShow and SelHour and StepDown;
	AlarmMinUp <= AlarmShow and SelMin and StepUp;
	AlarmMinDown <= AlarmShow and SelMin and StepDown;
	
	-- Display control
	Display.wr <= '1';
	Display.digit_ena <=
		"0011" when not AlarmShow and ClockSecShow else
		"1111";
	Display.digit_blink <=
		"1100" when not ClockSecShow and SelHour else
		"0011" when not ClockSecShow and SelMin else
		"0011" when ClockSecShow and SelSec else
		"0000";
	Display.dp_ena <= "0100";
	Display.dp_blink <=
		"0100" when not AlarmShow and not ClockSecShow and not SelHour and not SelMin else
		"0000";

	-- Multiplexing clock HH:MM, clock .SS, alarm HH:MM to display
	build_mux: for i in MuxDisplay'range(1) generate
		signal ILV: mux_input_t(0 to mux_sel_n - 1)(digit_t'range);
		signal OLV: std_logic_vector(digit_t'range);
		signal MuxSelIdx: natural range 0 to mux_sel_n - 1;
	begin
		build_ilv: for j in MuxDisplay'range(2) generate
		begin
			ILV(mux_sel_t'pos(j)) <= std_logic_vector(MuxDisplay(i, j));
		end generate;
		Display.digits(i) <= unsigned(OLV);
		MuxSelIdx <= mux_sel_t'pos(MuxSel);
		mux: entity work.multiplexer generic map (inputs=>mux_sel_n, bits=>digit_t'length) port map (Sel=>MuxSelIdx, I=>ILV, O=>OLV);
	end generate;
	
	MuxSel <=
		mux_alarm when AlarmShow else
		mux_s when ClockSecShow else
		mux_hm;
	
	-- Not displayed in .SS view, silence Quartus compiler warning about initial value 'X'
	MuxDisplay(3, mux_s) <= "0000";
	MuxDisplay(2, mux_s) <= "0000";
	
	-- Individual digit counters
	-- We use 4bit values to map them easily to display_in_t.digits
	clock_hour1: entity work.counter
		generic map (bits=>4, max=>9, max2=>23)
		port map(Clk=>Clk, Rst=>Rst, Inc=>ClockHourUp, Dec=>ClockHourDown,
			InCInc=>ClockHMCInc, InCDec=>ClockHMCDec, InCarry=>ClockCarry,
			Value=>MuxDisplay(2, mux_hm), CInc=>ClockHourCInc, CDec=>ClockHourCDec);
	clock_hour10: entity work.counter
		generic map (bits=>4, max=>2)
		port map(Clk=>Clk, Rst=>Rst, Inc=>ClockHourUp, Dec=>ClockHourDown,
			InCInc=>ClockHourCInc, InCDec=>ClockHourCDec, InCarry=>'1',
			Value=>MuxDisplay(3, mux_hm));
	clock_min1: entity work.counter
		generic map (bits=>4, max=>9)
		port map(Clk=>Clk, Rst=>Rst, Inc=>ClockMinUp, Dec=>ClockMinDown,
			InCInc=>ClockMSCInc, InCDec=>ClockMSCDec, InCarry=>ClockCarry,
			Value=>MuxDisplay(0, mux_hm), CInc=>ClockMinCInc, CDec=>ClockMinCDec);
	clock_min10: entity work.counter
		generic map (bits=>4, max=>5)
		port map(Clk=>Clk, Rst=>Rst, Inc=>ClockMinUp, Dec=>ClockMinDown,
			InCInc=>ClockMinCInc, InCDec=>ClockMinCDec, InCarry=>'1',
			Value=>MuxDisplay(1, mux_hm), CInc=>ClockHMCInc, CDec=>ClockHMCDec);
	clock_sec1: entity work.counter
		generic map (bits=>4, max=>9)
		port map(Clk=>Clk, Rst=>RstClockSec, Inc=>RTC, Dec=>'0',
			InCInc=>'0', InCDec=>'0', InCarry=>'0',
			Value=>MuxDisplay(0, mux_s), CInc=>ClockSecCInc, CDec=>ClockSecCDec);
	clock_sec10: entity work.counter
		generic map (bits=>4, max=>5)
		port map(Clk=>Clk, Rst=>RstClockSec, Inc=>RTC, Dec=>'0',
			InCInc=>ClockSecCInc, InCDec=>ClockSecCDec, InCarry=>'1',
			Value=>MuxDisplay(1, mux_s), CInc=>ClockMSCInc, CDec=>ClockMSCDec);
	
	alarm_hour1: entity work.counter
		generic map (bits=>4, max=>9, max2=>23)
		port map(Clk=>Clk, Rst=>Rst, Inc=>AlarmHourUp, Dec=>AlarmHourDown,
			InCInc=>'0', InCDec=>'0', InCarry=>'0',
			Value=>MuxDisplay(2, mux_alarm), CInc=>AlarmHourCInc, CDec=>AlarmHourCDec);
	alarm_hour10: entity work.counter
		generic map (bits=>4, max=>2)
		port map(Clk=>Clk, Rst=>Rst, Inc=>AlarmHourUp, Dec=>AlarmHourDown,
			InCInc=>AlarmHourCInc, InCDec=>AlarmHourCDec, InCarry=>'1',
			Value=>MuxDisplay(3, mux_alarm));
	alarm_min1: entity work.counter
		generic map (bits=>4, max=>9)
		port map(Clk=>Clk, Rst=>Rst, Inc=>AlarmMinUp, Dec=>AlarmMinDown,
			InCInc=>'0', InCDec=>'0', InCarry=>'0',
			Value=>MuxDisplay(0, mux_alarm), CInc=>AlarmMinCInc, CDec=>AlarmMinCDec);
	alarm_min10: entity work.counter
		generic map (bits=>4, max=>5)
		port map(Clk=>Clk, Rst=>Rst, Inc=>AlarmMinUp, Dec=>AlarmMinDown,
			InCInc=>AlarmMinCInc, InCDec=>AlarmMinCDec, InCarry=>'1',
			Value=>MuxDisplay(1, mux_alarm));

	-- Indicate alarm now time
	alarm_now_test: process (Clk) is
		variable state: boolean := false;
		variable equal: boolean;
	begin
		if rising_edge(Clk) then
			equal :=
				MuxDisplay(0, mux_hm) = MuxDisplay(0, mux_alarm) and
				MuxDisplay(1, mux_hm) = MuxDisplay(1, mux_alarm) and
				MuxDisplay(2, mux_hm) = MuxDisplay(2, mux_alarm) and
				MuxDisplay(3, mux_hm) = MuxDisplay(3, mux_alarm);
			if not state and equal then
				AlarmNow <= '1';
				state := true;
			else
				AlarmNow <= '0';
				state := equal;
			end if;
		end if;
	end process;
end architecture;