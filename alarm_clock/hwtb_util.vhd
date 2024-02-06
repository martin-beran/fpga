-- Hardware testing utilities

library ieee;
use ieee.std_logic_1164.all;

-- Indicate rising edge of a signal by LED

entity led_rising_edge is
	generic (
		duration: positive := 5_000_000 -- keep LED on for this number of Clk periods (0.1 s)
	);
	port (
		Clk: in std_logic; -- clock
		I: in std_logic; -- input signal
		LED: out std_logic -- output LED
	);
end entity;

architecture main of led_rising_edge is
	signal edge: std_logic;
	signal state: std_logic_vector(0 to 1);
begin
	edge <= '1' when state(0) = '1' and state(1) /= '1' else '0';
	process (Clk) is
		variable cnt: natural := 0;
	begin
		if rising_edge(Clk) then
			state(1) <= state(0);
			state(0) <= I;
			if edge = '1' then
				cnt := 1;
				LED <= '0';
			elsif cnt >= 1 and cnt <= duration then
				cnt := cnt + 1;
				LED <= '0';
			else
				cnt := 0;
				LED <= '1';
			end if;
		end if;
	end process;
end architecture;