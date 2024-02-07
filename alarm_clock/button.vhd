-- Processing button presses

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity button is
	generic (
		-- clock cycles for detection of button short press and release
		press: integer := 2_000_000; -- 40 ms
		-- clock cycles for detection of button long press and release
		long: integer := 52_000_000; -- 1.040 s
		-- autorepeat period (clock cycles)
		repeat: integer := 25_000_000; -- 500 ms
		-- true: enable autorepeat, send repeated Click
		-- false: disable autorepeat, send Click, then LongClick
		autorepeat: boolean := false
	);
	port (
		Clk: in std_logic; -- the main system clock
		Btn: in std_logic; -- the button input
		Click: out std_logic; -- the button was pressed or autorepeat fired
		LongClick: out std_logic; -- the button was pressed for a longer time
		Pressed: out std_logic -- the button is held pressed
	);
end entity;

architecture main of button is
begin
	process (Clk) is
		variable cnt: integer := 0;
		variable repeat_cnt: integer := 0;
		variable long_cnt: integer := 0;
		variable press_state: std_logic := '0';
	begin
		if rising_edge(Clk) then
			Click <= '0';
			LongClick <= '0';
			if Btn /= '0' then
				cnt := 0;
				long_cnt := 0;
				press_state := '0';
			else
				if cnt <= press then
					if cnt = press then
						Click <= '1';
						repeat_cnt := 1;
						press_state := '1';
					end if;
					cnt := cnt + 1;
				else
					if autorepeat then
						if repeat_cnt < repeat then
							repeat_cnt := repeat_cnt + 1;
						else
							repeat_cnt := 1;
							Click <= '1';
						end if;							
					end if;
				end if;
				if long_cnt <= long then
					if long_cnt = long then
						LongClick <= '1';
					end if;
					long_cnt := long_cnt + 1;
				end if;
			end if;
			Pressed <= press_state;
		end if;
	end process;
end architecture;