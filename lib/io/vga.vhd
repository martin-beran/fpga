-- VGA controller
-- It implements mode 640x480 @ 60 Hz
-- General timing
--     Screen refresh rate      60 Hz
--     Vertical refresh         31.46875 kHz
--     Pixel freq.              25.175 MHz
-- Horizontal timing
--     Scanline part    Pixels  Time [µs]
--     Visible area     640     25.422045680238
--     Front porch      16      0.63555114200596
--     Sync pulse       96      3.8133068520357
--     Back porch       48      1.9066534260179
--     Whole line       800     31.777557100298
-- Vertical timing
--     Frame part       Lines   Time [ms]
--     Visible area     480     15.253227408143
--     Front porch      10      0.31777557100298
--     Sync pulse       2       0.063555114200596
--     Back porch       33      1.0486593843098
--     Whole frame      525     16.683217477656

library ieee;
use ieee.std_logic_1164;

package pkg_vga is
	component vga is
		port (
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164;

entity vga is
	port (
	);
end entity;

architecture main of vga is
begin
end architecture;
