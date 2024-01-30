-- Various common definitions

library ieee;
use ieee.std_logic_1164.all;

package common is
	-- LEDs from left to right (active '0')
	subtype led4_t is std_logic_vector(1 to 4);
end package;

package body common is
end package body;