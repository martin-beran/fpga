-- MB50: System clock device (it ticks with frequency HZ and generates an interrupts on each tick)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;
use work.sys_params.CPU_HZ, work.sys_params.HZ;

entity system_clock is
	port (
		-- CPU clock
		Clk: in std_logic;
		-- Reset
		Rst: in std_logic;
		-- The current clock value
		Value: out word_t;
		-- The clock tick interrupt line
		Intr: out std_logic
	);
end entity;

architecture main of system_clock is
begin
	process (Clk, Rst) is
		variable counter: natural := 0;
		variable v: word_t := to_word(0);
	begin
		Intr <= '0';
		if Rst = '1' then
			counter := 0;
			v := to_word(0);
		elsif rising_edge(Clk) then
			counter := counter + 1;
			if counter = HZ / CPU_HZ then
				counter := 0;
				v := v + 1;
				Intr <= '1';
			end if;
		end if;
		Value <= v;
	end process;
end architecture;