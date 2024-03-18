-- VGA controller
-- It implements mode 640x480 @ 60 Hz
-- General timing
--     Screen refresh rate      60 Hz
--     Vertical refresh         31.46875 kHz
--     Pixel freq.              25.175 MHz
-- Horizontal timing
--     HSync pulse polarity is negative
--     Scanline part    Pixels  Time [µs]
--     Visible area     640     25.422045680238
--     Front porch      16      0.63555114200596
--     Sync pulse       96      3.8133068520357
--     Back porch       48      1.9066534260179
--     Whole line       800     31.777557100298
-- Vertical timing
--     VSync pulse polarity is negative
--     Frame part       Lines   Time [ms]
--     Visible area     480     15.253227408143
--     Front porch      10      0.31777557100298
--     Sync pulse       2       0.063555114200596
--     Back porch       33      1.0486593843098
--     Whole frame      525     16.683217477656
--
-- Video RAM is organized similarly to ZX Spectrum:
-- Bitmap of WxH = 256x192 pixels = 32x192 B
-- Bytes in a line are left-to-right
-- Lines are top-to-bottom (different ordering than ZX Spectrum)
-- 8 pixels represented by a byte: LSB=left, MSB=right
-- Attribute array 32x24 B for blocks of 8x8 pixels
-- MSB           LSB
-- |0|R|G|B|0|R|G|B|
-- fg color|bg color
-- One byte for border color
-- MSB           LSB
-- |0|0|0|0|0|R|G|B|

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg_vga is
	-- Bit size of an address
	constant addr_bits: positive := 16;
	-- Bit size of a data bytes
	constant data_bits: positive := 8;
	-- Address type
	subtype addr_t is unsigned(addr_bits - 1 downto 0);
	-- Data type
	subtype data_t is unsigned(data_bits - 1 downto 0);
	component vga is
		generic (
			-- Start address of image bitmap
			AddrPx: addr_t := (others=>'0');
			-- Start address of attribute array
			AddrAttr: addr_t := to_unsigned(32 * 192, addr_bits);
			-- Address of border color
			AddrBorder: addr_t := to_unsigned(32 * 192 + 32 * 24, addr_bits)
		);
		port (
			-- pixel clock, must have the correct frequency
			PxClk: in std_logic;
			-- horizontal synchronization
			HSync: out std_logic;
			-- vertical synchronization
			VSync: out std_logic;
			-- red channel
			R: out std_logic;
			-- green channel
			G: out std_logic;
			-- blue channel
			B: out std_logic;
			-- address for reading from video memory
			Addr: out addr_t;
			-- data from video memory
			Data: in data_t := (others=>'0')
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_io;
use lib_io.pkg_vga.all;

entity vga is
	generic (
		AddrPx: addr_t;
		AddrAttr: addr_t;
		AddrBorder: addr_t
	);
	port (
		PxClk: in std_logic;
		HSync, VSync, R, G, B: out std_logic;
		Addr: out addr_t;
		Data: in data_t
	);
end entity;

architecture main of vga is
	constant h_vis: natural := 640; -- visible pixels in line
	constant h_border: natural := 64; -- horizontal border width (pixels)
	constant h_fp: natural := 16; -- horizontal front porch (pixels)
	constant h_sync: natural := 96; -- horizontal sync pulse (pixels)
	constant h_bp: natural := 48; -- horizontal back porch (pixels)
	constant v_vis: natural := 480; -- visible lines
	constant v_border: natural := 48; -- vertical border width (lines)
	constant v_fp: natural := 10; -- vertical front porch (lines)
	constant v_sync: natural := 2; -- vertical sync pulse (lines)
	constant v_bp: natural := 33; -- vertical back porch (lines)
	signal h: natural range 0 to 799 := 0; -- horizontal position
	signal v: natural range 0 to 524 := 0; -- vertical position
begin
	process (PxClk) is
		variable bcolor: boolean := false;
		variable bstart, boff, bcnt: natural := 0;
	begin
		if rising_edge(PxClk) then
			Addr <= (others=>'0');
			-- generate RGB signal
			if h < h_vis and v < v_vis then
				if h < h_border or h >= h_vis - h_border or v < v_border or v >= v_vis - v_border then
					if h = 0 then
						if v = 0 then
							if bstart < 4 then
								bstart := bstart + 1;
							else
								bstart := 0;
								if boff < 11 then
									boff := boff + 1;
								else
									boff := 0;
									bcolor := not bcolor;
								end if;
							end if;
							bcnt := boff;
						end if;
						if bcnt < 11 then
							bcnt := bcnt + 1;
						else
							bcnt := 0;
							bcolor := not bcolor;
						end if;
					end if;
					if bcolor then
						R <= '1';
						G <= '0';
						B <= '0';
					else
						R <= '0';
						G <= '1';
						B <= '1';
					end if;
				elsif
					h = h_border + 0 or h = h_border + 1 or h = h_vis - h_border - 2 or h = h_vis - h_border - 1 or
					v = v_border + 0 or v = v_border + 1 or v = v_vis - v_border - 2 or v = v_vis - v_border - 1
				then
					R <= '1';
					G <= '1';
					B <= '1';
				else
					R <= to_unsigned(h, 4)(1);
					G <= to_unsigned(h, 4)(2);
					B <= to_unsigned(h, 4)(3);
				end if;
			else
				R <= '0';
				G <= '0';
				B <= '0';
			end if;
			-- next pixel and sync
			if h >= h_vis + h_fp and h < h_vis + h_fp + h_sync then
				HSync <= '0';
			else
				HSync <= '1';
			end if;
			if v >= v_vis + v_fp and v < v_vis + v_fp + v_sync then
				VSync <= '0';
			else
				VSync <= '1';
			end if;
			if h < h_vis + h_fp + h_sync + h_bp - 1 then
				h <= h + 1;
			else
				h <= 0;
				if v < v_vis + v_fp + v_sync + v_bp - 1 then
					v <= v + 1;
				else
					v <= 0;
				end if;
			end if;
		end if;
	end process;
end architecture;
