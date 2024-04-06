-- Demo of library package lib_io.pkg_vga
-- It shows an image with border stripes
-- button 1 = start blinking
-- button 2 = stop blinking
-- button 3 = clear image

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_io;
use lib_io.pkg_button.all;
use lib_io.pkg_vga.all;

entity demo_vga is
	port (
		Clk: in std_logic;
		Btn: in std_logic_vector(3 downto 0);
		HSync, VSync, R, G, B: out std_logic
	);
end entity;

architecture main of demo_vga is
	signal addr, addr_vga: addr_t;
	signal wr: std_logic := '0';
	signal clk_vga: std_logic;
	signal rdata, wdata, rdata_vga, wdata_vga: data_t;
	signal pressed: std_logic_vector(3 downto 0);
begin
	pixel_clock: entity lib_io.vga_pixel_clk_pll port map (inclk0=>Clk, c0=>clk_vga);
	
	buttons: button_group port map (Clk=>Clk, Button=>Btn, O=>pressed);
	
	memory: entity work.ram port map (
		address_a=>std_logic_vector(addr(14 downto 0)),
		address_b=>std_logic_vector(addr_vga(14 downto 0)),
		clock_a=>Clk,
		clock_b=>clk_vga,
		data_a=>std_logic_vector(wdata),
		data_b=>std_logic_vector(wdata_vga),
		wren_a=>wr,
		std_logic_vector(q_a)=>rdata,
		std_logic_vector(q_b)=>rdata_vga
	);
	
	vga_ctl: vga port map (
		PxClk=>clk_vga, HSync=>HSync, VSync=>VSync, R=>R, G=>G, B=>B,
		Addr=>addr_vga, Data=>rdata_vga
	);
	
	memory_writer: process (Clk) is
		variable img_clear: boolean := false;
		variable addr_clear: addr_t;
		variable cnt: natural;
		variable border_cnt: natural := 0;
		variable border_color: data_t := X"03";
	begin
		if rising_edge(Clk) then
			wr <= '0';
			if pressed(0) then
				addr <= AddrBlinkDefault;
				wdata <= X"1e";
				wr <= '1';
			elsif pressed(1) then
				addr <= AddrBlinkDefault;
				wdata <= X"00";
				wr <= '1';
			elsif pressed(2) then
				img_clear := true;
				cnt := 0;
				addr_clear := AddrPxDefault;
			elsif img_clear then
				if cnt = 500_000 then
					cnt := 0;
					if addr_clear = AddrBorderDefault then
						img_clear := false;
					else
						addr <= addr_clear;
						wdata <= X"00";
						wr <= '1';
						addr_clear := addr_clear + 1;
					end if;
				else
					cnt := cnt + 1;
				end if;
			else
				if border_cnt = 27778 then
					border_cnt := 0;
					addr <= AddrBorderDefault;
					border_color := not border_color;
					wdata <= border_color;
					wr <= '1';
				else
					border_cnt := border_cnt + 1;
				end if;
			end if;
		end if;
	end process;
	
end architecture;