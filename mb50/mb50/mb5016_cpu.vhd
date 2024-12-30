-- CPU MB5016: The main entity representing the whole CPU

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;
use work.pkg_mb5016_alu;
use work.pkg_mb5016_cu.all;

-- Access to registers (RegIdx, RegRd, RegWr) and takeover of the memory bus is
-- allowed only if the CPU is stopped (Run=0, Busy=0).
-- Quartus User Guide Design Recommendations allow using tri-state values only at the top level
-- of a design hierarchy for driving output or bidirectional pins. Therefore unidirectional data
-- bus signals DataBusRd and DataBusWr are used instead of a single inout DataBus.
-- Similarly, RegDataRd and RegDataWr are used instead of a single inout RegData.
entity mb5016_cpu is
	port (
		-- CPU clock input
		Clk: in std_logic;
		-- Reset
		Rst: in std_logic;
		-- Starts the CPU. It is sampled when the CPU is ready to execute an instruction.
		-- 1 sustained = run continuously
		-- 1 for 1 clock cycle = step (execute a single instruction)
		Run: in std_logic;
		-- Indicates that the CPU is executing an instruction (1=running, 0=halted)
		Busy: out std_logic;
		-- Indicates that the CPU is halted, because an exception has occurred when interrupts are disabled.
		-- The CPU must be reset or interrupts must be enabled by the CDI in order to leave the halted state
		Halted: out std_logic;
		-- Interrupt request lines, mapped to corresponding bits of register f
		-- 10 = iclk (system clock)
		-- 11 = ikbd (keyboard)
		-- 12-15 = reserved
		Irq: in std_logic_vector(15 downto 10) := (others=>'0');
		-- 16-bit address bus
		AddrBus: out addr_t;
		-- 8-bit data bus for reading (from memory)
		DataBusRd: in byte_t := (others=>'0');
		-- 8-bit data bus for writing (to memory)
		DataBusWr: out byte_t;
		-- Memory read (valid address on AddrBus, expects data in a later Clk cycle on DataBusRd)
		Rd: out std_logic;
		-- Memory write (valid address on AddrBus, valid data on DataBusWr)
		Wr: out std_logic;
		-- Access to registers: register index
		RegIdx: in reg_idx_t := (others=>'0');
		-- Access to registers: reading register value
		RegDataRd: out word_t;
		-- Access to registers: writing register value
		RegDataWr: in word_t := (others=>'0');
		-- Register read (valid index on RegIdx, expects value in the next Clk cycle on Reg)
		RegRd: in std_logic := '0';
		-- Register write (valid index on RegIdx, valid value on Reg)
		RegWr: in std_logic := '0';
		-- Select normal or CSR registers for read/write
		-- 0 = normal registers (r0...r15)
		-- 1 = CSRs (csr0...csr15)
		RegCsr: in std_logic := '0'
	);
end entity;

architecture main of mb5016_cpu is
	signal cpu_running, cu_exception, cu_halted, cu_disable_intr: std_logic;
	signal reg_idx_a, reg_idx_b, cu_reg_idx_a: reg_idx_t;
	signal reg_rd_data_a, reg_rd_data_b, alu_rd_data_a, alu_rd_data_b: word_t;
	signal reg_wr_data_a, reg_wr_data_b, alu_wr_data_a, alu_wr_data_b: word_t;
	signal reg_rd_f, reg_rd_pc, csr_rd_data, csr1_data: word_t;
	signal reg_wr_a, reg_wr_b, csr_wr, cu_reg_wr_a, cu_csr_rd, cu_csr_wr, ena_csr0_h, cu_ena_csr0_h: std_logic;
	signal reg_wr_data_flags, reg_wr_flags: flags_t;
	signal alu_op: pkg_mb5016_alu.op_t;
	signal addr_bus_route: addr_bus_route_t;
	signal addr_bus_add: std_logic;
	signal data_bus_route: data_bus_route_t;
