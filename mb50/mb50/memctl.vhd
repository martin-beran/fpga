-- MB50: MEMCTL (Memory Controller)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

entity memctl is
	port (
		-- Connected to the CPU address bus
		CpuAddrBus: in addr_t;
		-- Connected to the CPU DataBusRd (reading from memory)
		CpuDataBusRd: out byte_t;
		-- Connected to the CPU DataBusWr (writing to memory)
		CpuDataBusWr: in byte_t;
		-- Connected to the CPU memory read signal
		CpuRd: in std_logic;
		-- Connected to the CPU memory write signal
		CpuWr: in std_logic;
		-- Connected to the (15 bit) memory address bus
		MemAddrBus: out std_logic_vector(14 downto 0);
		-- Connected to the memory data outputs (for reading from memory)
		MemDataBusRd: in std_logic_vector(7 downto 0);
		-- Connected to the memory data inputs (for writing to memory)
		MemDataBusWr: out std_logic_vector(7 downto 0);
		-- Connected to the memory write enable signal
		MemWr: out std_logic;
		-- Connected to the system clock value register
		SysClkValue: in word_t
	);
end entity;

architecture main of memctl is
begin
end architecture;