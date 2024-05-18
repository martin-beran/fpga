-- CPU MB5016: The array of normal registers (r0...r15)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

-- MB5016 instructions have two register operands, therefore the implementation of registers
-- provides simultaneous reading and writing of pairs of registers. If the same register is
-- selected for writing by both WrIdxA and WrIdxB, only value WrDataA is written and WrDataB
-- is ignored.
entity mb5016_registers is
	port (
		-- CPU clock
		Clk: in std_logic;
		-- Reset (sets registers to all zeros)
		Rst: in std_logic;
		-- Read interface A: register index
		RdIdxA: in reg_idx_t;
		-- Read interface A: value
		RdDataA: out word_t;
		-- Read interface B: register index
		RdIdxB: in reg_idx_t;
		-- Read interface B: value
		RdDataB: out word_t;
		-- Write interface A: register index
		WrIdxA: in reg_idx_t;
		-- Write interface A: value
		WrDataA: in word_t;
		-- Write interface A: enable write
		WrA: in std_logic;
		-- Write interface B: register index
		WrIdxB: in reg_idx_t;
		-- Write interface B: value
		WrDataB: in word_t;
		-- Write interface B: enable write
		WrB: in std_logic
	);
end entity;

architecture main of mb5016_registers is
	type r_t is array(0 to reg_idx_max) of word_t;
	signal r: r_t := (others=>(others=>'0'));
begin
	RdDataA <= r(to_integer(RdIdxA));
	RdDataB <= r(to_integer(RdIdxB));
	process (Clk, Rst) is
	begin
		if Rst = '1' then
			r <= (others=>(others=>'0'));
		elsif rising_edge(Clk) then
			if WrA = '1' then
				r(to_integer(WrIdxA)) <= WrDataA;
			end if;
			if WrB = '1' and not (WrA = '1' and WrIdxA = WrIdxB) then
				r(to_integer(WrIdxB)) <=  WrDataB;
			end if;
		end if;
	end process;
end architecture;