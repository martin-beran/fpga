-- Real-time clock with period 1 s

library ieee;
use ieee.std_logic_1164.all;

entity rt_clock is
	generic (
		-- frequency of the input clock
		hz: integer := 50_000_000
	);
	port (
		Clk: in std_logic; -- input clock
		Rst: in std_logic; -- reset internal counter to 0
		RTC: out std_logic -- output clock
	);
end entity rt_clock;

architecture main of rt_clock is
begin
	process (Clk, Rst) is
		variable counter: integer := 0;
	begin
		if Rst = '1' then
			counter := 0;
			RTC <= '0';
		elsif rising_edge(Clk) then
			RTC <= '0';
			counter := counter + 1;
			if counter = hz then
				counter := 0;
				RTC <= '1';
			end if;
		end if;
	end process;
end architecture;