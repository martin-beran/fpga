-- PS/2 keyboard port controller

library ieee;
use ieee.std_logic_1164.all;

package pkg_ps2 is
	component ps2 is
		port (
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
	);
end entity;

architecture main of ps2 is
begin
end architecture;