-- A generic multiplexer N-to-1

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg_multiplexer is
	type mux_input_t is array (natural range <>) of std_logic_vector;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_multiplexer.all;

entity multiplexer is
	generic (
		inputs: positive; -- number of inputs
		bits: positive -- width of each input in bits
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