begin
	-- External out/inout signals
	Busy <= cpu_running;
	Halted <= cu_halted;
	RegDataRd <=
		(others=>'0') when cpu_running = '1' or RegRd /= '1' or RegWr /= '0' else
		reg_rd_data_a when RegCsr = '0' else
		csr_rd_data;
	
	-- Functional units of the CPU: registers, CSRs, ALU, CU
	reg: entity work.mb5016_registers port map (
		Clk=>Clk, Rst=>Rst,
		IdxA=>reg_idx_a, RdDataA=>reg_rd_data_a,
		IdxB=>reg_idx_b, RdDataB=>reg_rd_data_b,
		WrDataA=>reg_wr_data_a, WrA=>reg_wr_a,
		WrDataB=>reg_wr_data_b, WrB=>reg_wr_b,
		WrDataFlags=>reg_wr_data_flags, WrFlags=>reg_wr_flags,
		WrIrq(9)=>cu_exception, WrIrq(15 downto 10)=>Irq, ClrIE=>cu_disable_intr,
		RdF=>reg_rd_f, RdPc=>reg_rd_pc
	);
	csr: entity work.mb5016_csr port map (
		Clk=>Clk, Rst=>Rst,
		Idx=>reg_idx_a, RdData=>csr_rd_data, WrData=>reg_wr_data_a, Wr=>csr_wr,
		EnaCsr0H=>ena_csr0_h
	);
	alu: entity work.mb5016_alu port map (
		Op=>alu_op,
		InA=>alu_rd_data_a, InB=>alu_rd_data_b, OutA=>alu_wr_data_a, OutB=>alu_wr_data_b,
		FZ=>reg_wr_data_flags(flags_idx_z), FC=>reg_wr_data_flags(flags_idx_c),
		FS=>reg_wr_data_flags(flags_idx_s), FO=>reg_wr_data_flags(flags_idx_o)
	);
	cu: entity work.mb5016_cu port map (
		Clk=>Clk, Rst=>Rst, Run=>Run,
		Busy=>cpu_running, Halted=>cu_halted, Exception=>cu_exception, DisableIntr=>cu_disable_intr,
		RegIdxA=>cu_reg_idx_a, RegIdxB=>reg_idx_b,
		RegWrA=>cu_reg_wr_a, RegWrB=>reg_wr_b,
		CsrRd=>cu_csr_rd, CsrWr=>cu_csr_wr, EnaCsr0H=>cu_ena_csr0_h,
		RegWrFlags=>reg_wr_flags, RegRdF=>reg_rd_f, RegRdPc=>reg_rd_pc,
		AluOp=>alu_op,
		AddrBusRoute=>addr_bus_route, AddrBusAdd=>addr_bus_add,
		DataBusRoute=>data_bus_route, DataBus=>DataBusRd, MemRd=>Rd, MemWr=>Wr
	);
	
	-- Registers are controlled by CU and are connected to ALU, address bus, and data bus.
	-- CU or CDI selects between ordinary registers and CSRs
	-- CDI can access registers via interface A while the CPU is stopped
	alu_rd_data_a <= reg_rd_data_a;
	alu_rd_data_b <= csr_rd_data when cu_csr_rd = '1' else reg_rd_data_b;
	reg_idx_a <= cu_reg_idx_a when cpu_running = '1' else RegIdx;
	reg_wr_data_a <=
		RegDataWr when cpu_running /= '1' else
		unsigned(std_logic_vector(DataBusRd) & std_logic_vector(alu_wr_data_a(7 downto 0)))
			when data_bus_route = ToRegAH else
		unsigned(std_logic_vector(alu_wr_data_a(15 downto 8)) & std_logic_vector(DataBusRd))
			when data_bus_route = ToRegAL else
		alu_wr_data_a;
	reg_wr_data_b <=
		unsigned(std_logic_vector(DataBusRd) & std_logic_vector(alu_wr_data_b(7 downto 0)))
			when data_bus_route = ToRegBH else
		unsigned(std_logic_vector(alu_wr_data_b(15 downto 8)) & std_logic_vector(DataBusRd))
			when data_bus_route = ToRegBL else
		alu_wr_data_b;
	reg_wr_a <= cu_reg_wr_a when cpu_running = '1' else RegWr and not RegCsr;
	AddrBus <=
		reg_rd_data_a when addr_bus_route = AddrRegA and addr_bus_add = '0' else
		reg_rd_data_a + 1 when addr_bus_route = AddrRegA and addr_bus_add = '1' else
		reg_rd_data_b when addr_bus_route = AddrRegB and addr_bus_add = '0' else
		reg_rd_data_b + 1 when addr_bus_route = AddrRegB and addr_bus_add = '1' else
		(others=>'0');
	with data_bus_route select
		DataBusWr <=
			reg_rd_data_a(15 downto 8) when FromRegAH,
			reg_rd_data_a(7 downto 0) when FromRegAL,
			reg_rd_data_b(15 downto 8) when FromRegBH,
			reg_rd_data_b(7 downto 0) when FromRegBL,
			(others=>'0') when others;
	csr_wr <= cu_csr_wr when cpu_running = '1' else RegWr and RegCsr;
	ena_csr0_h <= cu_ena_csr0_h when cpu_running = '1' else '1';
	
end architecture;