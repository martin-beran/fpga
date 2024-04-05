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
	signal addr, addr_vga: addr_t;
	signal clk_vga: std_logic;
	signal rdata, wdata, rdata_vga, wdata_vga: data_t;
begin
	pixel_clock: entity lib_io.vga_pixel_clk_pll port map (inclk0=>Clk, c0=>clk_vga);
	memory: entity work.ram port map (
		address_a=>(others=>'0'),
		address_b=>std_logic_vector(addr_vga(14 downto 0)),
		clock_a=>Clk,
		clock_b=>clk_vga,
		data_a=>std_logic_vector(wdata),
		data_b=>std_logic_vector(wdata_vga),
		std_logic_vector(q_a)=>rdata,
		std_logic_vector(q_b)=>rdata_vga
	);
	vga_ctl: vga port map (
		PxClk=>clk_vga, HSync=>HSync, VSync=>VSync, R=>R, G=>G, B=>B,
		Addr=>addr_vga, Data=>rdata_vga
	);
end architecture;