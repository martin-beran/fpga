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
			factor: positive;
			-- number of input clock periods before the first pulse
			phase: natural := 0
		);
		port (
			-- the master system clock
			Clk: in std_logic;
			-- Reset and start from the beginning
			Rst: in std_logic;
			-- the input clock
			I: in std_logic := '0';
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
		factor: positive;
		phase: natural
	);
	port (
		Clk, Rst, I: in std_logic;
		O: out std_logic
	);
end entity;

architecture main of clock_divider is
begin
	process (Clk, Rst, I) is
		variable f: integer range 0 to factor := 0;
		variable p: integer range 0 to phase := 0;
		variable prev: std_logic := '0';
	begin
		if rising_edge(Clk) then
			O <= '0';
			if Rst = '1' then
				prev := '0';
				f := 0;
				p := 0;
			elsif not use_I or (I = '1' and prev /= '1') then
				if phase > 0 and p < phase then
					p := p + 1;
				else
					if f = 0 then
						O <= '1';
					end if;
					f := f + 1;
					if f = factor then
						f := 0;
					end if;
				end if;
			end if;
			if use_I then
				prev := I;
			end if;
		end if;
	end process;
end architecture;