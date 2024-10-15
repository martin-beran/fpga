-- Testbench for entity mb50

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

entity tb_mb50 is
end entity;

architecture main of tb_mb50 is
	constant step: delay_length := 1 ns; -- This should be set to simulation resolution
	constant period: delay_length := 20 ns; -- CPU clock period, 50 MHz
	signal FPGA_CLK: std_logic;
	signal RESET: std_logic := '1';
	signal UART_TXD: std_logic;
	signal UART_RXD: std_logic := '1';
	signal PS_DATA: std_logic := 'Z';
	signal PS_CLOCK: std_logic := 'Z';
	signal VGA_VSYNC: std_logic;
	signal VGA_HSYNC: std_logic;
	signal VGA_R: std_logic;
	signal VGA_G: std_logic;
	signal VGA_B: std_logic;
begin
	clock: process is
		variable state: std_logic := '0';
	begin
		state := not state;
		FPGA_CLK <= state;
		wait for period / 2;
	end process;

	dut: entity work.mb50 port map (
		FPGA_CLK=>FPGA_CLK, RESET=>RESET,
		UART_TXD=>UART_TXD, UART_RXD=>UART_RXD, PS_DATA=>PS_DATA, PS_CLOCK=>PS_CLOCK,
		VGA_VSYNC=>VGA_VSYNC, VGA_HSYNC=>VGA_HSYNC, VGA_R=>VGA_R, VGA_G=>VGA_G, VGA_B=>VGA_B
	);
end architecture;