-- MB50: MEMCTL (Memory Controller)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;
use work.sys_params.all;

entity memctl is
	port (
		-- CPU clock
		Clk: in std_logic;
		-- Reset
		Rst: in std_logic;
		-- Connected to the CPU/CDI address bus
		CpuAddrBus: in addr_t;
		-- Connected to the CPU/CDI DataBusRd (reading from memory)
		CpuDataBusRd: out byte_t;
		-- Connected to the CPU/CDI DataBusWr (writing to memory)
		CpuDataBusWr: in byte_t;
		-- Connected to the CPU/CDI memory read signal
		CpuRd: in std_logic;
		-- Connected to the CPU/CDI memory write signal
		CpuWr: in std_logic;
		-- Connected to the (15 bit) RAM address bus
		RamAddrBus: out std_logic_vector(14 downto 0);
		-- Connected to the RAM data outputs (for reading from memory)
		RamDataBusRd: in std_logic_vector(7 downto 0);
		-- Connected to the RAM data inputs (for writing to memory)
		RamDataBusWr: out std_logic_vector(7 downto 0);
		-- Connected to the RAM write enable signal
		RamWr: out std_logic;
		-- Connected to the system clock value register
		SysClkValue: in word_t;
		-- Connected to PS/2 controller signal TxD
		Ps2TxD: out std_logic_vector(7 downto 0) := (others=>'0');
		-- Connected to PS/2 controller signal TxStart
		Ps2TxStart: out std_logic := '0';
		-- Connnected to PS/2 controller signal TxReady
		Ps2TxReady: in std_logic;
		-- Connnected to PS/2 controller signal RxD
		Ps2RxD: in std_logic_vector(7 downto 0);
		-- Connnected to PS/2 controller signal RxValid
		Ps2RxValid: in std_logic;
		-- Connnected to PS/2 controller signal RxAck
		Ps2RxAck: out std_logic
	);
end entity;

architecture main of memctl is
	signal addr_reg: word_t; -- Stored CpuAddrBus from the last clock period when CpuRd = '1'
begin
	CpuDataBusRd <=
		(others=>'0') when Rst /= '0' else
		SysClkValue(7 downto 0) when addr_reg = CLK_ADDR else
		SysClkValue(15 downto 8) when addr_reg = CLK_ADDR + 1 else
		byte_t(Ps2RxD) when addr_reg = KBD_ADDR + 1 else
		(0=>Ps2RxValid, 1=>Ps2TxReady, others=>'0') when addr_reg = KBD_ADDR + 2 else
		byte_t(RamDataBusRd);
	RamAddrBus <=
		(others=>'0') when Rst /= '0' else
		(others=>'0') when CpuAddrBus > MEM_MAX else
		std_logic_vector(addr_reg(14 downto 0)) when CpuRd = '0' and CpuWr = '0' else
		std_logic_vector(CpuAddrBus(14 downto 0));
	RamDataBusWr <=
		(others=>'0') when Rst /= '0' else
		std_logic_vector(CpuDataBusWr);
	RamWr <=
		'0' when Rst /= '0' else
		'0' when CpuAddrBus > MEM_MAX else
		CpuWr;
	Ps2TxStart <=
		'0' when Rst /= '0' else
		CpuWr when CpuAddrBus = KBD_ADDR else
		'0';
	Ps2RxAck <=
		'0' when Rst /= '0' else
		CpuWr when CpuAddrBus = KBD_ADDR + 1 else
		'0';
	save_values: process (Clk, Rst) is
		variable saved_ps2_txd: std_logic_vector(7 downto 0) := (others => '0');
	begin
		if Rst = '1' then
			addr_reg <= (others=>'0');
			Ps2TxD <= (others=>'0');
		elsif rising_edge(Clk) then
			if CpuRd = '1' then
				addr_reg <= CpuAddrBus;
			end if;
			if CpuAddrBus = KBD_ADDR and CpuWr = '1' then
				-- Value of Ps2TxD must be kept in the next clock cycle
				saved_ps2_txd := std_logic_vector(CpuDataBusWr);
			end if;
			Ps2TxD <= saved_ps2_txd;
		end if;
	end process;
end architecture;