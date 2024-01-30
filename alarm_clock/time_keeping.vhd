-- Time keeping

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;
use work.pkg_display_4hex.all;

entity time_keeping is
	port (
		Clk: in std_logic; -- the main system clock
		RTC: in std_logic; -- the real time clock
		RstSec: in std_logic; -- reset seconds to 0
		AlarmShow: in std_logic; -- display alarm
		SelHour: in std_logic; -- select hours for setting
		SelMin: in std_logic; -- select minutes for setting
		StepUp: in std_logic; -- increase the selected value
		StepDown: in std_logic; -- decrease the selected value
		Display: out display_in_t -- controlling display
	);
end entity;

architecture main of time_keeping is
begin
	-- TODO
end architecture;