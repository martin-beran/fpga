-- CPU MB5016: ALU (Arithmetic-Logic Unit)
-- The ALU is implemented as purely combinatorial logic. Any operation that requires sequential logic
-- is implemented in cooperation with the CU (Control Unit), which controls temporary registers and
-- multiple passes through the ALU.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

package pkg_mb5016_alu is
	-- Operations implemented by the ALU
	type op_t is (
		OpMv,
		OpExch
	);
end package;

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
begin
	with Op select (OutA, OutB, FZ, FC, FS, FO) <=
		(InA, InB, '0', '0', '0', '0') when OpMv;
		(InB, InA, '0', '0', '0', '0') when OpExch;
		((others=>'0'), (others=>'0'), '0', '0', '0', '0') when others;
end architecture;