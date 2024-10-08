-- MB50 main entity, it composes all components of computer MB50

library ieee, lib_io;
use ieee.std_logic_1164.all;
use lib_io.pkg_reset.all;

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
	signal Rst, run: std_logic;
begin
	reset_hnd: reset_button generic map (initial_rst=>true) port map (Clk=>FPGA_CLK, RstBtn=>RESET, Rst=>Rst);
	
	cpu: entity work.mb5016_cpu port map (
		Clk=>FPGA_CLK, Rst=>Rst,
		Run=>run
	);
	
	ctl_dbg_if: entity work.cdi port map (
		Clk=>FPGA_CLK, Rst=>Rst,
		RunCpu=>run
	);
end architecture;