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
-- Bitmap of WxH = 256x192 (logical) pixels = 32x192 B
--     Each logical pixel is 2x2 VGA pixels
--     Bytes in a line are left-to-right
--     Lines are top-to-bottom (different ordering than ZX Spectrum)
--     8 pixels represented by a byte: LSB=left, MSB=right, 0=background, 1=foreground
-- Attribute array 32x24 B for blocks of 8x8 pixels
--     MSB           LSB
--     |  b  |  R  |  G  |  B  |  0  |  R  |  G  |  B  |
--      blink|    fg color     |    bg color
-- One byte for border color
--     MSB           LSB
--     |0|0|0|0|0|R|G|B|
-- One byte containing blinking half-period (number of frames)
--     0 = no blinking
--     1..255 = exchange bg/fg colors after this number of frames
-- Each read from video RAM needs 3 clock periods:
-- 0 = set address to Addr
-- 1 = memory starts reading
-- 2 = data available on Data
-- Each group of 8 logical pixels (16 VGA) pixels in a row needs 2 bytes:
-- bitmap = one byte selecting background/foreground colors of each logical pixel
-- attributes = one byte defining background/foreground colors and blinking, common for all 8 pixels
-- Reading of data for each group of 8 logical pixels starts when displaying the first pixel of the previous group.

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
	-- Default start address of image bitmap (0 0x0000)
	constant AddrPxDefault: addr_t := (others=>'0');
	-- Default start address of attribute array (6144 0x1800)
	constant AddrAttrDefault: addr_t := to_unsigned(to_integer(AddrPxDefault) + 32*192, addr_bits);
	-- Default address of border color (6144+768=6912 0x1800+0x300=0x1b00)
	constant AddrBorderDefault: addr_t := to_unsigned(to_integer(AddrAttrDefault) + 32*24, addr_bits);
	-- Default address of blinking period (6144+768+1=6913 0x1800+0x300+0x01=0x1b01)
	constant AddrBlinkDefault: addr_t := to_unsigned(to_integer(AddrBorderDefault) + 1, addr_bits);
	
	component vga is
		generic (
			-- Start address of image bitmap
			AddrPx: addr_t := AddrPxDefault;
			-- Start address of attribute array
			AddrAttr: addr_t := AddrAttrDefault;
			-- Address of border color
			AddrBorder: addr_t := AddrBorderDefault;
			-- Address of blinking period
			AddrBlink: addr_t := AddrBlinkDefault
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
		AddrBorder: addr_t;
		AddrBlink: addr_t
	);
	port (
		PxClk: in std_logic;
		HSync, VSync, R, G, B: out std_logic;
		Addr: out addr_t;
		Data: in data_t
	);
end entity;

architecture main of vga is
	-- line: h_vis + h_fp + h_sync + h_bp = 800
	-- frame: v_vis + v_fp + v_sync + v_bp = 525
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
	constant prefetch: natural := 16; -- read this many pixels in advance	
begin
	process (PxClk) is
		variable h: natural range 0 to 799 := 0; -- horizontal position
		variable v: natural range 0 to 524 := 0; -- vertical position
		variable px, px1, attr: data_t; -- the current and next pixels, current attributes
		variable blink, frame: data_t := (others=>'0'); -- period and frame counter for blinking
		variable reverse: std_logic := '0'; -- current blinking state
		variable px_addr0, px_addr: addr_t; -- first and current pixel address
		variable attr_addr0, attr_addr: addr_t; -- first and current attribute address
		variable x2, y2: boolean := false; -- counting 2x2 VGA pixels in a logical pixel
		variable px8, py8: natural range 0 to 7 := 0; -- counting pixels in a group of 8
	begin
		if rising_edge(PxClk) then
			-- read image data from memory
			if v < v_border or v >= v_vis - v_border or
				h < h_border - prefetch or h >= h_vis - h_border - prefetch
			then
				if v = v_vis then
					-- fetch blinking period
					Addr <= AddrBlink;
				else
					-- fetch border color
					Addr <= AddrBorder;
				end if;
			else
				-- fetch pixel data
				if h = h_border - prefetch then
					if v = v_border then
						px_addr0 := AddrPx;
						px_addr := px_addr0;
						attr_addr0 := AddrAttr;
						attr_addr := attr_addr0;
					else
						if y2 then
							px_addr := px_addr0;
						else
							px_addr0 := px_addr;
						end if;
						if y2 or py8 /= 0 then
							attr_addr := attr_addr0;
						else
							attr_addr0 := attr_addr;
						end if;
					end if;
				end if;
				if px8 < 4 then
					Addr <= px_addr;
				else
					Addr <= attr_addr;
				end if;
			end if;
			if not x2 then
				case px8 is
					when 0 =>
						px := px1;
						attr := Data;
					when 3 =>
						px1 := Data;
					when others =>
						null;
				end case;
			end if;
			if v = v_vis then
				blink := Data;
			end if;
			-- generate RGB signal
			if h < h_vis and v < v_vis then
				if h >= h_border and h < h_vis - h_border and v >= v_border and v < v_vis - v_border then
					-- image
					if (px(px8) xor (reverse and attr(7))) = '1' then
						R <= attr(6);
						G <= attr(5);
						B <= attr(4);
					else
						R <= attr(2);
						G <= attr(1);
						B <= attr(0);
					end if;
				else
					-- border
					R <= attr(2);
					G <= attr(1);
					B <= attr(0);
				end if;
			else
				-- sync
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
			if h = h_vis + h_fp + h_sync + h_bp - 1 then
				h := 0;
				if v = v_vis + v_fp + v_sync + v_bp - 1 then
					v := 0;
					-- blinking
					if frame < blink then
						frame := frame + 1;
					else
						frame := (others=>'0');
						if unsigned(blink) = 0 then
							reverse := '0';
						else
							reverse := not reverse;
						end if;
					end if;
				else
					v := v + 1;
				end if;
			else
				h := h + 1;
			end if;
			if x2 then
				if px8 = 7 then
					px8 := 0;
					if h > h_border - prefetch and h <= h_vis - h_border - prefetch then
						px_addr := px_addr + 1;
						attr_addr := attr_addr + 1;
					end if;
				else
					px8 := px8 + 1;
				end if;
			end if;
			x2 := not x2;
			if h = 0 then
				if v = 0 then
					y2 := false;
					py8 := 0;
				else
					y2 := not y2;
					if y2 then
						if py8 = 7 then
							py8 := 0;
						else
							py8 := py8 + 1;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;
end architecture;
