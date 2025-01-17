-- Basic common types (and some related constants and functions) used throughout the MB50 computer

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package types is
	-- Creates a vector of n identical bits
	pure function bit_to_vector(b: std_logic; n: positive) return std_logic_vector;
	-- Conversion from BOOLEAN to STD_LOGIC
	pure function to_std_logic(b: boolean) return std_logic;
	-- Type of a byte (8 bits)
	subtype byte_t is unsigned(7 downto 0);
	pure function to_byte(i: natural) return byte_t;
	pure function bit_to_byte(b: std_logic) return byte_t;
	-- Check that all bits of a byte are 'Z'.
	-- To be used instead of a equality test, which would always return false.
	pure function is_byte_z(b: byte_t) return boolean;
	-- Type of a word (16 bits)
	subtype word_t is unsigned(15 downto 0);
	pure function to_word(i: natural) return word_t;
	pure function bit_to_word(b: std_logic) return word_t;
	-- Check that all bits of a word are 'Z'.
	-- To be used instead of a equality test, which would always return false.
	pure function is_word_z(b: word_t) return boolean;
	-- Type of a memory address
	-- Currently it is a word, but in future, an address space larger than the word size could be supported
	subtype addr_t is word_t;
	-- Type of a register index (4 bits for 16 registers)
	subtype reg_idx_t is unsigned(3 downto 0);
	pure function reg_idx_max return natural;
	pure function to_reg_idx(constant i: natural) return reg_idx_t;
	-- Index of register IA (r13)
	constant reg_idx_ia: natural := 13;
	-- Index of register F (r14)
	constant reg_idx_f: natural := 14;
	-- Index of register PC (r15)
	constant reg_idx_pc: natural := 15;
	-- Type of flag bits allocated in register F
	subtype flags_t is std_logic_vector(7 downto 4);
	-- Indices of some bits in register F
	constant flags_idx_z: natural := 4;
	constant flags_idx_c: natural := 5;
	constant flags_idx_s: natural := 6;
	constant flags_idx_o: natural := 7;
	constant flags_idx_ie: natural := 8;
	constant flags_idx_exc: natural := 9;
	constant flags_idx_iexc: natural := 10;
	-- Type of exception/interrupt bits in register F
	subtype irq_t is std_logic_vector(15 downto 9);
end package;

package body types is

	pure function bit_to_vector(b: std_logic; n: positive) return std_logic_vector is
		constant v: std_logic_vector(n - 1 downto 0) := (others=>b);
	begin
		return v;
	end;
	
	pure function to_std_logic(b: boolean) return std_logic is
	begin
		if b then
			return '1';
		else
			return '0';
		end if;
	end;

	pure function reg_idx_max return natural is
		constant last_reg_idx: reg_idx_t := (others=>'1');
	begin
		return to_integer(last_reg_idx);
	end;

	pure function to_byte(i: natural) return byte_t is
	begin
		return to_unsigned(i, byte_t'length);
	end;

	pure function bit_to_byte(b: std_logic) return byte_t is
	begin
		return unsigned(bit_to_vector(b, byte_t'length));
	end;
	
	pure function is_byte_z(b: byte_t) return boolean is
	begin
		return std_logic_vector(b) = std_logic_vector(bit_to_byte('Z'));
	end;
	
	pure function to_word(i: natural) return word_t is
	begin
		return to_unsigned(i, word_t'length);
	end;

	pure function bit_to_word(b: std_logic) return word_t is
	begin
		return unsigned(bit_to_vector(b, word_t'length));
	end;
	
	pure function is_word_z(b: word_t) return boolean is
	begin
		return std_logic_vector(b) = std_logic_vector(bit_to_word('Z'));
	end;
	
	pure function to_reg_idx(constant i: natural) return reg_idx_t is
	begin
		return to_unsigned(i, reg_idx_t'length);
	end;

end package body;