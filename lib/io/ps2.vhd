-- PS/2 keyboard port controller

library ieee;
use ieee.std_logic_1164.all;

package pkg_ps2 is
	component ps2 is
		port (
			-- the master system clock
			Clk: in std_logic;
			-- reset
			Rst: in std_logic;
			-- PS/2 clock
			Ps2Clk: inout std_logic;
			-- PS/2 data
			Ps2Data: inout std_logic
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_util;
use lib_util.pkg_clock.all;
use lib_util.pkg_shift_register.all;
library lib_io;
use lib_io.pkg_crystal.crystal_hz;
use lib_io.pkg_ps2.all;

entity ps2 is
	port (
		Clk, Rst: in std_logic;
		Ps2Clk, Ps2Data: inout std_logic
	);
end entity;

architecture main of ps2 is
begin
	-- TODO
	Ps2Clk <= 'H';
	Ps2Data <= 'H';
end architecture;