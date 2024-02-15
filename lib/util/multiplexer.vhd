-- Generic N-to-1 multiplexer

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg_multiplexer is
	type mux_input_t is array (natural range <>) of std_logic_vector;
	component multiplexer is
		generic (
			-- number of inputs
			inputs: positive;
			-- width of each input in bits
			bits: positive
		);
		port (
			-- pass this element of I to O
			Sel: in natural range 0 to inputs - 1;
			-- inputs
			I: in mux_input_t(0 to inputs - 1);
			-- output
			O: out std_logic_vector(bits - 1 downto 0)
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_util;
use lib_util.pkg_multiplexer.all;

entity multiplexer is
	generic (
		inputs, bits: positive
	);
	port (
		Sel: in natural range 0 to inputs - 1;
		I: in mux_input_t(0 to inputs - 1);
		O: out std_logic_vector(bits - 1 downto 0)
	);
end entity;

architecture main of multiplexer is
begin
	O <= I(Sel);
end architecture;