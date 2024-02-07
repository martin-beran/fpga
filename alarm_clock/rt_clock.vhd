-- Real-time clock with period 1 s

library ieee;
use ieee.std_logic_1164.all;

entity rt_clock is
	generic (
		-- frequency of the input clock
		hz: integer := 50_000_000;
		-- divider of the fast clock
		fast_div: integer := 2
	);
	port (
		Clk: in std_logic; -- input clock
		Rst: in std_logic; -- reset internal counter to 0
		RTC: out std_logic; -- output clock
		Fast: out std_logic -- fast clock (used for blinking)
	);
end entity rt_clock;

architecture main of rt_clock is
	constant fast_period: integer := hz / fast_div;
begin
	process (Clk, Rst) is
		variable counter, fast_cnt: integer := 0;
	begin
		if Rst = '1' then
			counter := 0;
			fast_cnt := 0;
			RTC <= '0';
			Fast <= '0';
		elsif rising_edge(Clk) then
			RTC <= '0';
			Fast <= '0';
			counter := counter + 1;
			fast_cnt := fast_cnt + 1;
			if counter = hz then
				counter := 0;
				RTC <= '1';
			end if;
			if fast_cnt = fast_period then
				fast_cnt := 0;
				Fast <= '1';
			end if;
		end if;
	end process;
end architecture;