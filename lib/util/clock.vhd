-- Clock adapters

library ieee;
use ieee.std_logic_1164.all;

package pkg_clock is
	-- Divider of an input clock frequency.
	-- Generates pulses of a length equal to the period of the master clock at
	-- some rising edges of the input clock.
	component clock_divider is
		generic (
			-- if false, then divide frequency of Clk and ignore I
			use_I: boolean := false;
			-- number of input clock periods between output pulses
			factor: positive
		);
		port (
			-- the master system clock
			Clk: in std_logic;
			-- Reset and start from the beginning
			Rst: in std_logic;
			-- the input clock
			I: in std_logic := '1';
			-- the output clock
			O: out std_logic
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
library lib_util;
use lib_util.pkg_clock.all;

entity clock_divider is
	generic (
		use_I: boolean;
		factor: positive
	);
	port (
		Clk, Rst, I: in std_logic;
		O: out std_logic
	);
end entity;

architecture main of clock_divider is
	signal f: integer range 0 to factor := 0;
begin
	O <= '1' when Rst /= '1' and I = '1' and f = 0 else '0';
	process (Clk, Rst, I) is
		variable prev_i, prev_rst: std_logic := '0';
	begin
		if rising_edge(Clk) then
			if prev_rst = '1' then
				prev_i := '0';
				f <= 0;
			else
				if not use_I or (I = '0' and prev_i /= '0') then
					if f < factor - 1 then
						f <= f + 1;
					else
						f <= 0;
					end if;
				end if;
			end if;
			if use_I then
				prev_i := I;
			end if;
			prev_rst := Rst;
		end if;
	end process;
end architecture;