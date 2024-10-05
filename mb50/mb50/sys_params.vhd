-- System parameters

library ieee;
use ieee.std_logic_1164.all;
library lib_io;
use lib_io.pkg_crystal;
use work.types.all;

package sys_params is
	-- The CPU clock frequency
	constant CPU_HZ: positive := pkg_crystal.crystal_hz;
	-- The system clock frequency
	-- The system clock counter is incremented and clock interrupt is generated with this frequency
	constant HZ: positive := 100;
	-- The maximum address in the address space
	constant ADDR_MAX: addr_t := X"ffff";
	-- The address of the last byte of memory
	constant MEM_MAX: addr_t := X"752f"; -- 29999
	-- Address of the system clock counter register
	constant CLK_ADDR: addr_t := X"fff0";
	-- Address of the first keyboard controller register
	constant KBD_ADDR: addr_t := X"ffe0";
	-- Video RAM start address
	constant VIDEO_ADDR: addr_t := X"5a00";
end package;