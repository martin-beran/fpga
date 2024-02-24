-- Testbench for package pkg_uart

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_io;
use lib_io.pkg_crystal.all;
use lib_io.pkg_uart.all;

entity tb_uart is
end entity;

architecture main of tb_uart is
	signal Clk, Rst: std_logic;
	signal TX, RX, CfgSet, TxStart, TxReady: std_logic;
	signal Cfg, TxD: std_logic_vector(7 downto 0);
begin
	clock: process is
		variable state: std_logic := '0';
	begin
		state := not state;
		Clk <= state;
		wait for 500 ms / crystal_hz;
	end process;
	
	Rst <= '0';
	
	Cfg <= uart_baud_115200;
	CfgSet <=
		'0',
		'1' after 20 ns,
		'0' after 40 ns;
	
	TxD <=
		"00000000",
		"01100101" after 1000 ns,
		"00000000" after 1020 ns;
	TxStart <=
		'0',
		'1' after 1000 ns,
		'0' after 1020 ns;
	
	dut: uart port map (
		Clk=>Clk, Rst=>Rst, TX=>TX, RX=>RX, CfgSet=>CfgSet, Cfg=>Cfg, TxD=>TxD, TxStart=>TxStart, TxReady=>TxReady
	);
end architecture;