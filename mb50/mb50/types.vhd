-- Basic common types

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package types is
	-- Type of a byte (8 bits)
	subtype byte_t is unsigned(7 downto 0);
	-- Type of a word (16 bits)
	subtype word_t is unsigned(15 downto 0);
	-- Type of a memory address
	-- Currently it is a word, but in future, an address space larger than the word size could be supported
	subtype addr_t is word_t;
end package;