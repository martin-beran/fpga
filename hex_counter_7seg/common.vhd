library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package common is
	subtype val_t is unsigned(3 downto 0);
	subtype digit7_t is std_logic_vector(6 downto 0);
	function to_val_t(constant n: integer) return val_t;
end package;

package body common is
	function to_val_t(constant n: integer) return val_t is
	begin
		return to_unsigned(n, 4);
	end function;
end package body;