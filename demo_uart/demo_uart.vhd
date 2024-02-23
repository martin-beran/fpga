-- Demo of library package lib_io.pkg_uart

library ieee;
use ieee.std_logic_1164.all;
library lib_io;
use lib_io.pkg_uart.all;

entity demo_uart is
	port (
		Clk, Rst: in std_logic;
		TX: out std_logic;
		RX: in std_logic
	);
end entity;

architecture main of demo_uart is
begin
	serial_port: uart port map (Clk=>Clk, Rst=>Rst, TX=>TX, RX=>RX);
end architecture;