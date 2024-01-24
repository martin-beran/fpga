library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- two pairs of alternatively blinking LEDs
-- uses two implementations of blinking on/off switch

entity blink is
	generic (
		crystal_khz: integer := 50_000;
		period_ms: integer:= 1000
	);
	port (
		clk, start, stop: in std_logic;
		led1, led2, led3, led4: out std_logic := '1'
	);
end entity;

architecture main of blink is
	signal running12: std_logic := '1';
begin
	running12 <=
		'0' when stop = '0' else
		'1' when start = '0' else
		unaffected;
	led12: process is
		variable cnt: integer := 0;
		variable state: std_logic := '0';
	begin
		cnt := cnt + 1;
		if cnt = crystal_khz * period_ms then
			cnt := 0;
			state := not state;
		end if;
		if running12 = '1' then
			led1 <= state;
			led2 <= not state;
		else
			led1 <= '1';
			led2 <= '1';
		end if;
		wait on clk until clk = '1';
	end process;
	led34: process (clk) is
		variable cnt: integer := 0;
		variable state: std_logic := '0';
		variable running34: boolean := true;
	begin
		if rising_edge(clk) then
			if stop = '0' then
				running34 := false;
			elsif start = '0' then
				running34 := true;
			end if;
			cnt := cnt + 1;
			if cnt = 2 * crystal_khz * period_ms then
				cnt := 0;
				state := not state;
			end if;
		end if;
		if running34 then
			led3 <= state;
			led4 <= not state;
		else
			led3 <= '1';
			led4 <= '1';
		end if;
	end process;
end architecture;