-- CPU MB5016: CU (Control Unit)
-- The CU connects and controls other components of the CPU. It fetches and executes instructions,
-- routes data, and communicates with the CDI (Control and Debugging Interface)

library ieee;
use ieee.std_logic_1164.all;
use work.types.all;
use work.pkg_mb5016_alu;

entity mb5016_cu is
	port (
		-- CPU clock
		Clk: in std_logic;
		-- Reset (stops the CPU)
		Rst: in std_logic;
		-- Execute the next instruction
		Run: in std_logic;
		-- Executing an instruction
		Busy: out std_logic;
		-- Generate an exception
		Exception: out std_logic;
		-- Select the first register argument of an instruction
		RegIdxA: out reg_idx_t;
		-- Select the second register argument of an instruction
		RegIdxB: out reg_idx_t;
		-- Write to the first register argument of an instruction
		RegWrA: out std_logic;
		-- Write to the second register argument of an instruction
		RegWrB: out std_logic;
		-- Read the first argument of an instruction from a CSR instead a register
		CsrRd: out std_logic;
		-- Use a CSR instead of a register for writing the first result of an instruction
		CsrWr: out std_logic;
		-- Enable writing of csr0 bit H
		EnaCsr0H: out std_logic;
		-- Value of csr1
		Csr1Data: out word_t;
		-- Which flags an instruction can modify
		RegWrFlags: out flags_t;
		-- Current value of register F (r14)
		RegRdF: in word_t;
		-- Current value of register PC (r15)
		RegRdPc: in word_t;
		-- Select ALU operation
		AluOp: out pkg_mb5016_alu.op_t
	);
end entity;

architecture main of mb5016_cu is
begin
	-- The main FSM that controls the CPU
	cu_fsm: block is
		enum state_t is (Init);
		signal state: state_t := Init;
	begin
		process (Clk, Rst) is
		begin
			if Rst = '1' then
				state := Init;
			elsif rising_edge(Clk) then
				case state is
					when Init =>
						null;
				end case;
			end if;
		end process;
	end block;
end architecture;