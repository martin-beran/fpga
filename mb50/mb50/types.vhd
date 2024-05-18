-- Basic common types used throughout the MB50 computer

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package types is
	-- Type of a byte (8 bits)
	subtype byte_t is unsigned(7 downto 0);
	pure function to_byte(i: natural) return byte_t;
	-- Type of a word (16 bits)
	subtype word_t is unsigned(15 downto 0);
	pure function to_word(i: natural) return word_t;
	-- Type of a memory address
	-- Currently it is a word, but in future, an address space larger than the word size could be supported
	subtype addr_t is word_t;
	-- Type of a register index (4 bits for 16 registers)
	subtype reg_idx_t is unsigned(3 downto 0);
	pure function reg_idx_max return natural;
	pure function to_reg_idx(i: natural) return reg_idx_t;
end package;

package body types is
	pure function reg_idx_max return natural is
		constant last_reg_idx: reg_idx_t := (others=>'1');
	begin
		return to_integer(last_reg_idx);
	end;
	pure function to_byte(i: natural) return byte_t is
	begin
		return to_unsigned(i, byte_t'length);
	end;
	pure function to_word(i: natural) return byte_t is
	begin
		return to_unsigned(i, word_t'length);
	end;
	pure function to_reg_idx(i: natural) return reg_idx_t is
	begin
		return to_unsigned(i, reg_idx_t'length);
	end;
end package body;