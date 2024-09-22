-- CPU MB5016: ALU (Arithmetic-Logic Unit)
-- The ALU is implemented as purely combinatorial logic. Any operation that requires sequential logic
-- is implemented in cooperation with the CU (Control Unit), which controls temporary registers and
-- multiple passes through the ALU.

package pkg_mb5016_alu is
	-- Operations implemented by the ALU. If OutA or OutB is not specified for an operation, its value
	-- may be arbitrary. Values of flags are defined by specifications of related instructions.
	-- If a flag value is not specified for an instruction, its value may be arbitrary. Unspecified
	-- output and flags values are ignored by the CU, because the ALU always generates a value.
	-- InA, OutA are connected to the first (destination) register of an instruction
	-- InB, OutB are connected to the second (source) register of an instruction
	type op_t is (
		-- TODO: opcodes for not yet implemented operations
		OpTODO, OpShl, OpShr, OpShra, OpSub,
		-- Constant: Exception reason "Unspecified" (OutA := OutB := const)
		OpConstExcUnspec,
		-- Constant: Exception reason "Illegal instruction with opcode zero" (OutA := OutB := const)
		OpConstExcIZero,
		-- Constant: Exception reason "Illegal (unknown) instruction with nonzero opcode" (OutA := OutB := const)
		OpConstExcIInstr,
		-- Instruction ADD: OutA := InA + InB
		OpAdd,
		-- Instruction AND: OutA := InA AND InB
		OpAnd,
		-- Decrement by 1: OutA := InB - 1
		OpDec1,
		-- Decrement by 2: OutA := InB - 2
		OpDec2,
		-- Instructions MV, EXCH: OutA := InB; OutB := InA
		OpExch,
		-- Increment by 1: OutA := InB + 1
		OpInc1,
		-- Increment by 2: OutA := InB + 2
		OpInc2,
		-- Pass data from InA to OutA, from InB to OutB: OutA := InA; OutB := InB
		OpMv,
		-- Instruction NOT: OutA := NOT InB
		OpNot,
		-- Instruction OR: OutA := InA OR InB
		OpOr,
		-- Instruction RETI: OutA := InA OR flags_idx_ie (set IE bit in register F)
		OpRetiIe,
		-- Instruction REV: OutA(15 downto 0) := InB(0 to 15)
		OpRev,
		-- Instruction XOR: OutA := InA XOR InB
		OpXor
	);
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;
use work.pkg_mb5016_alu.all;

entity mb5016_alu is
	port (
		-- Selection of an operation
		Op: in op_t;
		-- The first argument word
		InA: in word_t;
		-- The second argument word
		InB: in word_t;
		-- The first result word
		OutA: out word_t;
		-- The second result word
		OutB: out word_t;
		-- The Zero flag
		FZ: out std_logic;
		-- The Carry flag
		FC: out std_logic;
		-- The Sign flag
		FS: out std_logic;
		-- the Overflow flag
		FO: out std_logic
	);
end entity;

use work.pkg_mb5016_alu.all;

