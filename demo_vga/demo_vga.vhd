-- Demo of library package lib_io.pkg_vga

library ieee;
use ieee.std_logic_1164.all;
library lib_io;
use lib_io.pkg_vga.all;

entity demo_vga is
	port (
		Clk: in std_logic;
		HSync, VSync, R, G, B: out std_logic
	);
end entity;

architecture main of demo_vga is
	signal px_clk: std_logic;
begin
	pixel_clock: entity lib_io.vga_pixel_clk_pll port map (inclk0=>Clk, c0=>px_clk);
	vga_ctl: vga port map (PxClk=>px_clk, HSync=>HSync, VSync=>VSync, R=>R, G=>G, B=>B);
end architecture;