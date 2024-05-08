-- MB50 main entity, it composes all components of computer MB50

library ieee;
use ieee.std_logic_1164.all;

-- The top level entity that defines computer MB50
entity mb50 is
	port (
		-- The CPU clock
		FPGA_CLK: in std_logic;
		-- The reset button
		RESET: in std_logic;
		-- RS-232 interface
		UART_TXD: out std_logic;
		UART_RXD: in std_logic;
		-- PS/2 keyboard interface
		PS_DATA: inout std_logic;
		PS_CLOCK: inout std_logic;
		-- VGA interface
		VGA_VSYNC: out std_logic;
		VGA_HSYNC: out std_logic;
		VGA_R: out std_logic;
		VGA_G: out std_logic;
		VGA_B: out std_logic
	);
end entity;

architecture main of mb50 is
begin
end architecture;