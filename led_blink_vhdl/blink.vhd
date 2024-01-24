library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- two alternatively blinking LEDs

entity blink is
	generic (
		crystal_khz: integer := 50_000;
		period_ms: integer:= 1000
	);
	port (
		clk, start, stop: in std_logic;
		led1, led2: out std_logic := '1'
	);
end entity;

architecture main of blink is
begin
	process (clk) is
		variable cnt: integer := 0;
		variable state: std_logic := '0';
		variable running: boolean := true;
	begin
		if rising_edge(clk) then
			if stop = '0' then
				running := false;
			elsif start = '0' then
				running := true;
			end if;
			cnt := cnt + 1;
			if cnt = crystal_khz * period_ms then
				cnt := 0;
				state := not state;
			end if;
		end if;
		if running then
			led1 <= state;
			led2 <= not state;
		else
			led1 <= '1';
			led2 <= '1';
		end if;
	end process;
end architecture;