library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

-- Cyclic counter from 0 to 15

entity counter16 is
	generic (
		period: positive := 50_000_000
	);
	port (
		clk: in std_logic;
		N: out val_t
	);
end entity;

architecture main of counter16 is
begin
	process (clk) is
		variable tick: integer := 0;
		variable state: val_t := to_val_t(0);
	begin
		if rising_edge(clk) then
			tick := tick + 1;
			if tick = period then
				state := state + 1;
				tick := 0;
			end if;
		end if;
		N <= state;
	end process;
end architecture;