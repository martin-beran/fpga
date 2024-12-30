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
		-- Instruction CMPS: InA <=> InB (signed)
		OpCmps,
		-- Instruction CMPU: InA <=> InB (unsigned)
		OpCmpu,
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
		-- Multiplication of signed and signed: OutA := (InA * InB) % 0x1000; OutB := (InA * InB) / 0x1000
		OpMulss,
		-- Multiplication of signed and unsigned: OutA := (InA * InB) % 0x1000; OutB := (InA * InB) / 0x1000
		OpMulsu,
		-- Multiplication of unsigned and signed: OutA := (InA * InB) % 0x1000; OutB := (InA * InB) / 0x1000
		OpMulus,
		-- Multiplication of unsigned and unsigned: OutA := (InA * InB) % 0x1000; OutB := (InA * InB) / 0x1000
		OpMuluu,
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
		-- Instruction SHL: OutA := InA << InB
		OpShl,
		-- Instruction SHR: OutA := InA >> InB (logical)
		OpShr,
		-- Instruction SHRA: OutA := InA >> InB (arithmetic)
		OpShra,
		-- Instruction SUB: OutA := InA - InB
		OpSub,
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

	pure function f_cmps(InA, InB: word_t) return output_t is
		variable eq, le: std_logic;
	begin
		eq := to_std_logic(InA = InB);
		le := to_std_logic(signed(InA) < signed(InB));
		return (outA=>InA, OutB=>InB, FZ=>eq, FC=>le or eq, FS=>le, FO=>'0');
	end;
	
	pure function f_cmpu(InA, InB: word_t) return output_t is
		variable eq, le: std_logic;
	begin
		eq := to_std_logic(InA = InB);
		le := to_std_logic(InA < InB);
		return (outA=>InA, OutB=>InB, FZ=>eq, FC=>le or eq, FS=>le, FO=>'0');
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

	pure function f_mulss(InA, InB: word_t) return output_t is
		variable OutAB: signed(31 downto 0);
		variable FZ,FC, FO: std_logic := '0';
	begin
		OutAB := signed(std_logic_vector(InA)) * signed(std_logic_vector(InB));
		if OutAB = X"0000_0000" then
			FZ := '1';
		end if;
		if (OutAB(31 downto 16) /= X"0000" and OutAB(31) = '0') or
			(OutAB(31 downto 16) /= X"ffff" and OutAB(31) = '1')
		then
			FC := '1';
		end if;
		if (OutAB(31 downto 15) /= X"0000" and OutAB(31) = '0') or
			(OutAB(31 downto 15) /= X"ffff" and OutAB(31) = '1')
		then
			FO := '1';
		end if;
		return (OutA=>word_t(OutAB(15 downto 0)), OutB=>word_t(OutAB(31 downto 16)),
			FZ=>FZ, FC=>FC, FS=>OutAB(31), FO=>FO);
	end;

	pure function f_mulsu(InA, InB: word_t) return output_t is
		variable OutAB: signed(31 downto 0);
		variable FZ,FC, FO: std_logic := '0';
	begin
		OutAB := to_signed(to_integer(signed(std_logic_vector(InA))) * to_integer(InB), OutAB'length);
		if OutAB = X"0000_0000" then
			FZ := '1';
		end if;
		if (OutAB(31 downto 16) /= X"0000" and OutAB(31) = '0') or
			(OutAB(31 downto 16) /= X"ffff" and OutAB(31) = '1')
		then
			FC := '1';
		end if;
		if (OutAB(31 downto 15) /= X"0000" and OutAB(31) = '0') or
			(OutAB(31 downto 15) /= X"ffff" and OutAB(31) = '1')
		then
			FO := '1';
		end if;
		return (OutA=>word_t(OutAB(15 downto 0)), OutB=>word_t(OutAB(31 downto 16)),
			FZ=>FZ, FC=>FC, FS=>OutAB(31), FO=>FO);
	end;

	pure function f_muluu(InA, InB: word_t) return output_t is
		variable OutAB: unsigned(31 downto 0);
		variable FZ, FC, FO: std_logic := '0';
	begin
		OutAB := InA * InB;
		if OutAB = X"0000_0000" then
			FZ := '1';
		end if;
		if OutAB(31 downto 16) /= X"0000" then
			FC := '1';
		end if;
		if OutAB(31 downto 15) /= X"0000" & '0' then
			FO := '1';
		end if;
		return (OutA=>OutAB(15 downto 0), OutB=>OutAB(31 downto 16), FZ=>FZ, FC=>FC, FS=>'0', FO=>FO);
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
	
	pure function f_shl(InA, InB: word_t) return output_t is
		variable OutA: word_t;
	begin
		OutA := shift_left(InA, to_integer(InB(3 downto 0)));
		return (OutA=>OutA, OutB=>InB, FZ=>to_std_logic(OutA = to_word(0)),
			FC=>InA(word_t'high), FS=>OutA(word_t'high), FO=>to_std_logic(OutA(word_t'high) /= InA(word_t'high)));
	end;
	
	pure function f_shr(InA, InB: word_t) return output_t is
		variable OutA: word_t;
	begin
		OutA := shift_right(InA, to_integer(InB(3 downto 0)));
		return (OutA=>OutA, OutB=>InB, FZ=>to_std_logic(OutA = to_word(0)),
			FC=>InA(0), FS=>OutA(word_t'high), FO=>to_std_logic(OutA(word_t'high) /= InA(word_t'high)));
	end;
	
	pure function f_shra(InA, InB: word_t) return output_t is
		variable OutA: word_t;
	begin
		OutA := unsigned(shift_right(signed(InA), to_integer(InB(3 downto 0))));
		return (OutA=>OutA, OutB=>InB, FZ=>to_std_logic(OutA = to_word(0)),
			FC=>InA(0), FS=>OutA(word_t'high), FO=>to_std_logic(InB(3 downto 0) /= X"0" and InA = X"ffff"));
	end;
	
	pure function f_sub(InA, InB: word_t) return output_t is
		variable OutA: unsigned(word_t'high + 1 downto word_t'low);
	begin
		OutA := ('1' & InA) - ('0' & InB);
		return (OutA=>OutA(word_t'range), OutB=>InB,
			FZ=>to_std_logic(OutA(word_t'range) = to_word(0)),
			FC=>not OutA(OutA'high), FS=>OutA(word_t'high),
			FO=>to_std_logic(OutA(word_t'high) /= InA(word_t'high) and OutA(word_t'high) = InB(word_t'high)));
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
		f_cmps(InA, InB) when OpCmps,
		f_cmpu(InA, InB) when OpCmpu,
		f_dec1(InB) when OpDec1,
		f_dec2(InB) when OpDec2,
		(InB, InA, '0', '0', '0', '0') when OpExch,
		f_inc1(InB) when OpInc1,
		f_inc2(InB) when OpInc2,
		f_mulss(InA, InB) when OpMulss,
		f_mulsu(InA, InB) when OpMulsu,
		f_mulsu(InB, InA) when OpMulus,
		f_muluu(InA, InB) when OpMuluu,
		(InA, InB, '0', '0', '0', '0') when OpMv,
		f_not(InB) when OpNot,
		f_or(InA, InB) when OpOr,
		(InA or to_word(1) sll flags_idx_ie, InB, '0', '0', '0', '0') when OpRetiIe,
		f_rev(InB) when OpRev,
		f_shl(InA, InB) when OpShl,
		f_shr(InA, InB) when OpShr,
		f_shra(InA, InB) when OpShra,
		f_sub(InA, InB) when OpSub,
		f_xor(InA, InB) when OpXor,
		((others=>'0'), (others=>'0'), '0', '0', '0', '0') when others;
end architecture;