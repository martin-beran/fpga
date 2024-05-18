-- CPU MB5016: The main entity representing the whole CPU

library ieee;
use ieee.std_logic_1164.all;
use work.types.all;

-- Access to registers (RegIdx, RegRd, RegWr) and takeover of the memory bus is
-- allowed only if the CPU is stopped (Run=0, Busy=0).
entity mb5016_cpu is
	port (
		-- CPU clock input
		Clk: in std_logic;
		-- Reset
		Rst: in std_logic;
		-- Indicates that the CPU is executing an instruction (1=running, 0=halted)
		Busy: out std_logic;
		-- Starts the CPU. It is sampled when the CPU is ready to execute an instruction.
		-- 1 sustained = run continuously
		-- 1 for 1 clock cycle = step (execute a single instruction)
		Run: in std_logic;
		-- Interrupt request lines, mapped to corresponding bits of register f
		-- 10 = iclk (system clock)
		-- 11 = ikbd (keyboard)
		-- 12-15 = reserved
		IRQ: in std_logic_vector(10 to 15) := (others=>'0');
		-- 16-bit address bus
		AddrBus: out addr_t;
		-- 8-bit data bus
		DataBus: inout byte_t;
		-- Memory read (valid address on AddrBus, expects data in the next Clk cycle on DataBus)
		Rd: out std_logic;
		-- Memory write (valid address on AddrBus, valid data on DataBus)
		Wr: out std_logic;
		-- Access to registers: register index
		RegIdx: in reg_idx_t := (others=>'0');
		-- Access to registers: register value
		Reg: inout word_t;
		-- Register read (valid index on RegIdx, expects value in the next Clk cycle on Reg)
		RegRd: in std_logic := '0';
		-- Register write (valid index on RegIdx, valid value on Reg)
		RegWr: in std_logic := '0';
		-- Select normal or CSR registers for read/write
		-- 0 = normal registers (r0...r15)
		-- 1 = CSRs (csr0...csr15)
		RegCSR: in std_logic := '0'
	);
end entity;

architecture main of mb5016_cpu is
begin
	registers: entity work.mb5016_registers port map (Clk=>Clk, Rst=>Rst);
	csr: entity work.mb5016_csr port map (Clk=>Clk, Rst=>Rst);
end architecture;