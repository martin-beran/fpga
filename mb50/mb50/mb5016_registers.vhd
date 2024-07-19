-- CPU MB5016: The array of normal registers (r0...r15)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

-- MB5016 instructions have two register operands, therefore the implementation of registers
-- provides simultaneous reading and writing of pairs of registers.
-- In addition, direct access is provided for registers F and PC. If the same register is
-- selected for writing by both WrIdxA and WrIdxB, only value WrDataA is written and WrDataB
-- is ignored. If register F (r14) is written via write interface A or B, the written value
-- takes precedence over any modification by WrDataFlags and WrFlags, but exception/interrupt
-- bits set by WrIrq take precedence over any other modification of these bits. These rules ensure
-- that bits of F can be modified by arithmetic or logic instructions (which would otherwise
-- disturb the stored result by setting flags according to an instruction result), and that no
-- interrupt or exception gets lost when signalled at the same time as register F is written.
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
		WrB: in std_logic;
		-- Set flags: value to store in flags
		WrDataFlags: in flags_t := (others=>'0');
		-- Set flags: mask of bits changed by WrFlags
		WrFlags: in flags_t := (others=>'0');
		-- Set exception and interrupt bits
		WrIrq: in irq_t := (others=>'0');
		-- Value of register F (r14)
		RdF: out word_t;
		-- Value of register PC (r15)
		RdPc: out word_t;
		-- Increment the value of register PC (r15) by 2, ignored if PC is written by WrA or WrB
		Inc2Pc: in std_logic := '0';
	);
end entity;

architecture main of mb5016_registers is
	type r_t is array(0 to reg_idx_max) of word_t;
	signal r: r_t := (others=>(others=>'0'));
begin
	RdDataA <= r(to_integer(RdIdxA));
	RdDataB <= r(to_integer(RdIdxB));
	RdF <= r(reg_idx_f);
	RdPc <= r(reg_idx_pc);
	process (Clk, Rst) is
	begin
		if Rst = '1' then
			r <= (others=>(others=>'0'));
		elsif rising_edge(Clk) then
			r(reg_idx_f)(flags_t'range) <= unsigned((std_logic_vector(r(reg_idx_f)(flags_t'range)) and not WrFlags) or (WrDataFlags and WrFlags));
			-- Placing this condition here allows the increment to be overwritten by setting a new value to PC by WrA or WrB
			if IncPc = '1' then
				r(reg_idx_pc) <= r(reg_idx_pc) + 2;
			end if;
			if WrA = '1' then
				r(to_integer(WrIdxA)) <= WrDataA;
			end if;
			if WrB = '1' and not (WrA = '1' and WrIdxA = WrIdxB) then
				r(to_integer(WrIdxB)) <=  WrDataB;
			end if;
			-- old value is visible in r (not value written by WrA or WrB), so we cannot simply do
			-- r(15 downto 9) <= r(15 downto 9) or IRQ;
			for i in irq_t'range loop
				if WrIrq(i) = '1' then
					r(reg_idx_f)(i) <= '1';
				end if;
			end loop;
		end if;
	end process;
end architecture;