architecture main of mb5016_alu is
	type output_t is record
		OutA, OutB: word_t;
		FZ, FC, FS, FO: std_logic;
	end record;
	signal output: output_t;

	pure function f_add(InA, InB: word_t) return output_t is
		variable OutA: unsigned(word_t'high + 1 downto word_t'low);
	begin
		OutA := ('0' & InA) + ('0' & InB);
		return (OutA=>OutA(word_t'range), OutB=>InB,
			FZ=>to_std_logic(OutA(word_t'range) = to_word(0)),
			FC=>OutA(OutA'high), FS=>OutA(word_t'high),
			FO=>to_std_logic(OutA(word_t'high) /= InA(word_t'high) and OutA(word_t'high) /= InB(word_t'high)));
	end;
	
	pure function f_and(InA, InB: word_t) return output_t is
		variable OutA: word_t;
	begin
		OutA := InA and InB;
		return (OutA=>OutA, OutB=>InB, FZ=>to_std_logic(OutA = to_word(0)), FC=>'0', FS=>OutA(OutA'high), FO=>'0');
	end;

	pure function f_dec1(InB: word_t) return output_t is
		variable OutA: word_t;
	begin
		OutA := InB - 1;
		return (OutA=>OutA, OutB=>InB, FZ=>to_std_logic(OutA = to_word(0)), FC=>to_std_logic(OutA = X"ffff"),
			FS=>OutA(OutA'high), FO=>to_std_logic(OutA = X"7fff"));
	end;

	pure function f_dec2(InB: word_t) return output_t is
		variable OutA: word_t;
	begin
		OutA := InB - 2;
		return (OutA=>OutA, OutB=>InB, FZ=>to_std_logic(OutA = to_word(0)),
			FC=>to_std_logic(OutA = X"ffff" or OutA = X"fffe"),
			FS=>OutA(OutA'high), FO=>to_std_logic(OutA = X"7fff" or OutA = X"7ffe"));
	end;

	pure function f_inc1(InB: word_t) return output_t is
		variable OutA: word_t;
	begin
		OutA := InB + 1;
		return (OutA=>OutA, OutB=>InB, FZ=>to_std_logic(OutA = to_word(0)), FC=>to_std_logic(InB = X"ffff"),
			FS=>OutA(OutA'high), FO=>to_std_logic(InB = X"7fff"));
	end;

	pure function f_inc2(InB: word_t) return output_t is
		variable OutA: word_t;
	begin
		OutA := InB + 2;
		return (OutA=>OutA, OutB=>InB, FZ=>to_std_logic(OutA = to_word(0)),
			FC=>to_std_logic(InB = X"ffff" or InB = X"fffe"),
			FS=>OutA(OutA'high), FO=>to_std_logic(InB = X"7fff" or InB = X"7ffe"));
	end;

	pure function f_not(InB: word_t) return output_t is
		variable OutA: word_t;
	begin
		OutA := not InB;
		return (OutA=>OutA, OutB=>InB, FZ=>to_std_logic(OutA = to_word(0)), FC=>'0', FS=>OutA(OutA'high), FO=>'0');
	end;

	pure function f_or(InA, InB: word_t) return output_t is
		variable OutA: word_t;
	begin
		OutA := InA or InB;
		return (OutA=>OutA, OutB=>InB, FZ=>to_std_logic(OutA = to_word(0)), FC=>'0', FS=>OutA(OutA'high), FO=>'0');
	end;

	pure function f_rev(InB: word_t) return output_t is
		variable OutA: word_t;
	begin
		rev: for i in word_t'range loop
			OutA(i) := InB(word_t'high - i);
		end loop;
		return (OutA=>OutA, OutB=>InB, FZ=>to_std_logic(OutA = to_word(0)), FC=>'0', FS=>OutA(OutA'high), FO=>'0');
	end;
	
	pure function f_xor(InA, InB: word_t) return output_t is
		variable OutA: word_t;
	begin
		OutA := InA xor InB;
		return (OutA=>OutA, OutB=>InB, FZ=>to_std_logic(OutA = to_word(0)), FC=>'0', FS=>OutA(OutA'high), FO=>'0');
	end;

begin
	OutA <= output.OutA;
	OutB <= output.OutB;
	FZ <= output.FZ;
	FC <= output.FC;
	FS <= output.FS;
	FO <= output.FO;
	with Op select output <=
		(X"0100", X"0100", '0', '0', '0', '0') when OpConstExcUnspec,
		(X"0101", X"0101", '0', '0', '0', '0') when OpConstExcIZero,
		(X"0102", X"0102", '0', '0', '0', '0') when OpConstExcIInstr,
		f_add(InA, InB) when OpAdd,
		f_and(InA, InB) when OpAnd,
		(InB, InA, '0', '0', '0', '0') when OpExch,
		f_inc1(InB) when OpInc1,
		f_inc2(InB) when OpInc2,
		(InA, InB, '0', '0', '0', '0') when OpMv,
		f_not(InB) when OpNot,
		f_or(InA, InB) when OpOr,
		(InA or to_word(1) sll flags_idx_ie, InB, '0', '0', '0', '0') when OpRetiIe,
		f_rev(InB) when OpRev,
		f_xor(InA, InB) when OpXor,
		((others=>'0'), (others=>'0'), '0', '0', '0', '0') when others;
end architecture;