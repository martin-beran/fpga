-- CPU MB5016: ALU (Arithmetic-Logic Unit)
-- The ALU is implemented as purely combinatorial logic. Any operation that requires sequential logic
-- is implemented in cooperation with the CU (Control Unit), which controls temporary registers and
-- multiple passes through the ALU.

package pkg_mb5016_alu is
	-- Operations implemented by the ALU. If OutA or OutB is not specified for an operation, its value
	-- may be arbitrary. Values of flags are defined by specifications of related instructions.
	-- If a flag value is not specified for an instruction, its value may be arbitrary. Unspecified
	-- output and flags values are ignored by the CU, because the ALU always generates a value.
	type op_t is (
		-- Instruction AND: dst=OutA = InA AND InB(src)
		OpAnd,
		-- Instructions MV, EXCH: Exchange data from InA to OutB, from InB to OutA
		OpExch,
		-- Pass data from InA to OutA, from InB to OutB
		OpMv,
		-- Instruction NOT: dst=OutA = NOT InB(src)
		OpNot,
		-- Instruction OR: dst=OutA = InA OR InB(src)
		OpOr,
		-- Instruction XOR: dst=OutA = InA XOR InB(src)
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

	pure function f_and(InA, InB: word_t) return output_t is
		variable OutA: word_t;
	begin
		OutA := InA and InB;
		return (OutA=>OutA, OutB=>InB, FZ=>to_std_logic(OutA = to_word(0)), FC=>'0', FS=>OutA(OutA'high), FO=>'0');
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
		f_and(InA, InB) when OpAnd,
		(InB, InA, '0', '0', '0', '0') when OpExch,
		(InA, InB, '0', '0', '0', '0') when OpMv,
		f_not(InB) when OpNot,
		f_or(InA, InB) when OpOr,
		f_xor(InA, InB) when OpXor,
		((others=>'0'), (others=>'0'), '0', '0', '0', '0') when others;
end architecture;