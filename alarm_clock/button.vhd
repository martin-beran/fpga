-- Processing button presses

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;
use work.pkg_display_4hex.all;

entity button is
	generic (
		-- clock cycles for detection of button short press or release
		press: integer := 2_000_000; -- 40 ms
		-- clock cycles for detection of button long press
		long: integer := 50_000_000; -- 1 s
		-- autorepeat period (clock cycles)
		repeat: integer := 10_000_000; -- 200 ms
		-- true: enable autorepeat, send repeated Click
		-- false: disable autorepeat, send Click, then LongClick
		autorepeat: boolean := false
	);
	port (
		Clk: in std_logic; -- the main system clock
		Btn: in std_logic; -- the button input
		Click: out std_logic; -- the button was pressed or autorepeat fired
		LongClick: out std_logic -- the button was pressed for a longer time
	);
end entity;

architecture main of button is
begin
	Click <= '0';
	LongClick <='0';
	-- TODO
end architecture;